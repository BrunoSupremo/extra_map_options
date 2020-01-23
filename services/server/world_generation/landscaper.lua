local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Region3 = _radiant.csg.Region3
local SimplexNoise =		require 'stonehearth.lib.math.simplex_noise'
local Biome =				require 'stonehearth.services.server.world_generation.biome'
local Array2D =				require 'stonehearth.services.server.world_generation.array_2D'
local FilterFns =			require 'stonehearth.services.server.world_generation.filter.filter_fns'
local PerturbationGrid =	require 'stonehearth.services.server.world_generation.perturbation_grid'
local water_shallow = 'water_1'
local water_deep = 'water_2'

local GiantLandscaper = class()

local Astar = require 'giant_map.astar'
local noise_height_map --this noise is to mess with the astar to avoid straight line rivers
local regions --.size, .start and .ending
local min_required_region_size = 10
local log = radiant.log.create_logger('GiantLandscaper')

local sky_config = {
	octaves = 4,
	persistence_ratio = 0.001,
	bandlimit = 1.75,
	mean = 1.5,
	range = 16,
	aspect_ratio = 1
}

function GiantLandscaper:__init(biome, rng, seed, custom_map_options)
	self._biome = biome
	self._tile_width = self._biome:get_tile_size()
	self._tile_height = self._biome:get_tile_size()
	self._feature_size = self._biome:get_feature_block_size()
	self._landscape_info = self._biome:get_landscape_info()
	self._rng = rng
	self._seed = seed

	self._noise_map_buffer = nil
	self._density_map_buffer = nil

	self._perturbation_grid = PerturbationGrid(self._tile_width, self._tile_height, self._feature_size, self._rng)

	self._water_table = {
		water_1 = self._landscape_info.water.depth.shallow,
		water_2 = self._landscape_info.water.depth.deep
	}

	self:_parse_landscape_info()

	self._world_size = custom_map_options.world_size
	self._lakes = custom_map_options.lakes
	self._rivers = custom_map_options.rivers
	self._sky_lands = custom_map_options.sky_lands

	self._extra_map_options_on = true
end

function GiantLandscaper:mark_water_bodies(elevation_map, feature_map)
	if not self._lakes then
		return
	end
	local rng = self._rng
	local biome = self._biome
	local config = self._landscape_info.water.noise_map_settings
	local modifier_map, density_map = self:_get_filter_buffers(feature_map.width, feature_map.height)
	--fill modifier map to push water bodies away from terrain type boundaries
	local modifier_fn = function (i,j)
		if self:_is_flat(elevation_map, i, j, 1) and not self:_has_sky_near(feature_map, i, j) then
			return 0
		else
			return -1*config.range
		end
	end
	--use density map as buffer for smoothing filter
	density_map:fill(modifier_fn)
	FilterFns.filter_2D_0125(modifier_map, density_map, modifier_map.width, modifier_map.height, 10)
	--mark water bodies on feature map using density map and simplex noise
	local old_feature_map = Array2D(feature_map.width, feature_map.height)
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local occupied = feature_map:get(i, j) ~= nil
			if not occupied then
				local elevation = elevation_map:get(i, j)
				local terrain_type = biome:get_terrain_type(elevation)
				local value = SimplexNoise.proportional_simplex_noise(config.octaves,config.persistence_ratio, config.bandlimit,config.mean[terrain_type],config.range,config.aspect_ratio, self._seed,i,j)
				value = value + modifier_map:get(i,j)
				if value > 0 then
					local old_value = feature_map:get(i, j)
					old_feature_map:set(i, j, old_value)
					feature_map:set(i, j, water_shallow)
				end
			end
		end
	end
	self:_remove_juts(feature_map)
	self:_remove_ponds(feature_map, old_feature_map)
	self:_fix_tile_aligned_water_boundaries(feature_map, old_feature_map)
	self:_add_deep_water(feature_map)
end

function GiantLandscaper:mark_river_bodies(elevation_map, feature_map)
	if self._rivers.quantity < 1 then
		return
	end

	local rng = self._rng
	local biome = self._biome

	noise_height_map = {}
	noise_height_map.width = feature_map.width
	noise_height_map.height = feature_map.height
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local elevation = elevation_map:get(i, j)
			local terrain_type = biome:get_terrain_type(elevation)

			local offset = (j-1)*feature_map.width+i
			--creates and set the points
			noise_height_map[offset] = {}
			noise_height_map[offset].x = i
			noise_height_map[offset].y = j
			noise_height_map[offset].elevation = elevation
			noise_height_map[offset].terrain_type = terrain_type
			noise_height_map[offset].noise = rng:get_int(1,100)
		end
	end
	self:mark_borders(feature_map) --it is important to avoid generating close to the borders
	if self:river_create_regions() then -- try to create and check if regions exist to spawn rivers
		self:add_rivers(feature_map)
	end
end

