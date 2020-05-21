extra_map_options = {}
print("Extra Map Options version 20.5.21")

function extra_map_options:_on_required_loaded()
	for i, mod in ipairs(radiant.resources.get_mod_list()) do
		if mod == "tower_defense" then
			return
		end
	end

	local game_creation_service = radiant.mods.require('stonehearth.services.server.game_creation.game_creation_service')
	local custom = require('services.server.game_creation.game_creation_service')
	radiant.mixin(game_creation_service, custom)

	local terrain_detailer = radiant.mods.require('stonehearth.services.server.world_generation.terrain_detailer')
	local custom = require('services.server.world_generation.terrain_detailer')
	radiant.mixin(terrain_detailer, custom)

	local world_generation_service = radiant.mods.require('stonehearth.services.server.world_generation.world_generation_service')
	local custom = require('services.server.world_generation.world_generation_service')
	radiant.mixin(world_generation_service, custom)

	local micro_map_generator = radiant.mods.require('stonehearth.services.server.world_generation.micro_map_generator')
	local custom = require('services.server.world_generation.micro_map_generator')
	radiant.mixin(micro_map_generator, custom)

	local landscaper = radiant.mods.require('stonehearth.services.server.world_generation.landscaper')
	local custom = require('services.server.world_generation.landscaper')
	radiant.mixin(landscaper, custom)

	local custom_height_map_renderer = require('services.server.world_generation.height_map_renderer')
	local height_map_renderer = radiant.mods.require('stonehearth.services.server.world_generation.height_map_renderer')
	radiant.mixin(height_map_renderer, custom_height_map_renderer)

	local custom_overview_map = require('services.server.world_generation.overview_map')
	local overview_map = radiant.mods.require('stonehearth.services.server.world_generation.overview_map')
	radiant.mixin(overview_map, custom_overview_map)

	local custom_physics_service = require('services.server.physics.physics_service')
	local physics_service = radiant.mods.require('stonehearth.services.server.physics.physics_service')
	radiant.mixin(physics_service, custom_physics_service)

	local custom_qb_to_terrain = require('scenarios.static.landmarks.qb_to_terrain')
	local qb_to_terrain = radiant.mods.require('stonehearth.scenarios.static.landmarks.qb_to_terrain')
	radiant.mixin(qb_to_terrain, custom_qb_to_terrain)
end

radiant.events.listen_once(radiant, 'radiant:required_loaded', extra_map_options, extra_map_options._on_required_loaded)

return extra_map_options