local validator = radiant.validator
local ExtraMapGameCreationService = class()

function ExtraMapGameCreationService:new_game_command(session, response, num_tiles_x, num_tiles_y, seed, options, starting_data, extra_map_options)
   validator.expect_argument_types({'number', 'number', 'number', 'table', 'table', 'table'}, num_tiles_x, num_tiles_y, seed, options, starting_data, extra_map_options)
   validator.expect.num.positive(num_tiles_x)
   validator.expect.num.positive(num_tiles_y)
   validator.expect.table.fields({'biome_src'}, options)

   self._extra_map_options = extra_map_options

   --if no kingdom has been set for the player yet, set it to ascendancy
   if not stonehearth.player:get_kingdom(session.player_id) then
      stonehearth.player:add_kingdom(session.player_id, "stonehearth:kingdoms:ascendancy")
   end

   local pop = stonehearth.population:get_population(session.player_id)
   pop:set_game_options(options)

   self._starting_data = starting_data

   local overview_map = self:create_new_world(num_tiles_x, num_tiles_y, seed, options.biome_src)
   self.__saved_variables:mark_changed()

   return overview_map
end

function ExtraMapGameCreationService:_get_world_generation_radius()
	return self._extra_map_options.world_size
end

function ExtraMapGameCreationService:get_extra_map_options()
	return self._extra_map_options
end

return ExtraMapGameCreationService