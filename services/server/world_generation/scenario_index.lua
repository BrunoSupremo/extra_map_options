local ScenarioSelector = require 'stonehearth.services.server.world_generation.scenario_selector'
local ExtraMapScenarioIndex = class()

function ExtraMapScenarioIndex:_parse_scenario_index(json)
	local categories = {}
	local custom_map_options = stonehearth.game_creation:get_extra_map_options()
	local landmarks = custom_map_options.landmarks

	for name, properties in pairs(json.static.categories) do
		local category = {
			selector = ScenarioSelector(self._biome,self._rng)
		}
		for key, value in pairs(properties) do
			category[key] = value
		end
		local multiplier = 1
		if category.location_type == "surface" and category.activation_type == "immediate" then
			-- only for landmarks. it avoid nests, ores, etc...
			-- landmarks: 0 = none, 1 = default, 2 = plenty
			if landmarks == 0 then
				multiplier = 0
			end
			if landmarks == 2 and (string.find(name, "water") == nil) then
				--ignore multiplier for water features
				multiplier = 10
			end
		end
		category.density = (category.density * multiplier) / 100
		if category.density > 1 then
			-- cap at 1 as that was the expected upper limit before modding it
			category.density = 1
		end

		if category.max_count then
			-- if it is a list (and so far they all are),
			if type(category.max_count) == 'table' then
				-- avg the lowest and highest indexes, use that instead
				category.max_count = (category.max_count[1] + category.max_count[#category.max_count]) / 2
			end
			category.max_count = math.ceil(category.max_count * multiplier)
		end

		categories[name] = category
	end

	for _, file in pairs(json.static.scenarios) do
		local properties = radiant.resources.load_json(file)

		local category = categories[properties.category]
		if category then
			properties = self:_construct_map_from_type_arrays(properties, file)
			category.selector:add(properties)
		end
	end

	return categories
end

return ExtraMapScenarioIndex