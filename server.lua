giant_map = {}
print("Extra Map Options version 19.3.13")

function giant_map:_on_required_loaded()
	local game_creation_service = radiant.mods.require('stonehearth.services.server.game_creation.game_creation_service')
	local custom = require('services.server.game_creation.game_creation_service')
	radiant.mixin(game_creation_service, custom)

	local world_generation_service = radiant.mods.require('stonehearth.services.server.world_generation.world_generation_service')
	local custom = require('services.server.world_generation.world_generation_service')
	radiant.mixin(world_generation_service, custom)

	local micro_map_generator = radiant.mods.require('stonehearth.services.server.world_generation.micro_map_generator')
	local custom = require('services.server.world_generation.micro_map_generator')
	radiant.mixin(micro_map_generator, custom)

	local landscaper = radiant.mods.require('stonehearth.services.server.world_generation.landscaper')
	local custom = require('services.server.world_generation.landscaper')
	radiant.mixin(landscaper, custom)
end

radiant.events.listen_once(radiant, 'radiant:required_loaded', giant_map, giant_map._on_required_loaded)

return giant_map