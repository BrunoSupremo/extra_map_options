local WeightedSet = require 'stonehearth.lib.algorithms.weighted_set'

local ExtraMapScenarioSelector = class()

function ExtraMapScenarioSelector:select_scenarios(density, habitat_volumes)
	local rng = self._rng
	local selected = {}
	local biome_alias = stonehearth.world_generation:get_biome_alias()
	local custom_map_options = stonehearth.game_creation:get_extra_map_options()
	local landmarks = custom_map_options.landmarks

	for habitat_type, volume in pairs(habitat_volumes) do
		local candidates = WeightedSet(self._rng)

		for name, properties in pairs(self._scenarios) do
			local is_valid_habitat = properties.habitat_types[habitat_type]
			local is_valid_biome = not properties.biomes or properties.biomes[biome_alias]
			if is_valid_habitat and is_valid_biome then
				local volume = self:_get_scenario_volume(properties)
				local effective_weight = properties.weight / volume
				candidates:add(properties, effective_weight)
			end
		end

		if candidates:get_total_weight() > 0 then
			local num = volume * density
			while num > 0 do
				local choose = num >= 1 or rng:get_real(0, 1) < num
				if choose then
					local properties = candidates:choose_random()
					if landmarks == 2 and properties.plenty_reduction_factor then
						if rng:get_real(0,1) < properties.plenty_reduction_factor then
							table.insert(selected, properties)
						end
					else
						table.insert(selected, properties)
					end
				end
				num = num - 1
			end
		end
	end

	return selected
end

return ExtraMapScenarioSelector