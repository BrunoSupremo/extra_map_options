local Array2D = require 'stonehearth.services.server.world_generation.array_2D'
local Biome = require 'stonehearth.services.server.world_generation.biome'

local Sky_Lands_OverviewMap = class()

function Sky_Lands_OverviewMap:derive_overview_map(full_elevation_map, full_feature_map, origin_x, origin_y)
   -- -1 to remove half-macro_block offset from both ends
   local overview_width = full_elevation_map.width/2 - 1
   local overview_height = full_elevation_map.height/2 - 1
   local overview_map = Array2D(overview_width, overview_height)
   local biome = self._biome
   local a, b, terrain_code, forest_density, macro_block_info

   -- only needed if we need to reassemble the full map from the shards in the blueprint
   -- local full_feature_map, full_elevation_map
   -- full_feature_map, full_elevation_map = self:_assemble_maps(blueprint)

   for j=1, overview_height do
      for i=1, overview_width do
         a, b = _overview_map_to_feature_map_coords(i, j)

         macro_block_info = {
            terrain_code = self:_get_terrain_code(a, b, full_elevation_map, full_feature_map),
            is_sky = self:_is_sky(a, b, full_feature_map),
            forest_density = self:_get_forest_density(a, b, full_feature_map),
            wildlife_density = self:_get_wildlife_density(a, b, full_elevation_map),
            vegetation_density = self:_get_vegetation_density(a, b, full_feature_map),
            mineral_density = self:_get_mineral_density(a, b, full_elevation_map)
         }

         -- Hacky fixup so that forest doesn't show on top of water on the overview map
         -- This occurs because there are 4 feature cells per macro_block
         if macro_block_info.terrain_code == 'water' then
            macro_block_info.forest_density = 0
         end

         overview_map:set(i, j, macro_block_info)
      end
   end

   self._width = overview_width
   self._height = overview_height
   self._map = overview_map

   -- discard the half macro block offset on the outside
   local margin = self._macro_block_size/2
   -- location of the world origin in the coordinate system of the overview map
   self._origin_x = origin_x - margin
   self._origin_y = origin_y - margin
end

function Sky_Lands_OverviewMap:_is_sky(i, j, feature_map)
   local landscaper = self._landscaper
   local value
   local count = 0

   -- count the 4 feature blocks in this macro block
   feature_map:visit_block(i, j, 2, 2, function(value)
         if landscaper:is_sky_feature(value) then
            count = count + 1
         end
      end)

   return count
end

return Sky_Lands_OverviewMap