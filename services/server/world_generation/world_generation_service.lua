local Array2D =	require 'stonehearth.services.server.world_generation.array_2D'
local Timer =	require 'stonehearth.services.server.world_generation.timer'
local Point3 =	_radiant.csg.Point3

local ExtraMapWorldGenerationService = class()

function ExtraMapWorldGenerationService:set_blueprint(blueprint)
	assert(self._biome_generation_data, "cannot find biome_generation_data")
	local seconds = Timer.measure(
		function()
			local tile_size = self._biome_generation_data:get_tile_size()
			local macro_blocks_per_tile = tile_size / self._biome_generation_data:get_macro_block_size()
			local blueprint_generator = self.blueprint_generator
			local micro_map_generator = self._micro_map_generator
			local landscaper = self._landscaper
			local full_micro_map, full_underground_micro_map
			local full_elevation_map, full_underground_elevation_map, full_feature_map, sky_map, full_habitat_map

			full_micro_map, full_elevation_map = micro_map_generator:generate_micro_map(blueprint.width, blueprint.height)
			full_underground_micro_map, full_underground_elevation_map = micro_map_generator:generate_underground_micro_map(full_micro_map)

			full_feature_map = Array2D(full_elevation_map.width, full_elevation_map.height)
			sky_map = Array2D(full_elevation_map.width, full_elevation_map.height)

			-- determine which features will be placed in which cells
			landscaper:mark_sky(full_elevation_map, full_feature_map, sky_map)
			landscaper:mark_water_bodies(full_elevation_map, full_feature_map)
			landscaper:mark_river_bodies(full_elevation_map, full_feature_map)
			landscaper:mark_trees(full_elevation_map, full_feature_map)
			landscaper:mark_berry_bushes(full_elevation_map, full_feature_map)
			landscaper:mark_plants(full_elevation_map, full_feature_map)
			landscaper:mark_boulders(full_elevation_map, full_feature_map)

			full_habitat_map = self._habitat_manager:derive_habitat_map(full_elevation_map, full_feature_map)

			-- shard the maps and store in the blueprint
			-- micro_maps are overlapping so they need a different sharding function
			-- these maps are at macro_block_size resolution (32x32)
			blueprint_generator:store_micro_map(blueprint, "micro_map", full_micro_map, macro_blocks_per_tile)
			blueprint_generator:store_micro_map(blueprint, "underground_micro_map", full_underground_micro_map, macro_blocks_per_tile)
			-- these maps are at feature_size resolution (16x16)
			blueprint_generator:shard_and_store_map(blueprint, "elevation_map", full_elevation_map)
			blueprint_generator:shard_and_store_map(blueprint, "underground_elevation_map", full_underground_elevation_map)
			blueprint_generator:shard_and_store_map(blueprint, "feature_map", full_feature_map)
			blueprint_generator:shard_and_store_map(blueprint, "sky_map", sky_map)
			blueprint_generator:shard_and_store_map(blueprint, "habitat_map", full_habitat_map)

			-- location of the world origin in the coordinate system of the blueprint
			blueprint.origin_x = math.floor(blueprint.width * tile_size / 2)
			blueprint.origin_y = math.floor(blueprint.height * tile_size / 2)

			-- create the overview map
			self.overview_map:derive_overview_map(full_elevation_map, full_feature_map, blueprint.origin_x, blueprint.origin_y)

			self._blueprint = blueprint
		end
		)
	log:info('Blueprint population time: %.3fs', seconds)
end

function ExtraMapWorldGenerationService:_generate_tile_internal(i, j)
	local blueprint = self._blueprint
	local tile_size = self._biome_generation_data:get_tile_size()
	local tile_map, underground_tile_map, tile_info, tile_seed
	local micro_map, underground_micro_map
	local elevation_map, underground_elevation_map, feature_map, sky_map, habitat_map
	local offset_x, offset_y
	local metadata = {}

	tile_info = blueprint:get(i, j)
	assert(not tile_info.generated)

	log:info('Generating tile (%d,%d)', i, j)

	-- calculate the world offset of the tile
	offset_x, offset_y = self:get_tile_origin(i, j, blueprint)

	-- make each tile deterministic on its coordinates (and game seed)
	tile_seed = self:_get_tile_seed(i, j)
	self._rng:set_seed(tile_seed)

	-- get the various maps from the blueprint
	micro_map = tile_info.micro_map
	underground_micro_map = tile_info.underground_micro_map
	elevation_map = tile_info.elevation_map
	underground_elevation_map = tile_info.underground_elevation_map
	feature_map = tile_info.feature_map
	sky_map = tile_info.sky_map
	habitat_map = tile_info.habitat_map

	-- generate the high resolution heightmap for the tile
	local seconds = Timer.measure(
		function()
			tile_map = self._terrain_generator:generate_tile(i,j,micro_map)
			underground_tile_map = self._terrain_generator:generate_underground_tile(underground_micro_map)
		end
		)
	log:info('Terrain generation time: %.3fs', seconds)
	self:_yield()

	-- render heightmap to region3
	local tile_region = self:_render_heightmap_to_region(tile_map, underground_tile_map)
	self:_yield()

	metadata.sky_region = self:_place_sky(tile_region, tile_map, sky_map, offset_x, offset_y)
	metadata.sky_region:translate(Point3(offset_x, 0, offset_y))
	self:_yield()

	metadata.water_region = self:_place_water_bodies(tile_region, tile_map, feature_map)
	metadata.water_region:translate(Point3(offset_x, 0, offset_y))
	self:_yield()

	self:_add_region_to_terrain(tile_region, offset_x, offset_y)
	self:_yield()

	-- place flora
	self:_place_flora(tile_map, feature_map, offset_x, offset_y)
	self:_yield()

	-- place scenarios
	-- INCONSISTENCY: Ore veins extend across tiles that are already generated, but are truncated across tiles
	-- that have yet to be generated.
	self:_place_scenarios(habitat_map, elevation_map, underground_elevation_map, offset_x, offset_y)
	self:_yield()

	tile_info.generated = true

	return metadata
end

function ExtraMapWorldGenerationService:_place_sky(tile_region, tile_map, feature_map, offset_x, offset_y)
	local sky_region
	local seconds = Timer.measure(
		function()
			sky_region = self._landscaper:place_sky(tile_region, tile_map, feature_map, offset_x, offset_y)
		end
		)

	log:info('Place sky time: %.3fs', seconds)
	return sky_region
end

return ExtraMapWorldGenerationService