local validator = radiant.validator
local log = radiant.log.create_logger('world_generation')

GiantGameCreationService = class()

local giant_mod_custom_radius = 2

function GiantGameCreationService:new_game_command(session, response, num_tiles_x, num_tiles_y, seed, options, starting_data, custom_map_options)
   validator.expect_argument_types({'number', 'number', 'number', 'table', 'table'}, num_tiles_x, num_tiles_y, seed, options, starting_data)
   validator.expect.num.positive(num_tiles_x)
   validator.expect.num.positive(num_tiles_y)
   validator.expect.table.fields({'biome_src'}, options)

   giant_mod_custom_radius = custom_map_options.world_size

   --if no kingdom has been set for the player yet, set it to ascendancy
   if not stonehearth.player:get_kingdom(session.player_id) then
      stonehearth.player:add_kingdom(session.player_id, "stonehearth:kingdoms:ascendancy")
   end

   local pop = stonehearth.population:get_population(session.player_id)
   pop:set_game_options(options)

   self._starting_data = starting_data

   local overview_map = self:create_new_world(num_tiles_x, num_tiles_y, seed, options.biome_src, custom_map_options)
   self.__saved_variables:mark_changed()

   return overview_map
end

function GiantGameCreationService:create_new_world(num_tiles_x, num_tiles_y, seed, biome_src, custom_map_options)
   local seed = radiant.util.get_config('world_generation.seed', seed)
   local generation_method = radiant.util.get_config('world_generation.method', 'default')
   local wgs = stonehearth.world_generation
   local blueprint
   local tile_margin

   log:info('using biome %s', biome_src)

   wgs:create_new_game(seed, biome_src, true, custom_map_options)

   -- Temporary merge code. The javascript client may eventually hold state about the original dimensions.
   if generation_method == 'tiny' then
      tile_margin = 0
      blueprint = wgs.blueprint_generator:get_empty_blueprint(2, 2) -- (2,2) is minimum size
   else
      -- generate extra tiles along the edge of the map so that we still have a full N x N set of tiles if we embark on the edge
      tile_margin = self:_get_world_generation_radius()
      num_tiles_x = num_tiles_x + 2*tile_margin
      num_tiles_y = num_tiles_y + 2*tile_margin
      blueprint = wgs.blueprint_generator:get_empty_blueprint(num_tiles_x, num_tiles_y)
   end

   wgs:set_blueprint(blueprint)

   return self:_get_overview_map(tile_margin)
end

function GiantGameCreationService:_get_world_generation_radius()
   return giant_mod_custom_radius
end

return GiantGameCreationService