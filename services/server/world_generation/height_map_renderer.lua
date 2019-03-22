local Array2D = require 'stonehearth.services.server.world_generation.array_2D'
local Rect2 = _radiant.csg.Rect2
local Point2 = _radiant.csg.Point2
local Cube3 = _radiant.csg.Cube3
local Point3 = _radiant.csg.Point3
local Region2 = _radiant.csg.Region2
local Region3 = _radiant.csg.Region3
local HeightMapCPP = _radiant.csg.HeightMap

local Sky_Lands_HeightMapRenderer = class()

function Sky_Lands_HeightMapRenderer:render_height_map_to_region(region3, height_map, underground_height_map)
   assert(height_map.width == self._tile_size)
   assert(height_map.height == self._tile_size)
   assert(underground_height_map.width == self._tile_size)
   assert(underground_height_map.height == self._tile_size)

   local surface_region = self:_convert_height_map_to_region3(height_map, self._add_land_to_region)
   region3:add_region(surface_region)

   local underground_region = self:_convert_height_map_to_region3(underground_height_map, self._add_mountains_to_region)
   region3:add_region(underground_region)

   region3:optimize('Sky_Lands_heightmaprenderer:render_height_map_to_region()')
end

return Sky_Lands_HeightMapRenderer
