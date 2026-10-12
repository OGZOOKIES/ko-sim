-- Each world's surroundings, built with Roblox Terrain (cheap to render, looks natural) plus a few
-- groves of themed props:
--
--   * a ground layer 20 studs below the hub, rolling hills and a ring of distant mountains
--     (snow-capped in Frostbite), all kept clear of the hub, plaza and runway
--   * a lake beside the runway: water, ice or lava depending on the world
--   * Cosmic has no ground: rock islands under the hub and runway, and floating islets around
--
-- Terrain only writes inside this world's band, so worlds never overlap (2000 studs apart).

local Parts = require(script.Parent.Parts)
local Props = require(script.Parent.Props)

local Landscape = {}

local V = Vector3.new

type Hill = { Center: Vector3, Radius: number }

-- Areas that must stay flat and clear (world-relative): hub, Training Grounds plaza, runway.
local function clearAreas(runwayLength: number): { { number } }
	return {
		{ -300, 10, -150, 150 }, -- hub
		{ -300, -130, 0, 215 }, -- Training Grounds plaza
		{ -10, runwayLength + 60, -75, 75 }, -- runway and its sign pylons
	}
end

local function distanceToRect(x: number, z: number, rect: { number }): number
	local dx = math.max(rect[1] - x, 0, x - rect[2])
	local dz = math.max(rect[3] - z, 0, z - rect[4])
	return math.sqrt(dx * dx + dz * dz)
end

local function isClear(x: number, z: number, margin: number, areas: { { number } }): boolean
	for _, rect in areas do
		if distanceToRect(x, z, rect) < margin then
			return false
		end
	end
	return true
end

-- Ground height (world-relative) at x, z given the hills placed so far.
local function heightAt(x: number, z: number, groundY: number, hills: { Hill }): number
	local height = groundY
	for _, hill in hills do
		local dx, dz = x - hill.Center.X, z - hill.Center.Z
		local d2 = dx * dx + dz * dz
		local r2 = hill.Radius * hill.Radius
		if d2 < r2 then
			height = math.max(height, hill.Center.Y + math.sqrt(r2 - d2))
		end
	end
	return height
end

local function pick(rng: Random, minX: number, maxX: number, maxZ: number, minAbsZ: number): (number, number)
	local x = rng:NextNumber(minX, maxX)
	local z = rng:NextNumber(minAbsZ, maxZ) * (if rng:NextNumber() < 0.5 then -1 else 1)
	return x, z
end

