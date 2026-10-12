--!strict
-- Maps a landing distance to a landing zone.

local WorldsConfig = require(script.Parent.Parent.Config.WorldsConfig)

local Zones = {}

-- Distances are rounded down to whole studs, so 50.9 is in the 0-50 zone and 51 is in the next.
function Zones.Find(worldId: string, distance: number): WorldsConfig.Zone
	local world = WorldsConfig.ById[worldId]
	assert(world, `Unknown world {worldId}`)
	if distance ~= distance then
		distance = 0
	end
	local studs = math.floor(math.max(distance, 0))
	local zones = world.Zones
	for i = #zones, 1, -1 do
		if studs >= zones[i].Min then
			return zones[i]
		end
	end
	return zones[1]
end

return Zones
