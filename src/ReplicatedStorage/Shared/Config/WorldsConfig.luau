--!strict
-- The five worlds: unlock requirements, landing zones, launch scaling and visual theme.
--
-- Landing zones are listed as { Name, starting distance in studs, Wins }.
-- Each zone ends one stud before the next one starts and the last zone never ends,
-- so ranges can't overlap or leave gaps. Landing distances are rounded down to whole
-- studs before lookup, so every landing belongs to exactly one zone.
--
-- Launch distance (see Logic/Formulas.LaunchDistance):
--   distance = FinalZoneStart * (Strength / FullStrength) ^ DistanceExponent * charge and upgrade bonuses
-- FullStrength is the launch strength that reaches the final zone with a normal charge.

export type Zone = {
	Index: number,
	Name: string,
	Min: number,
	Max: number,
	Wins: number,
}

export type LightingTheme = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereDensity: number,
	AtmosphereHaze: number,
}

export type Theme = {
	Icon: string,
	Ground: Color3,
	GroundMaterial: Enum.Material,
	Hub: Color3,
	HubMaterial: Enum.Material,
	Path: Color3,
	RunwayA: Color3,
	RunwayB: Color3,
	RunwayMaterial: Enum.Material,
	Accent: Color3,
	Decor: string,
	Lighting: LightingTheme,
}

export type World = {
	Id: string,
	Order: number,
	Name: string,
	Description: string,
	UnlockCost: number,
	RequiredRebirths: number,
	FullStrength: number,
	Zones: { Zone },
	Theme: Theme,
}

local function zones(list: { { any } }): { Zone }
	local result = {}
	for i, entry in list do
		local nextEntry = list[i + 1]
		table.insert(result, {
			Index = i,
			Name = entry[1] :: string,
			Min = entry[2] :: number,
			Max = if nextEntry then (nextEntry[2] :: number) - 1 else math.huge,
			Wins = entry[3] :: number,
		})
	end
	return result
end

local rgb = Color3.fromRGB

