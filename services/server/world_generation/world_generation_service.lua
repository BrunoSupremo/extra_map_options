local BlueprintGenerator = 		require 'stonehearth.services.server.world_generation.blueprint_generator'
local MicroMapGenerator = 		require 'stonehearth.services.server.world_generation.micro_map_generator'
local Landscaper = 				require 'stonehearth.services.server.world_generation.landscaper'
local TerrainGenerator = 		require 'stonehearth.services.server.world_generation.terrain_generator'
local HeightMapRenderer = 		require 'stonehearth.services.server.world_generation.height_map_renderer'
local HabitatManager = 			require 'stonehearth.services.server.world_generation.habitat_manager'
local OverviewMap = 			require 'stonehearth.services.server.world_generation.overview_map'
local ScenarioIndex = 			require 'stonehearth.services.server.world_generation.scenario_index'
local OreScenarioSelector = 	require 'stonehearth.services.server.world_generation.ore_scenario_selector'
local SurfaceScenarioSelector = require 'stonehearth.services.server.world_generation.surface_scenario_selector'

GiantWorldGenerationService = class()

function GiantWorldGenerationService:create_new_game(seed, biome_src, async, custom_map_options)
	self:set_seed(seed)
	self._async = async
	self._enable_scenarios = radiant.util.get_config('enable_scenarios', true)

	self:_setup_biome_data(biome_src)

	local biome_generation_data = self._biome_generation_data

	self._micro_map_generator = MicroMapGenerator(biome_generation_data, self._rng, seed, custom_map_options)
	self._terrain_generator = TerrainGenerator(biome_generation_data, self._rng, seed)
	self._height_map_renderer = HeightMapRenderer(biome_generation_data)

	self._landscaper = Landscaper(biome_generation_data, self._rng, seed, custom_map_options)
	self._habitat_manager = HabitatManager(biome_generation_data, self._landscaper)
	self.overview_map = OverviewMap(biome_generation_data, self._landscaper)

	self._scenario_index = ScenarioIndex(biome_generation_data, self._rng)
	self._ore_scenario_selector = OreScenarioSelector(self._scenario_index, biome_generation_data, self._rng)
	self._surface_scenario_selector = SurfaceScenarioSelector(self._scenario_index, biome_generation_data, self._rng)

	stonehearth.static_scenario:create_new_game(seed)
	stonehearth.dynamic_scenario:start()

	self.blueprint_generator = BlueprintGenerator(biome_generation_data)

	self._sv._starting_location = nil
	self.__saved_variables:mark_changed()
end

return GiantWorldGenerationService