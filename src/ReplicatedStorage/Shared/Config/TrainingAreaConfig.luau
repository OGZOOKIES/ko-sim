-- How the Training Grounds look. Purely visual: bag multipliers and unlock rules stay in
-- BagsConfig and are enforced by the server. Shared so the client can match labels and effects.

local rgb = Color3.fromRGB

export type BagVisual = {
	Body: Color3,
	BodyMaterial: Enum.Material,
	Diameter: number,
	Length: number,
	Trim: Color3,
	TrimMaterial: Enum.Material,
	Bands: number,
	Cap: Color3,
	CapMaterial: Enum.Material,
	Strap: Color3,
	Mat: Color3,
	Ribs: boolean?,
	Crown: boolean?,
	Light: Color3?,
	Particles: Color3?,
	Orbiters: { Color3 }?,
}

local TrainingAreaConfig = {}

-- Positions are in studs relative to each world's origin (runway start). See WorldBuilder.
TrainingAreaConfig.Layout = {
	Center = Vector3.new(-212, 0, 120), -- center of the pavilion floor
	BagSpacing = 16,
	FloorHeight = 1.2, -- top of the pavilion floor above the hub
	BeamBottom = 21.2, -- underside of the beam the bags hang from
	BagBottom = 3, -- bags start this high above the pavilion floor
	-- The plaza extends the hub behind the pavilion.
	PlazaMinX = -290,
	PlazaMaxX = -140,
	PlazaMaxZ = 195,
	BoardPosition = Vector3.new(-176, 0, 78),
}

TrainingAreaConfig.Palette = {
	Navy = rgb(30, 40, 86),
	DeepNavy = rgb(20, 26, 60),
	Roof = rgb(26, 34, 76),
	Cyan = rgb(70, 220, 255),
	Gold = rgb(255, 198, 70),
	Stone = rgb(214, 208, 196),
	StoneDark = rgb(168, 162, 150),
	Marble = rgb(240, 236, 228),
	Path = rgb(200, 194, 182),
	Wood = rgb(125, 86, 56),
	Soil = rgb(92, 64, 44),
	WarmLight = rgb(255, 196, 130),
}

-- Plant colours per world decoration style, so the plaza fits every world.
TrainingAreaConfig.Plants = {
	Trees = { rgb(76, 170, 70), rgb(104, 196, 84), rgb(58, 140, 60) },
	Cacti = { rgb(110, 160, 70), rgb(140, 180, 80), rgb(90, 140, 60) },
	Pines = { rgb(70, 130, 100), rgb(200, 225, 235), rgb(90, 150, 115) },
	Volcanic = { rgb(150, 50, 40), rgb(200, 90, 40), rgb(110, 40, 40) },
	Space = { rgb(140, 90, 230), rgb(90, 200, 230), rgb(190, 110, 240) },
}

TrainingAreaConfig.Flowers = {
	rgb(255, 120, 170),
	rgb(255, 220, 80),
	rgb(250, 250, 255),
	rgb(170, 120, 255),
	rgb(255, 150, 80),
}

-- One entry per bag in BagsConfig.
TrainingAreaConfig.Bags = {
	Basic = {
		Body = rgb(214, 66, 46),
		BodyMaterial = Enum.Material.Leather,
		Diameter = 3.6,
		Length = 7.4,
		Trim = rgb(48, 34, 30),
		TrimMaterial = Enum.Material.Leather,
		Bands = 1,
		Cap = rgb(70, 44, 36),
		CapMaterial = Enum.Material.Leather,
		Strap = rgb(40, 30, 28),
		Mat = rgb(214, 66, 46),
	},
	Reinforced = {
		Body = rgb(46, 112, 220),
		BodyMaterial = Enum.Material.Leather,
		Diameter = 3.8,
		Length = 7.6,
		Trim = rgb(205, 210, 220),
		TrimMaterial = Enum.Material.Metal,
		Bands = 3,
		Cap = rgb(185, 190, 200),
		CapMaterial = Enum.Material.Metal,
		Strap = rgb(60, 62, 72),
		Mat = rgb(46, 112, 220),
		Ribs = true,
	},
	Heavy = {
		Body = rgb(48, 48, 56),
		BodyMaterial = Enum.Material.Leather,
		Diameter = 4.6,
		Length = 8,
		Trim = rgb(135, 140, 150),
		TrimMaterial = Enum.Material.DiamondPlate,
		Bands = 4,
		Cap = rgb(95, 98, 108),
		CapMaterial = Enum.Material.DiamondPlate,
		Strap = rgb(30, 30, 34),
		Mat = rgb(90, 92, 104),
		Ribs = true,
	},
	Titan = {
		Body = rgb(245, 196, 50),
		BodyMaterial = Enum.Material.Leather,
		Diameter = 4.4,
		Length = 8,
		Trim = rgb(255, 222, 120),
		TrimMaterial = Enum.Material.Foil,
		Bands = 3,
		Cap = rgb(255, 210, 90),
		CapMaterial = Enum.Material.Foil,
		Strap = rgb(110, 80, 30),
		Mat = rgb(245, 196, 50),
		Crown = true,
	},
	Elemental = {
		Body = rgb(22, 178, 140),
		BodyMaterial = Enum.Material.SmoothPlastic,
		Diameter = 4.2,
		Length = 8,
		Trim = rgb(130, 255, 225),
		TrimMaterial = Enum.Material.Neon,
		Bands = 3,
		Cap = rgb(16, 90, 80),
		CapMaterial = Enum.Material.Metal,
		Strap = rgb(16, 70, 62),
		Mat = rgb(22, 178, 140),
		Light = rgb(90, 255, 210),
		Particles = rgb(120, 255, 220),
	},
	Cosmic = {
		Body = rgb(112, 42, 196),
		BodyMaterial = Enum.Material.SmoothPlastic,
		Diameter = 4.4,
		Length = 8,
		Trim = rgb(80, 230, 255),
		TrimMaterial = Enum.Material.Neon,
		Bands = 2,
		Cap = rgb(222, 64, 200),
		CapMaterial = Enum.Material.SmoothPlastic,
		Strap = rgb(50, 20, 90),
		Mat = rgb(150, 70, 230),
		Crown = true,
		Light = rgb(190, 110, 255),
		Particles = rgb(220, 140, 255),
		Orbiters = { rgb(80, 230, 255), rgb(255, 90, 220), rgb(255, 255, 255) },
	},
}

-- CollectionService tags the client uses to find and animate pieces of the area.
TrainingAreaConfig.Tags = {
	Bag = "TrainingBag",
	Label = "TrainingBagLabel",
	Board = "BagProgressBoard",
	Spin = "TrainingSpin",
	Orbiter = "TrainingOrbiter",
}

return TrainingAreaConfig