function GiantLandscaper:mark_borders(feature_map)
	local function neighbors_have_different_elevations(x,y,offset)
		if not self._rivers[noise_height_map[offset].terrain_type] or self:_has_sky_near(feature_map, x, y, self._rivers.radius) then
			return true
		end
		local radius = self._rivers.radius
		for j=y-radius, y+radius do --the border will be 2 tiles thick
			for i=x-radius, x+radius do
				local neighbor_offset = (j-1)*noise_height_map.width+i
				if noise_height_map[neighbor_offset] then
					if noise_height_map[neighbor_offset].elevation ~= noise_height_map[offset].elevation then
						return true
					end
				end
			end
		end
		return false
	end

	for y=1, noise_height_map.height do
		for x=1, noise_height_map.width do
			local offset = (y-1)*noise_height_map.width+x
			noise_height_map[offset].border = true
		end
	end
	local map_border = self._world_size*16
	for y = map_border, noise_height_map.height - (map_border-1) do
		for x = map_border, noise_height_map.width - (map_border-1) do
			local offset = (y-1)*noise_height_map.width+x
			noise_height_map[offset].border = neighbors_have_different_elevations(x,y,offset)
		end
	end
end

function GiantLandscaper:river_create_regions()
	regions = {}
	--creates multiple regions, where each point has a path to any other within the region
	local has_at_least_one_usable_area = false
	local region_index = 1
	for y=1, noise_height_map.height do
		for x=1, noise_height_map.width do
			local offset = (y-1)*noise_height_map.width+x
			if not noise_height_map[offset].border then
				if not noise_height_map[offset].region then
					local region_candidate = self:river_flood_fill_region(x,y, region_index)

					if region_candidate.size>min_required_region_size then
						has_at_least_one_usable_area = true
						regions[region_index] = region_candidate
						region_index = region_index +1
					end
				end
			end
		end
	end

	--this is used to procced or skip the river generation (no need to try if there is no space)
	return has_at_least_one_usable_area
end

function GiantLandscaper:river_flood_fill_region(x,y, region)
	local offset = (y-1)*noise_height_map.width+x
	local openset = {}

	local start = offset
	local ending = offset

	local current
	local index = 1
	local size = 1
	openset[index] = offset
	noise_height_map[offset].checked = true
	while openset[index]~=nil do
		--find the most distant point in this region from that initially chosen
		current = noise_height_map[ openset[index] ]
		noise_height_map[ openset[index] ].region = region

		local offset_left = (current.y-1)*noise_height_map.width+current.x -1
		if current.x>1 and noise_height_map[offset_left].border==false and not noise_height_map[offset_left].checked then
			size = size +1
			openset[size] = offset_left
			noise_height_map[offset_left].checked = true
		end

		local offset_right = (current.y-1)*noise_height_map.width+current.x +1
		if current.x<noise_height_map.width and noise_height_map[offset_right].border==false and not noise_height_map[offset_right].checked then
			size = size +1
			openset[size] = offset_right
			noise_height_map[offset_right].checked = true
		end

		local offset_up = (current.y-2)*noise_height_map.width+current.x
		if current.y>1 and noise_height_map[offset_up].border==false and not noise_height_map[offset_up].checked then
			size = size +1
			openset[size] = offset_up
			noise_height_map[offset_up].checked = true
		end

		local offset_down = (current.y)*noise_height_map.width+current.x
		if current.y<noise_height_map.height and noise_height_map[offset_down].border==false and not noise_height_map[offset_down].checked then
			size = size +1
			openset[size] = offset_down
			noise_height_map[offset_down].checked = true
		end

		index = index +1
	end
	start = openset[size]

	if size > min_required_region_size then
		--reverse the flood to find the oposing most distant point
		local second_openset = {}
		index = 1
		size = 1
		second_openset[index] = start
		noise_height_map[start].second_pass = true
		while second_openset[index]~=nil do
			current = noise_height_map[ second_openset[index] ]

			local offset_left = (current.y-1)*noise_height_map.width+current.x -1
			if current.x>1 and noise_height_map[offset_left].border==false and not noise_height_map[offset_left].second_pass then
				size = size +1
				second_openset[size] = offset_left
				noise_height_map[offset_left].second_pass = true
			end

			local offset_right = (current.y-1)*noise_height_map.width+current.x +1
			if current.x<noise_height_map.width and noise_height_map[offset_right].border==false and not noise_height_map[offset_right].second_pass then
				size = size +1
				second_openset[size] = offset_right
				noise_height_map[offset_right].second_pass = true
			end

			local offset_up = (current.y-2)*noise_height_map.width+current.x
			if current.y>1 and noise_height_map[offset_up].border==false and not noise_height_map[offset_up].second_pass then
				size = size +1
				second_openset[size] = offset_up
				noise_height_map[offset_up].second_pass = true
			end

			local offset_down = (current.y)*noise_height_map.width+current.x
			if current.y<noise_height_map.height and noise_height_map[offset_down].border==false and not noise_height_map[offset_down].second_pass then
				size = size +1
				second_openset[size] = offset_down
				noise_height_map[offset_down].second_pass = true
			end

			index = index +1
		end
		ending = second_openset[size]
	end

	return {size = size, start = start, ending = ending}
