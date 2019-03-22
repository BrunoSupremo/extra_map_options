local landmark_lib = require 'stonehearth.lib.landmark.landmark_lib'
local Point3 = _radiant.csg.Point3

local Sky_Lands_QBToTerrain = class()

function Sky_Lands_QBToTerrain:initialize(properties, context, services)
	local x, z = services:to_world_coordinates(properties.size.length / 2, properties.size.width / 2)
	local has_block = false
	for i=1,40 do
		if radiant.terrain.get_block_tag_at(Point3(x, i*5, z)) then
			has_block = true
			break
		end
	end
	if has_block then
		local location = radiant.terrain.get_point_on_terrain(Point3(x, 0, z))
		if location.y >1 then
			landmark_lib.create_landmark(Point3(location.x, location.y, location.z), properties.data)
		end
	end
end

return Sky_Lands_QBToTerrain