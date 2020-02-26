local SimplexNoise = require 'stonehearth.lib.math.simplex_noise'

local ExtraMapTerrainDetailer = class()

function ExtraMapTerrainDetailer:_initialize_detailer(terrain_type)
	local fns = {}
	local config = self._detail_info[terrain_type]
	local step_size = self._terrain_info[terrain_type].step_size

	local custom_map_options = stonehearth.game_creation:get_extra_map_options()
	if custom_map_options.modes.waterworld then
		local depth_config = config.depth_function
		if depth_config.layer_thickness * depth_config.layer_count > 7 then
			depth_config.layer_thickness = depth_config.layer_thickness-1
			depth_config.layer_count = depth_config.layer_count -1
		end
		if depth_config.layer_thickness * depth_config.layer_count > 7 then
			depth_config.layer_thickness = depth_config.layer_thickness-1
			depth_config.layer_count = depth_config.layer_count -1
		end
	end

	local depth_layer_count = config.depth_function.layer_count
	if depth_layer_count > self._max_layers then self._max_layers = depth_layer_count end

	--returns number of layers of protrusion we should have
	local depth_fn = function(x,y)
		local depth_config = config.depth_function
		local bandlimit = depth_config.unit_length
		local layer_count = depth_config.layer_count
		local mean = 0.5*layer_count
		local range = depth_config.amplitude * layer_count
		--round to quantized values and get noise
		local q_x, q_y = x - (x-1)%depth_config.unit_length, y - (y-1)%depth_config.unit_length
		local depth = SimplexNoise.proportional_simplex_noise(depth_config.octaves, depth_config.persistence_ratio,
			bandlimit, mean, range, 1, self._seed, q_x, q_y)
		local result = radiant.math.round(depth)
		if result < 1 then return 1 end
		if result > layer_count then return layer_count end
		return result
	end

	--returns offset of height from terrain step maximum
	local height_fn = function(x,y)
		local height_config = config.height_function
		local bandlimit = height_config.unit_length
		local layer_thickness = height_config.layer_thickness
		local mean = 0.5 * step_size
		local range = height_config.amplitude * step_size
		--round to quantized values and get noise
		local q_x, q_y = x - (x-1)%height_config.unit_length, y - (y-1)%height_config.unit_length
		local height = SimplexNoise.proportional_simplex_noise(height_config.octaves, height_config.persistence_ratio,
			bandlimit, mean, range, 1, self._seed, q_x, q_y)
		local result = layer_thickness * radiant.math.round(height / layer_thickness)
		if result < 0 then return 0 end
		if result > step_size then return step_size end
		return result
	end

	--TODO bring it into the json file
	--this basically determines the height offset of layers 2 and up, depending on the previous layer
	local inset_fn = function(x,y)
		local bandlimit = 4
		local mean = 1.5
		local range = 5
		local unit_length = 4
		local q_x, q_y = x - (x-1)%unit_length, y - (y-1)%unit_length
		local height = SimplexNoise.proportional_simplex_noise(3, 0.02, bandlimit, mean, range, 1, self._seed, q_y, q_x)
		local result = radiant.math.round(height)
		if result < 1 then return 1 end
		return result
	end

	fns.depth_function = depth_fn
	fns.height_function = height_fn
	fns.inset_function = inset_fn
	return fns
end

return ExtraMapTerrainDetailer