end

function GiantLandscaper:add_rivers(feature_map)

	local function grab_bigest_region()
		local bigest_region = 0
		local current_bigest_size = 0

		for i,v in pairs(regions) do
			if regions[i].size > current_bigest_size then
				bigest_region = i
				current_bigest_size = regions[i].size
			end
		end
		if bigest_region <1 then
			return nil
		end
		return bigest_region
	end

	local counter = self._rivers.quantity
	while counter >0 do
		local region = grab_bigest_region()
		if not region then break end

		local start = regions[region].start
		local ending = regions[region].ending

		if counter > 0 and self._rivers[ noise_height_map[start].terrain_type ] then
			self:draw_river(noise_height_map[start], noise_height_map[ending], feature_map)
			counter = counter -1
		end
		regions[region] = nil
	end
end

function GiantLandscaper:draw_river(start,goal,feature_map)
	local path = Astar.path ( start, goal, noise_height_map, true )

	if not path then
		log:error('Error. No valid river path found!')
	else
		for i, node in ipairs ( path ) do
			if self._rivers.radius == 2 then --wide and deep rivers
				feature_map:set(node.x, node.y, water_deep)
				self:add_shallow_neighbors(node.x, node.y, feature_map)
			else --narrow and shallow rivers
				if feature_map:get(node.x, node.y) ~= water_deep then --avoid overwriting deep with shallow
					feature_map:set(node.x, node.y, water_shallow)
				end
			end
		end
	end
end

function GiantLandscaper:add_shallow_neighbors(x,y, feature_map)
	for j=y-1, y+1 do
		for i=x-1, x+1 do
			local feature_name = feature_map:get(i, j)
			--only where there is no water (else the deep parts would be overwriten)
			if feature_map:in_bounds(i,j) and (not self:is_water_feature(feature_name)) then
				feature_map:set(i, j, water_shallow)
			end
		end
	end
end

function GiantLandscaper:mark_sky(elevation_map, feature_map, sky_map)
	if not self._sky_lands then
		return false
	end
	local biome = self._biome
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local occupied = feature_map:get(i, j) ~= nil
			if not occupied then
				local value = SimplexNoise.proportional_simplex_noise(sky_config.octaves,sky_config.persistence_ratio, sky_config.bandlimit,sky_config.mean,sky_config.range,sky_config.aspect_ratio, self._seed,i,j)
				sky_map:set(i, j, value)
				if value > 0 then
					feature_map:set(i, j, "sky")
				end
			end
		end
	end
end

function GiantLandscaper:place_sky(tile_region, tile_map, sky_map, tile_offset_x, tile_offset_y)
	local sky_region = Region3()
	local rng = self._rng

	if self._sky_lands then
		sky_map:visit(function(value, i, j)
			local x, y, w, h = self._perturbation_grid:get_cell_bounds(i, j)

			-- use the center of the cell to get the elevation because the edges may have been detailed
			local cx, cy = x + math.floor(w*0.5), y + math.floor(h*0.5)
			local top = tile_map:get(cx, cy)

			if value>0 then
				top = top+100
				local cloud_x, cloud_z = self:_to_world_coordinates(x, y, tile_offset_x, tile_offset_y)
				local cloud = radiant.entities.create_entity("giant_map:decoration:clouds", {ignore_gravity = true})
				radiant.terrain.place_entity_at_exact_location(cloud, Point3(cloud_x,rng:get_int(0,value*10),cloud_z))
			else
				local elevation = tile_map:get(i, j)
				local terrain_type, step = self._biome:get_terrain_type_and_step(elevation)
				local mountain_value = -1
				if terrain_type ~= 'plains' then
					mountain_value = -2
				end
				top = top +( (value-1)*(value-1)*(mountain_value)*5 )
			end

			local world_x, world_z = self:_to_world_coordinates(x, y, 0, 0)
			local extra_padding = rng:get_int(1,2)*3
			local cube = Cube3(
				Point3(world_x-extra_padding, 0, world_z-extra_padding),
				Point3(world_x + w +extra_padding, top, world_z + h +extra_padding)
				)
			tile_region:subtract_cube(cube)

			sky_region:add_cube(cube)
		end)
	end

	sky_region:optimize('place sky')

	return sky_region
end

function GiantLandscaper:is_sky_feature(feature_name)
	return feature_name == "sky"
end

function GiantLandscaper:_has_sky_near(tile_map, x, y, radius)
	if not self._sky_lands then
		return false
	end
	radius = radius or 1
	local start_x, start_y = tile_map:bound(x-radius, y-radius)
	local end_x, end_y = tile_map:bound(x+radius, y+radius)
	local block_width = end_x - start_x + 1
	local block_height = end_y - start_y + 1
	local has_sky_near = false

	tile_map:visit_block(start_x, start_y, block_width, block_height, function(value)
		if self:is_sky_feature(value) then
			has_sky_near = true
			-- return true to terminate iteration
			return true
		end
	end)

	return has_sky_near
end

return GiantLandscaper