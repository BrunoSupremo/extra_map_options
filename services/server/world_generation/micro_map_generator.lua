local ValleyShapes =	require 'stonehearth.services.server.world_generation.valley_shapes'
local Array2D =			require 'stonehearth.services.server.world_generation.array_2D'
local FilterFns =		require 'stonehearth.services.server.world_generation.filter.filter_fns'

GiantMicroMapGenerator = class()

local dirt_holes = true

function GiantMicroMapGenerator:__init(biome,rng,seed, custom_map_options)
	self._biome = biome
	self._tile_size = self._biome:get_tile_size()
	self._macro_block_size = self._biome:get_macro_block_size()
	self._feature_size = self._biome:get_feature_block_size()
	self._terrain_info = self._biome:get_terrain_info()
	self._rng = rng
	self._seed = seed
	self._macro_blocks_per_tile = self._tile_size / self._macro_block_size

	dirt_holes = custom_map_options.dirt_holes
	self._valley_shapes = ValleyShapes(rng)
end

function GiantMicroMapGenerator:_add_plains_valleys(micro_map)
	if not dirt_holes then
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

return GiantMicroMapGenerator