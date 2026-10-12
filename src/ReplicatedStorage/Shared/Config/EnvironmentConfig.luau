-- How each world's environment is built and lit: architecture palette, terrain, props and sky.
--
-- Every world shares one architectural language (warm stone, deep navy roofs, gold trim, a
-- restrained energy accent); the stone, ground, props and light change to give each world its
-- own identity.
--
-- Terrain
--   Ground / Hills / Cliff   Roblox terrain materials for the base, rolling hills and mountains
--   Peaks                    optional material capping the mountains (snow)
--   Liquid                   "Water" | "Ice" | "Lava" | nil  (a lake beside the runway)
--   Void                     true = no ground: floating rock islands instead (Cosmic)
-- Props: "Groves" | "Oasis" | "Pines" | "Volcanic" | "Asteroids"

local rgb = Color3.fromRGB
local M = Enum.Material

export type Environment = {
	Floor: Color3,
	FloorMaterial: Enum.Material,
	Lawn: Color3,
	LawnMaterial: Enum.Material,
	Stone: Color3,
	StoneDark: Color3,
	StoneMaterial: Enum.Material,
	Roof: Color3,
	Trim: Color3,
	Energy: Color3,
	Wood: Color3,
	Terrain: {
		Ground: Enum.Material,
		Hills: Enum.Material,
		Cliff: Enum.Material,
		Peaks: Enum.Material?,
		Liquid: string?,
		Void: boolean?,
	},
	Props: string,
	PropColors: { Color3 },
	Sky: { Tint: Color3, CloudCover: number, CloudDensity: number, CloudColor: Color3 },
}

local EnvironmentConfig: { [string]: Environment } = {
	Greenfield = {
		Floor = rgb(196, 188, 172),
		FloorMaterial = M.Pavement,
		Lawn = rgb(98, 172, 76),
		LawnMaterial = M.Grass,
		Stone = rgb(214, 206, 190),
		StoneDark = rgb(150, 142, 128),
		StoneMaterial = M.Limestone,
		Roof = rgb(30, 40, 86),
		Trim = rgb(240, 196, 80),
		Energy = rgb(80, 220, 255),
		Wood = rgb(124, 86, 56),
		Terrain = { Ground = M.Grass, Hills = M.LeafyGrass, Cliff = M.Rock, Liquid = "Water" },
		Props = "Groves",
		PropColors = { rgb(76, 160, 64), rgb(104, 190, 80), rgb(56, 130, 56) },
		Sky = { Tint = rgb(255, 252, 245), CloudCover = 0.55, CloudDensity = 0.5, CloudColor = rgb(255, 255, 255) },
	},
	Desert = {
		Floor = rgb(224, 196, 150),
		FloorMaterial = M.Sandstone,
		Lawn = rgb(206, 176, 120),
		LawnMaterial = M.Sand,
		Stone = rgb(222, 188, 138),
		StoneDark = rgb(170, 128, 84),
		StoneMaterial = M.Sandstone,
		Roof = rgb(36, 44, 92),
		Trim = rgb(232, 176, 70),
		Energy = rgb(255, 150, 60),
		Wood = rgb(140, 96, 58),
		Terrain = { Ground = M.Sand, Hills = M.Sand, Cliff = M.Sandstone, Liquid = "Water" },
		Props = "Oasis",
		PropColors = { rgb(110, 150, 70), rgb(150, 176, 82), rgb(182, 140, 90) },
		Sky = { Tint = rgb(255, 244, 226), CloudCover = 0.2, CloudDensity = 0.3, CloudColor = rgb(255, 236, 210) },
	},
	Frostbite = {
		Floor = rgb(214, 224, 236),
		FloorMaterial = M.Slate,
		Lawn = rgb(236, 242, 250),
		LawnMaterial = M.Snow,
		Stone = rgb(200, 210, 224),
		StoneDark = rgb(110, 122, 142),
		StoneMaterial = M.Slate,
		Roof = rgb(32, 46, 92),
		Trim = rgb(206, 214, 232),
		Energy = rgb(110, 220, 255),
		Wood = rgb(96, 72, 56),
		Terrain = { Ground = M.Snow, Hills = M.Snow, Cliff = M.Glacier, Peaks = M.Snow, Liquid = "Ice" },
		Props = "Pines",
		PropColors = { rgb(52, 104, 82), rgb(226, 238, 248), rgb(130, 210, 245) },
		Sky = { Tint = rgb(240, 248, 255), CloudCover = 0.7, CloudDensity = 0.6, CloudColor = rgb(236, 244, 255) },
	},
	Inferno = {
		Floor = rgb(78, 70, 70),
		FloorMaterial = M.Basalt,
		Lawn = rgb(60, 44, 40),
		LawnMaterial = M.CrackedLava,
		Stone = rgb(96, 86, 84),
		StoneDark = rgb(44, 38, 38),
		StoneMaterial = M.Basalt,
		Roof = rgb(30, 24, 30),
		Trim = rgb(214, 132, 62),
		Energy = rgb(255, 110, 40),
		Wood = rgb(52, 40, 36),
		Terrain = { Ground = M.Basalt, Hills = M.Basalt, Cliff = M.CrackedLava, Liquid = "Lava" },
		Props = "Volcanic",
		PropColors = { rgb(40, 32, 30), rgb(255, 110, 40), rgb(90, 60, 50) },
		Sky = { Tint = rgb(255, 228, 214), CloudCover = 0.8, CloudDensity = 0.75, CloudColor = rgb(120, 70, 60) },
	},
	Cosmic = {
		Floor = rgb(56, 52, 84),
		FloorMaterial = M.Slate,
		Lawn = rgb(40, 34, 70),
		LawnMaterial = M.Glass,
		Stone = rgb(92, 88, 124),
		StoneDark = rgb(36, 32, 58),
		StoneMaterial = M.Slate,
		Roof = rgb(26, 22, 52),
		Trim = rgb(200, 206, 230),
		Energy = rgb(120, 220, 255),
		Wood = rgb(60, 54, 90),
		Terrain = { Ground = M.Rock, Hills = M.Slate, Cliff = M.Basalt, Void = true },
		Props = "Asteroids",
		PropColors = { rgb(150, 100, 255), rgb(90, 220, 255), rgb(255, 120, 220) },
		Sky = { Tint = rgb(236, 232, 255), CloudCover = 0, CloudDensity = 0, CloudColor = rgb(160, 140, 255) },
	},
}

return EnvironmentConfig