local list: { World } = {
	{
		Id = "Greenfield",
		Order = 1,
		Name = "Greenfield Meadows",
		Description = "Grassy fields, hay bales and a giant oak. Every champion starts here.",
		UnlockCost = 0,
		RequiredRebirths = 0,
		FullStrength = 1e6,
		Zones = zones({
			{ "Starter Field", 0, 1 },
			{ "Wooden Fence", 51, 2 },
			{ "Hay Bale Hill", 101, 4 },
			{ "Windmill Ridge", 176, 7 },
			{ "Farmer's Bridge", 251, 12 },
			{ "Apple Orchard", 351, 20 },
			{ "Rolling Hills", 451, 35 },
			{ "Waterfall Bend", 576, 60 },
			{ "Giant Oak", 701, 100 },
			{ "Meadow Summit", 851, 175 },
		}),
		Theme = {
			Icon = "🌿",
			Ground = rgb(92, 170, 74),
			GroundMaterial = Enum.Material.Grass,
			Hub = rgb(110, 190, 86),
			HubMaterial = Enum.Material.Grass,
			Path = rgb(214, 190, 140),
			RunwayA = rgb(126, 204, 96),
			RunwayB = rgb(104, 184, 80),
			RunwayMaterial = Enum.Material.Grass,
			Accent = rgb(255, 214, 64),
			Decor = "Trees",
			Lighting = {
				ClockTime = 14,
				Brightness = 2.5,
				Ambient = rgb(120, 130, 120),
				OutdoorAmbient = rgb(150, 160, 150),
				AtmosphereColor = rgb(200, 230, 255),
				AtmosphereDecay = rgb(120, 170, 220),
				AtmosphereDensity = 0.25,
				AtmosphereHaze = 0.5,
			},
		},
	},
	{
		Id = "Desert",
		Order = 2,
		Name = "Dust Devil Desert",
		Description = "Rolling dunes and sandstone ruins under a blazing sun.",
		UnlockCost = 2000,
		RequiredRebirths = 1,
		FullStrength = 1e9,
		Zones = zones({
			{ "Sandy Start", 0, 150 },
			{ "Cactus Patch", 61, 225 },
			{ "Tumbleweed Flats", 121, 350 },
			{ "Scorpion Dunes", 211, 500 },
			{ "Oasis Springs", 301, 750 },
			{ "Sandstone Arch", 421, 1100 },
			{ "Buried Temple", 541, 1600 },
			{ "Mirage Valley", 691, 2400 },
			{ "Pharaoh's Pyramid", 841, 3500 },
			{ "Sun-Scorched Summit", 1021, 5000 },
		}),
		Theme = {
			Icon = "🏜️",
			Ground = rgb(222, 186, 120),
			GroundMaterial = Enum.Material.Sand,
			Hub = rgb(232, 200, 140),
			HubMaterial = Enum.Material.Sandstone,
			Path = rgb(190, 140, 90),
			RunwayA = rgb(240, 208, 150),
			RunwayB = rgb(224, 186, 126),
			RunwayMaterial = Enum.Material.Sandstone,
			Accent = rgb(255, 140, 40),
			Decor = "Cacti",
			Lighting = {
				ClockTime = 15.5,
				Brightness = 3,
				Ambient = rgb(150, 120, 90),
				OutdoorAmbient = rgb(180, 150, 110),
				AtmosphereColor = rgb(255, 220, 170),
				AtmosphereDecay = rgb(230, 160, 90),
				AtmosphereDensity = 0.35,
				AtmosphereHaze = 2,
			},
		},
	},
	{
		Id = "Frostbite",
		Order = 3,
		Name = "Frostbite Peaks",
		Description = "Snowy mountains, frozen lakes and glowing ice crystals.",
		UnlockCost = 50000,
		RequiredRebirths = 4,
		FullStrength = 1e12,
		Zones = zones({
			{ "Snowy Steps", 0, 4000 },
			{ "Frozen Pond", 71, 6000 },
			{ "Icicle Alley", 141, 9000 },
			{ "Penguin Point", 246, 13000 },
			{ "Glacier Gap", 351, 19000 },
			{ "Yeti Cave", 491, 28000 },
			{ "Crystal Cavern", 631, 42000 },
			{ "Avalanche Run", 806, 62000 },
			{ "Aurora Ridge", 981, 90000 },
			{ "Frostbite Pinnacle", 1191, 135000 },
		}),
		Theme = {
			Icon = "❄️",
			Ground = rgb(235, 242, 250),
			GroundMaterial = Enum.Material.Snow,
			Hub = rgb(220, 232, 245),
			HubMaterial = Enum.Material.Snow,
			Path = rgb(150, 190, 230),
			RunwayA = rgb(200, 225, 250),
			RunwayB = rgb(175, 210, 245),
			RunwayMaterial = Enum.Material.Glacier,
			Accent = rgb(90, 200, 255),
			Decor = "Pines",
			Lighting = {
				ClockTime = 10,
				Brightness = 2.5,
				Ambient = rgb(130, 140, 160),
				OutdoorAmbient = rgb(160, 175, 200),
				AtmosphereColor = rgb(220, 235, 255),
				AtmosphereDecay = rgb(150, 190, 240),
				AtmosphereDensity = 0.4,
				AtmosphereHaze = 1.5,
			},
		},
	},
	{
		Id = "Inferno",
		Order = 4,
		Name = "Inferno Kingdom",
		Description = "Rivers of lava, obsidian spikes and a volcano that never sleeps.",
		UnlockCost = 1500000,
		RequiredRebirths = 10,
		FullStrength = 1e15,
		Zones = zones({
			{ "Ash Fields", 0, 100000 },
			{ "Ember Road", 81, 150000 },
			{ "Magma Moat", 161, 225000 },
			{ "Obsidian Gate", 281, 340000 },
			{ "Fire Bridge", 401, 500000 },
			{ "Lava Falls", 561, 750000 },
			{ "Dragon's Lair", 721, 1100000 },
			{ "Molten Throne", 921, 1650000 },
			{ "Eruption Point", 1121, 2500000 },
			{ "Inferno Crown", 1361, 3750000 },
		}),
		Theme = {
			Icon = "🌋",
			Ground = rgb(50, 40, 40),
			GroundMaterial = Enum.Material.CrackedLava,
			Hub = rgb(70, 60, 60),
			HubMaterial = Enum.Material.Basalt,
			Path = rgb(140, 60, 40),
			RunwayA = rgb(90, 70, 70),
			RunwayB = rgb(70, 54, 54),
			RunwayMaterial = Enum.Material.Basalt,
			Accent = rgb(255, 90, 30),
			Decor = "Volcanic",
			Lighting = {
				ClockTime = 18.3,
				Brightness = 2,
				Ambient = rgb(140, 70, 50),
				OutdoorAmbient = rgb(150, 80, 60),
				AtmosphereColor = rgb(255, 140, 90),
				AtmosphereDecay = rgb(200, 60, 30),
				AtmosphereDensity = 0.45,
				AtmosphereHaze = 2.5,
			},
		},
	},
	{
		Id = "Cosmic",
		Order = 5,
		Name = "Cosmic Frontier",
		Description = "Glowing platforms floating between planets at the edge of space.",
		UnlockCost = 40000000,
		RequiredRebirths = 20,
		FullStrength = 1e18,
		Zones = zones({
			{ "Launch Pad", 0, 3000000 },
			{ "Asteroid Belt", 91, 4500000 },
			{ "Moon Base", 181, 6750000 },
			{ "Comet Trail", 316, 10000000 },
			{ "Nebula Drift", 451, 15000000 },
			{ "Ring Planet", 631, 22500000 },
			{ "Star Forge", 811, 34000000 },
			{ "Black Hole Rim", 1036, 51000000 },
			{ "Galaxy Core", 1261, 76000000 },
			{ "Edge of the Universe", 1531, 115000000 },
		}),
		Theme = {
			Icon = "🪐",
			Ground = rgb(30, 24, 56),
			GroundMaterial = Enum.Material.Slate,
			Hub = rgb(54, 44, 96),
			HubMaterial = Enum.Material.SmoothPlastic,
			Path = rgb(120, 90, 220),
			RunwayA = rgb(70, 56, 130),
			RunwayB = rgb(56, 44, 110),
			RunwayMaterial = Enum.Material.SmoothPlastic,
			Accent = rgb(170, 110, 255),
			Decor = "Space",
			Lighting = {
				ClockTime = 0,
				Brightness = 1.5,
				Ambient = rgb(110, 90, 160),
				OutdoorAmbient = rgb(120, 100, 180),
				AtmosphereColor = rgb(150, 120, 255),
				AtmosphereDecay = rgb(60, 30, 140),
				AtmosphereDensity = 0.3,
				AtmosphereHaze = 1,
			},
		},
	},
}

local WorldsConfig = {
	List = list,
	ById = {} :: { [string]: World },

	-- Studs of runway past the start of the final zone.
	RunwayExtension = 300,

	-- How quickly distance grows with strength. Lower = each extra zone needs more Power.
	DistanceExponent = 0.4,
}

for _, world in list do
	WorldsConfig.ById[world.Id] = world
end

return WorldsConfig
