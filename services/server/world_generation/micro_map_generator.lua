local Array2D = require 'stonehearth.services.server.world_generation.array_2D'
local SimplexNoise = require 'stonehearth.lib.math.simplex_noise'
local FilterFns = require 'stonehearth.services.server.world_generation.filter.filter_fns'
local ExtraMapMicroMapGenerator = class()

function ExtraMapMicroMapGenerator:generate_noise_map(size_x, size_y)
	local mountains_info = self._terrain_info.mountains
	local macro_blocks_per_tile = self._macro_blocks_per_tile
	-- +1 for half macro_block margin on each edge
	local width = size_x * macro_blocks_per_tile + 1
	local height = size_y * macro_blocks_per_tile + 1
	local noise_map = Array2D(width, height)

	local height_multipler = 1
	local noise_config = self._terrain_info.noise_map_settings
	local extras = stonehearth.game_creation:get_extra_map_options()
	if extras.modes.canyons then
		height_multipler = 10
		--noise_config is avgered with the canyons values, (this+canyons*2) /3
		noise_config.octaves = (noise_config.octaves + 4) /3
		noise_config.persistence_ratio = (noise_config.persistence_ratio + 0.2) /3
		noise_config.bandlimit = (noise_config.bandlimit + 5) /3
		noise_config.aspect_ratio = (noise_config.aspect_ratio + 2) /3
	end
	local fn = function (x,y)
		local mean = mountains_info.height_base
		local range = (mountains_info.height_max - mean)*2
		local height = SimplexNoise.proportional_simplex_noise(noise_config.octaves,noise_config.persistence_ratio,noise_config.bandlimit, mean,range, noise_config.aspect_ratio, self._seed,x,y)
		-- log:error("x: %d - y: %d - height: %d", x, y, height)
		return height * height_multipler
	end
	noise_map:fill(fn)
	return noise_map
end

function ExtraMapMicroMapGenerator:generate_underground_micro_map(surface_micro_map)
	local mountains_info = self._terrain_info.mountains
	local mountains_base_height = mountains_info.height_base
	local mountains_step_size = mountains_info.step_size
	local rock_line = mountains_step_size
	local width, height = surface_micro_map:get_dimensions()
	local size = width*height
	local unfiltered_map = Array2D(width, height)
	local underground_micro_map = Array2D(width, height)

	local blocks_to_sink = 0
	local extras = stonehearth.game_creation:get_extra_map_options()
	if extras.modes.canyons then
		blocks_to_sink = 30
	end

	-- seed the map using the above ground mountains
	for i=1, size do
		local surface_elevation = surface_micro_map[i]
		local value

		if surface_elevation > mountains_base_height then
			value = surface_elevation
		else
			value = math.max(surface_elevation - mountains_step_size*2, rock_line)
		end

		unfiltered_map[i] = value - blocks_to_sink
	end

	-- filter the map to generate the underground height map
	FilterFns.filter_2D_0125(underground_micro_map, unfiltered_map, width, height, 10)

	local quantizer = self._biome:get_mountains_quantizer()

	-- quantize the height map
	for i=1, size do
		local surface_elevation = surface_micro_map[i]
		local rock_elevation

		if surface_elevation > mountains_base_height then
			-- if the mountain breaks the surface just use its height
			rock_elevation = surface_elevation
		else
			-- quantize the filtered value
			rock_elevation = quantizer:quantize(underground_micro_map[i])

			-- make sure the sides of the rock faces stay beneath the surface
			-- e.g. we don't want a drop in an adjacent foothills block to expose the rock
			if rock_elevation > surface_elevation - mountains_step_size then
				rock_elevation = rock_elevation - mountains_step_size
			end

			-- make sure we have a layer of rock beneath everything
			if rock_elevation <= 0 then
				rock_elevation = rock_line
			end
		end

		underground_micro_map[i] = rock_elevation - blocks_to_sink
	end

	local underground_elevation_map = self:_convert_to_elevation_map(underground_micro_map)

	return underground_micro_map, underground_elevation_map
end

function ExtraMapMicroMapGenerator:_add_plains_valleys(micro_map)
	local extras = stonehearth.game_creation:get_extra_map_options()
	if not extras.dirt_holes or extras.modes.waterworld then
		return
	end
	local rng = self._rng
	local shape_width = self._valley_shapes.shape_width
	local shape_height = self._valley_shapes.shape_height
	local plains_info = self._terrain_info.plains
	local noise_map = Array2D(micro_map.width, micro_map.height)
	local filtered_map = Array2D(micro_map.width, micro_map.height)
	local plains_max_height = plains_info.height_max
	local valley_density = 0.015
	local num_sites = 0
	local sites = {}
	local value, site, roll

	local noise_fn = function(i, j)
		if micro_map:is_boundary(i, j) then
			return -10
		end
		if micro_map:get(i, j) ~= plains_max_height then
			return -100
		end
		return 1
	end

	noise_map:fill(noise_fn)

	FilterFns.filter_2D_0125(filtered_map, noise_map, noise_map.width, noise_map.height, 10)

	for j=1, filtered_map.height do
		for i=1, filtered_map.width do
			value = filtered_map:get(i, j)

			if value > 0 then
				num_sites = num_sites + 1
				site = { x = i-1, y = j-1 }
				table.insert(sites, site)
			end
		end
	end

	for i=1, num_sites*valley_density do
		roll = rng:get_int(1, num_sites)
		site = sites[roll]

		if self:_is_high_plains(micro_map, site.x-2, site.y-2, shape_width+4, shape_height+4) then
			self:_place_valley(micro_map, site.x, site.y)
		end
	end
end

function ExtraMapMicroMapGenerator:_match_plains_percentile(micro_map)
	local percentile = self._terrain_info.plains_percentage
	local extras = stonehearth.game_creation:get_extra_map_options()
	if extras.modes.canyons then
		percentile = (percentile + 100) /3
	end
	if extras.modes.superflat then
		percentile = 90
	end
	local max = self._terrain_info.foothills.height_max
	local altitude_difference = self:get_percentile_altitude(percentile, micro_map) - max
	micro_map:process(
		function (value)
			return value - altitude_difference
		end
		)
end

return ExtraMapMicroMapGenerator