local function lake(terrain: Terrain, o: Vector3, x: number, z: number, radius: number, liquid: string, groundY: number, parent: Instance)
	local center = o + V(x, groundY, z)
	if liquid == "Water" then
		terrain:FillCylinder(CFrame.new(center + V(0, -3, 0)), 8, radius, Enum.Material.Air)
		terrain:FillCylinder(CFrame.new(center + V(0, -5, 0)), 5, radius, Enum.Material.Water)
		terrain:FillCylinder(CFrame.new(center + V(0, -9, 0)), 4, radius + 4, Enum.Material.Sand)
	elseif liquid == "Ice" then
		terrain:FillCylinder(CFrame.new(center + V(0, -1, 0)), 3, radius, Enum.Material.Ice)
	elseif liquid == "Lava" then
		terrain:FillCylinder(CFrame.new(center + V(0, -1, 0)), 3, radius, Enum.Material.CrackedLava)
		-- A glowing surface sells the heat; one light keeps it cheap.
		local glow = Parts.Cylinder(parent, center + V(0, 0.4, 0), 0.2, radius * 1.6, {
			Name = "LavaGlow",
			Color = Color3.fromRGB(255, 110, 30),
			Material = Enum.Material.Neon,
			Transparency = 0.45,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 40)
		light.Range = 60
		light.Brightness = 1.2
		light.Parent = glow
	end
end

local function solidWorld(terrain: Terrain, o: Vector3, env, runwayLength: number, rng: Random, parent: Instance)
	local areas = clearAreas(runwayLength)
	local groundY = -20
	local minX, maxX = -560, runwayLength + 260
	local hills: { Hill } = {}

	-- Base ground: 16 studs thick, top at groundY.
	terrain:FillBlock(CFrame.new(o + V((minX + maxX) / 2, groundY - 8, 0)), V(maxX - minX, 16, 1000), env.Terrain.Ground)

	-- Rolling hills.
	for _ = 1, 40 do
		local radius = rng:NextNumber(30, 85)
		local x, z = pick(rng, minX + 60, maxX - 60, 430, 0)
		if isClear(x, z, radius * 0.85 + 12, areas) then
			local center = V(x, groundY - radius * 0.6, z)
			terrain:FillBall(o + center, radius, env.Terrain.Hills)
			table.insert(hills, { Center = center, Radius = radius })
		end
	end

	-- A ring of mountains along the far edges frames every view.
	-- (Sizes are kept moderate: terrain writes scale with volume and run at server start.)
	local step = (maxX - minX) / 7
	for i = 0, 7 do
		for _, side in { -1, 1 } do
			local radius = rng:NextNumber(85, 135)
			local x = minX + step * i + rng:NextNumber(-40, 40)
			local z = side * rng:NextNumber(430, 480)
			local center = V(x, groundY - radius * 0.3, z)
			terrain:FillBall(o + center, radius, env.Terrain.Cliff)
			if env.Terrain.Peaks then
				terrain:FillBall(o + center + V(0, radius * 0.48, 0), radius * 0.55, env.Terrain.Peaks)
			end
			table.insert(hills, { Center = center, Radius = radius })
		end
	end

	-- A lake beside the runway.
	local lakes = {}
	if env.Terrain.Liquid then
		for _, spot in { { runwayLength * 0.35, 230, 75 }, { runwayLength * 0.75, -250, 60 } } do
			local x, z, radius = spot[1], spot[2], spot[3]
			if isClear(x, z, radius + 10, areas) then
				lake(terrain, o, x, z, radius, env.Terrain.Liquid, groundY, parent)
				table.insert(lakes, { x, z, radius })
			end
		end
	end

	-- Groves of props on the ground, avoiding lakes and clear areas.
	local props = Instance.new("Model")
	props.Name = "Props"
	props.Parent = parent
	for _ = 1, 18 do
		local cx, cz = pick(rng, minX + 40, maxX - 40, 380, 80)
		if isClear(cx, cz, 30, areas) then
			for _ = 1, rng:NextInteger(3, 6) do
				local x, z = cx + rng:NextNumber(-26, 26), cz + rng:NextNumber(-26, 26)
				local wet = false
				for _, l in lakes do
					if (V(x, 0, z) - V(l[1], 0, l[2])).Magnitude < l[3] + 6 then
						wet = true
					end
				end
				if not wet and isClear(x, z, 12, areas) then
					local y = heightAt(x, z, groundY, hills)
					if y < groundY + 30 then
						Props.Place(props, env.Props, o + V(x, y - 0.3, z), rng, env.PropColors)
					end
				end
			end
		end
	end
end

local function voidWorld(terrain: Terrain, o: Vector3, env, runwayLength: number, rng: Random, parent: Instance)
	local areas = clearAreas(runwayLength)
	local top = -20

	-- Rock beneath the hub and plaza: stacked balls taper into a rounded underside.
	for _, spot in { { -150, 0, 125 }, { -215, 160, 70 }, { -40, 0, 80 } } do
		local x, z, radius = spot[1], spot[2], spot[3]
		terrain:FillBall(o + V(x, top - radius, z), radius, env.Terrain.Ground)
		terrain:FillBall(o + V(x, top - radius * 1.7, z), radius * 0.6, env.Terrain.Cliff)
		terrain:FillBall(o + V(x, top - radius * 2.2, z), radius * 0.3, env.Terrain.Cliff)
	end
	-- A rocky spine under the runway.
	for x = 0, runwayLength, 90 do
		local radius = rng:NextNumber(48, 62)
		terrain:FillBall(o + V(x, top - radius, rng:NextNumber(-8, 8)), radius, env.Terrain.Hills)
		terrain:FillBall(o + V(x, top - radius * 1.8, 0), radius * 0.45, env.Terrain.Cliff)
	end

	-- Floating islets with crystals.
	local props = Instance.new("Model")
	props.Name = "Props"
	props.Parent = parent
	for _ = 1, 22 do
		local x, z = pick(rng, -500, runwayLength + 200, 420, 90)
		if isClear(x, z, 40, areas) then
			local radius = rng:NextNumber(10, 26)
			local y = rng:NextNumber(-70, 50)
			-- Rounded underside, flat top at y.
			terrain:FillBall(o + V(x, y - radius, z), radius, env.Terrain.Hills)
			terrain:FillBlock(CFrame.new(o + V(x, y - 1, z)), V(radius * 1.1, 2, radius * 1.1), env.Terrain.Ground)
			if rng:NextNumber() < 0.7 then
				Props.Place(props, env.Props, o + V(x, y, z), rng, env.PropColors)
			end
		end
	end

	-- Distant planets give depth without terrain.
	for i = 1, 6 do
		local size = rng:NextNumber(40, 110)
		local x = -400 + i * (runwayLength + 600) / 6
		local z = (if i % 2 == 0 then 1 else -1) * rng:NextNumber(520, 700)
		local planet = Parts.Ball(props, o + V(x, rng:NextNumber(60, 260), z), size, {
			Name = "Planet",
			Color = env.PropColors[(i % #env.PropColors) + 1]:Lerp(Color3.new(0.15, 0.12, 0.25), 0.4),
			Material = Enum.Material.SmoothPlastic,
		})
		if i % 2 == 1 then
			Parts.Decor(props, {
				Name = "PlanetRing",
				Shape = Enum.PartType.Cylinder,
				Size = V(0.4, size * 1.8, size * 1.8),
				CFrame = planet.CFrame * CFrame.Angles(0, 0, math.rad(90) + rng:NextNumber(-0.4, 0.4)),
				Color = Color3.fromRGB(210, 200, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.6,
			})
		end
	end
end

function Landscape.Build(parent: Instance, o: Vector3, world, env, runwayLength: number)
	local model = Instance.new("Model")
	model.Name = "Landscape"
	model.Parent = parent
	local rng = Random.new(world.Order * 997)
	local terrain = workspace.Terrain
	if env.Terrain.Void then
		voidWorld(terrain, o, env, runwayLength, rng, model)
	else
		solidWorld(terrain, o, env, runwayLength, rng, model)
	end
end

return Landscape
