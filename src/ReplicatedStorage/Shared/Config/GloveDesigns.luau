-- What each of the 50 gloves looks like. Used by Gloves/GloveBuilder for the gloves players wear
-- AND for the 3D shop previews, so both always show the same item.
--
-- A design picks one option for each component (see GloveBuilder for what each builds):
--   Shell     Mitt | Boxing | Gauntlet | Armored | Claw
--   Knuckles  Pad | Plates | Rivets | Ridge | Segmented | Spikes | Crystal | Rocks | Horns | Bolt | Blades
--   Cuff      Wrap | Strap | Bracer | Flared | Crown | Rings
--   Emblem    nil | Badge | Diamond | Sun | Star | Snowflake | Crest | Orb | Ring | Leaf
--   Extras    any of: Stitching, Seams, Plating, Inlay, Channels, Fins, Tail, Shards, Orbit, Swirl, Halo
--   Effect    nil | Glow | Sparks | Embers | Frost | Heat | Cosmic   (light/particles; keep for high tiers)
--   Scale     overall size; later gloves are a little bigger
-- Colors: Primary (shell), Secondary (armor/panels), Trim (metal/edges), Accent (details), Glow (energy).
-- Mats:   materials for Primary, Secondary and Trim. Glow parts are always Neon.

local rgb = Color3.fromRGB
local M = Enum.Material

export type Design = {
	Feature: string,
	Shell: string,
	Knuckles: string,
	Cuff: string,
	Emblem: string?,
	Extras: { string },
	Effect: string?,
	Scale: number,
	Colors: { Primary: Color3, Secondary: Color3, Trim: Color3, Accent: Color3, Glow: Color3? },
	Mats: { Primary: Enum.Material, Secondary: Enum.Material, Trim: Enum.Material },
}

local function colors(primary, secondary, trim, accent, glow)
	return { Primary = primary, Secondary = secondary, Trim = trim, Accent = accent, Glow = glow }
end

local function mats(primary, secondary, trim)
	return { Primary = primary, Secondary = secondary, Trim = trim }
end

local GloveDesigns: { [string]: Design } = {
	-- Greenfield Meadows: honest training gear that grows into emerald-and-gold war gauntlets.
	Greenfield_1 = {
		Feature = "Stitched cream mitts with a brass badge",
		Shell = "Mitt", Knuckles = "Pad", Cuff = "Wrap", Emblem = "Badge", Extras = { "Stitching" }, Scale = 1,
		Colors = colors(rgb(236, 224, 198), rgb(178, 132, 86), rgb(196, 160, 82), rgb(64, 50, 42)),
		Mats = mats(M.Leather, M.Leather, M.Metal),
	},
	Greenfield_2 = {
		Feature = "Carved wooden knuckle armor over leather",
		Shell = "Boxing", Knuckles = "Ridge", Cuff = "Strap", Extras = { "Plating" }, Scale = 1.02,
		Colors = colors(rgb(122, 80, 50), rgb(168, 118, 72), rgb(72, 48, 32), rgb(206, 170, 112)),
		Mats = mats(M.Leather, M.Wood, M.Leather),
	},
	Greenfield_3 = {
		Feature = "Classic boxing leather with layered wraps",
		Shell = "Boxing", Knuckles = "Pad", Cuff = "Wrap", Extras = { "Stitching", "Seams" }, Scale = 1.04,
		Colors = colors(rgb(94, 56, 36), rgb(124, 76, 46), rgb(42, 30, 24), rgb(232, 216, 190)),
		Mats = mats(M.Leather, M.Leather, M.Leather),
	},
	Greenfield_4 = {
		Feature = "Forged iron plates studded with rivets",
		Shell = "Gauntlet", Knuckles = "Rivets", Cuff = "Bracer", Extras = { "Plating" }, Scale = 1.05,
		Colors = colors(rgb(72, 74, 80), rgb(112, 114, 120), rgb(150, 150, 156), rgb(186, 186, 190)),
		Mats = mats(M.Metal, M.CorrodedMetal, M.DiamondPlate),
	},
	Greenfield_5 = {
		Feature = "Segmented heavy armor with a hazard emblem",
		Shell = "Boxing", Knuckles = "Segmented", Cuff = "Strap", Emblem = "Diamond", Extras = { "Seams" }, Scale = 1.08,
		Colors = colors(rgb(52, 52, 58), rgb(92, 94, 102), rgb(60, 60, 66), rgb(242, 190, 40)),
		Mats = mats(M.Leather, M.Metal, M.Metal),
	},
	Greenfield_6 = {
		Feature = "Angular red-and-black combat plating",
		Shell = "Gauntlet", Knuckles = "Spikes", Cuff = "Flared", Emblem = "Crest", Extras = { "Plating" }, Scale = 1.1,
		Colors = colors(rgb(198, 42, 40), rgb(30, 30, 34), rgb(62, 62, 68), rgb(255, 96, 64)),
		Mats = mats(M.SmoothPlastic, M.Metal, M.Metal),
	},
	Greenfield_7 = {
		Feature = "Blue-steel impact plates with cyan channels",
		Shell = "Armored", Knuckles = "Segmented", Cuff = "Bracer", Emblem = "Ring", Extras = { "Channels" }, Effect = "Glow", Scale = 1.12,
		Colors = colors(rgb(72, 102, 142), rgb(122, 152, 192), rgb(40, 50, 72), rgb(200, 220, 240), rgb(80, 220, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Greenfield_8 = {
		Feature = "Lightning-bolt knuckles crackling with sparks",
		Shell = "Gauntlet", Knuckles = "Bolt", Cuff = "Rings", Emblem = "Star", Extras = { "Channels" }, Effect = "Sparks", Scale = 1.14,
		Colors = colors(rgb(40, 44, 58), rgb(72, 78, 96), rgb(172, 178, 190), rgb(120, 190, 255), rgb(90, 170, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Greenfield_9 = {
		Feature = "Crowned gold-and-steel titan gauntlets",
		Shell = "Armored", Knuckles = "Plates", Cuff = "Crown", Emblem = "Crest", Extras = { "Plating", "Inlay" }, Effect = "Glow", Scale = 1.18,
		Colors = colors(rgb(228, 178, 52), rgb(150, 155, 166), rgb(255, 216, 104), rgb(30, 40, 86), rgb(255, 210, 120)),
		Mats = mats(M.Foil, M.Metal, M.Foil),
	},
	Greenfield_10 = {
		Feature = "Engraved emerald war gauntlets with a leaf crest",
		Shell = "Claw", Knuckles = "Blades", Cuff = "Crown", Emblem = "Leaf", Extras = { "Plating", "Inlay", "Fins" }, Effect = "Glow", Scale = 1.22,
		Colors = colors(rgb(30, 150, 82), rgb(40, 46, 44), rgb(240, 196, 72), rgb(130, 232, 150), rgb(120, 255, 160)),
		Mats = mats(M.SmoothPlastic, M.Metal, M.Foil),
	},

	-- Dust Devil Desert: weathered bronze, sandstone, dark leather, ember orange and desert gold.
	Desert_1 = {
		Feature = "Sand-colored wraps with bronze knuckles",
		Shell = "Boxing", Knuckles = "Plates", Cuff = "Wrap", Extras = { "Seams" }, Scale = 1.04,
		Colors = colors(rgb(214, 188, 142), rgb(176, 122, 62), rgb(150, 100, 52), rgb(112, 72, 42)),
		Mats = mats(M.Fabric, M.Metal, M.Metal),
	},
	Desert_2 = {
		Feature = "Chitin armor with a scorpion tail on the cuff",
		Shell = "Gauntlet", Knuckles = "Segmented", Cuff = "Strap", Extras = { "Tail" }, Scale = 1.06,
		Colors = colors(rgb(52, 38, 32), rgb(92, 62, 42), rgb(182, 122, 62), rgb(232, 162, 62)),
		Mats = mats(M.SmoothPlastic, M.SmoothPlastic, M.Metal),
	},
	Desert_3 = {
		Feature = "Wind-swept sandstone blades",
		Shell = "Armored", Knuckles = "Blades", Cuff = "Flared", Extras = { "Fins" }, Scale = 1.08,
		Colors = colors(rgb(210, 170, 120), rgb(172, 116, 56), rgb(132, 86, 46), rgb(242, 202, 142)),
		Mats = mats(M.Sandstone, M.Metal, M.Metal),
	},
	Desert_4 = {
		Feature = "Polished brass with turquoise mirage inlays",
		Shell = "Gauntlet", Knuckles = "Plates", Cuff = "Rings", Emblem = "Diamond", Extras = { "Inlay" }, Scale = 1.1,
		Colors = colors(rgb(222, 176, 92), rgb(42, 190, 180), rgb(182, 132, 62), rgb(62, 222, 202)),
		Mats = mats(M.Foil, M.SmoothPlastic, M.Metal),
	},
	Desert_5 = {
		Feature = "Canyon-stone knuckles bound in steel",
		Shell = "Boxing", Knuckles = "Rocks", Cuff = "Bracer", Extras = { "Plating" }, Scale = 1.12,
		Colors = colors(rgb(150, 92, 62), rgb(172, 104, 72), rgb(122, 122, 128), rgb(202, 142, 92)),
		Mats = mats(M.Leather, M.Rock, M.Metal),
	},
	Desert_6 = {
		Feature = "Heated bronze crowned with a sun emblem",
		Shell = "Gauntlet", Knuckles = "Plates", Cuff = "Flared", Emblem = "Sun", Extras = { "Channels" }, Effect = "Heat", Scale = 1.14,
		Colors = colors(rgb(190, 112, 52), rgb(240, 190, 72), rgb(122, 72, 32), rgb(255, 210, 120), rgb(255, 140, 40)),
		Mats = mats(M.Metal, M.Foil, M.Metal),
	},
	Desert_7 = {
		Feature = "Ceremonial gold with lapis royal inlays",
		Shell = "Armored", Knuckles = "Segmented", Cuff = "Crown", Emblem = "Diamond", Extras = { "Inlay" }, Scale = 1.16,
		Colors = colors(rgb(236, 190, 72), rgb(32, 52, 142), rgb(255, 216, 112), rgb(44, 72, 182)),
		Mats = mats(M.Foil, M.SmoothPlastic, M.Foil),
	},
	Desert_8 = {
		Feature = "Layered bronze in a swirl of sand energy",
		Shell = "Armored", Knuckles = "Blades", Cuff = "Rings", Extras = { "Fins", "Swirl" }, Effect = "Heat", Scale = 1.18,
		Colors = colors(rgb(172, 112, 52), rgb(212, 162, 92), rgb(112, 72, 36), rgb(242, 212, 152), rgb(255, 202, 122)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Desert_9 = {
		Feature = "Blackened titan plates with molten seams",
		Shell = "Gauntlet", Knuckles = "Plates", Cuff = "Bracer", Extras = { "Channels", "Plating" }, Effect = "Embers", Scale = 1.22,
		Colors = colors(rgb(38, 34, 32), rgb(72, 62, 58), rgb(122, 82, 52), rgb(255, 150, 60), rgb(255, 112, 32)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Desert_10 = {
		Feature = "Gold-and-obsidian sovereign sun gauntlets",
		Shell = "Armored", Knuckles = "Spikes", Cuff = "Crown", Emblem = "Sun", Extras = { "Inlay", "Fins" }, Effect = "Heat", Scale = 1.25,
		Colors = colors(rgb(240, 196, 72), rgb(26, 22, 30), rgb(255, 222, 122), rgb(255, 172, 62), rgb(255, 172, 62)),
		Mats = mats(M.Foil, M.Glass, M.Foil),
	},

	-- Frostbite Peaks: icy blue, glacier white, silver and dark steel.
	Frostbite_1 = {
		Feature = "Padded mitts stitched with snowflakes",
		Shell = "Mitt", Knuckles = "Pad", Cuff = "Wrap", Emblem = "Snowflake", Extras = { "Stitching" }, Scale = 1.06,
		Colors = colors(rgb(240, 245, 250), rgb(152, 202, 240), rgb(192, 216, 240), rgb(102, 172, 232)),
		Mats = mats(M.Fabric, M.Fabric, M.Fabric),
	},
	Frostbite_2 = {
		Feature = "Faceted ice knuckles and silver cuffs",
		Shell = "Boxing", Knuckles = "Crystal", Cuff = "Bracer", Extras = { "Seams" }, Scale = 1.08,
		Colors = colors(rgb(182, 216, 240), rgb(172, 226, 255), rgb(202, 206, 216), rgb(232, 244, 255)),
		Mats = mats(M.SmoothPlastic, M.Ice, M.Metal),
	},
	Frostbite_3 = {
		Feature = "Slate armor with layered frozen ridges",
		Shell = "Armored", Knuckles = "Ridge", Cuff = "Strap", Extras = { "Plating" }, Scale = 1.1,
		Colors = colors(rgb(92, 102, 118), rgb(212, 232, 246), rgb(62, 68, 80), rgb(182, 222, 246)),
		Mats = mats(M.Slate, M.Glacier, M.Metal),
	},
	Frostbite_4 = {
		Feature = "Crystal plates grown into the shell",
		Shell = "Gauntlet", Knuckles = "Crystal", Cuff = "Rings", Extras = { "Shards" }, Effect = "Glow", Scale = 1.12,
		Colors = colors(rgb(62, 92, 142), rgb(152, 222, 255), rgb(202, 208, 222), rgb(232, 248, 255), rgb(152, 232, 255)),
		Mats = mats(M.SmoothPlastic, M.Glass, M.Metal),
	},
	Frostbite_5 = {
		Feature = "Dark steel with engraved permafrost panels",
		Shell = "Gauntlet", Knuckles = "Plates", Cuff = "Bracer", Emblem = "Snowflake", Extras = { "Inlay" }, Scale = 1.14,
		Colors = colors(rgb(42, 50, 64), rgb(192, 226, 246), rgb(152, 162, 178), rgb(132, 202, 242)),
		Mats = mats(M.Metal, M.Ice, M.Metal),
	},
	Frostbite_6 = {
		Feature = "Aerodynamic silver with icy channels",
		Shell = "Armored", Knuckles = "Blades", Cuff = "Flared", Extras = { "Fins", "Channels" }, Effect = "Frost", Scale = 1.16,
		Colors = colors(rgb(202, 206, 216), rgb(232, 240, 250), rgb(92, 102, 122), rgb(182, 226, 255), rgb(122, 212, 255)),
		Mats = mats(M.Metal, M.SmoothPlastic, M.Metal),
	},
	Frostbite_7 = {
		Feature = "Spiked polar war gauntlets",
		Shell = "Gauntlet", Knuckles = "Spikes", Cuff = "Crown", Emblem = "Crest", Extras = { "Plating" }, Scale = 1.18,
		Colors = colors(rgb(132, 142, 158), rgb(222, 236, 250), rgb(62, 72, 92), rgb(102, 182, 242)),
		Mats = mats(M.Metal, M.Glacier, M.Metal),
	},
	Frostbite_8 = {
		Feature = "Colossal sculpted knuckle guards",
		Shell = "Armored", Knuckles = "Segmented", Cuff = "Bracer", Extras = { "Plating", "Shards" }, Effect = "Frost", Scale = 1.24,
		Colors = colors(rgb(92, 112, 142), rgb(162, 202, 236), rgb(62, 72, 92), rgb(212, 236, 255), rgb(152, 222, 255)),
		Mats = mats(M.Slate, M.Ice, M.Metal),
	},
	Frostbite_9 = {
		Feature = "Royal silver gauntlets set with cyan crystals",
		Shell = "Gauntlet", Knuckles = "Crystal", Cuff = "Crown", Emblem = "Diamond", Extras = { "Inlay", "Shards" }, Effect = "Glow", Scale = 1.22,
		Colors = colors(rgb(212, 216, 226), rgb(92, 222, 255), rgb(242, 246, 255), rgb(92, 222, 255), rgb(92, 222, 255)),
		Mats = mats(M.Metal, M.Glass, M.Foil),
	},
	Frostbite_10 = {
		Feature = "White-and-navy claws haloed in frost",
		Shell = "Claw", Knuckles = "Crystal", Cuff = "Crown", Emblem = "Snowflake", Extras = { "Fins", "Shards", "Halo" }, Effect = "Frost", Scale = 1.26,
		Colors = colors(rgb(244, 248, 255), rgb(22, 30, 72), rgb(202, 212, 232), rgb(132, 222, 255), rgb(122, 222, 255)),
		Mats = mats(M.SmoothPlastic, M.SmoothPlastic, M.Metal),
	},

	-- Inferno Kingdom: volcanic black, dark steel, copper, ember red and molten orange.
	Inferno_1 = {
		Feature = "Blackened gloves with ember-red stitching",
		Shell = "Boxing", Knuckles = "Pad", Cuff = "Wrap", Extras = { "Stitching" }, Scale = 1.08,
		Colors = colors(rgb(40, 34, 32), rgb(72, 58, 52), rgb(52, 40, 36), rgb(202, 52, 32)),
		Mats = mats(M.Leather, M.Leather, M.Leather),
	},
	Inferno_2 = {
		Feature = "Rough volcanic stone knuckles",
		Shell = "Boxing", Knuckles = "Rocks", Cuff = "Strap", Extras = { "Seams" }, Scale = 1.1,
		Colors = colors(rgb(62, 58, 56), rgb(82, 78, 76), rgb(112, 102, 96), rgb(160, 72, 52)),
		Mats = mats(M.Leather, M.Basalt, M.Metal),
	},
	Inferno_3 = {
		Feature = "Segmented knuckles with molten channels",
		Shell = "Gauntlet", Knuckles = "Segmented", Cuff = "Bracer", Extras = { "Channels" }, Effect = "Glow", Scale = 1.12,
		Colors = colors(rgb(46, 40, 40), rgb(72, 62, 60), rgb(92, 82, 80), rgb(255, 132, 52), rgb(255, 122, 32)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Inferno_4 = {
		Feature = "Forged steel with copper rivets",
		Shell = "Gauntlet", Knuckles = "Rivets", Cuff = "Flared", Extras = { "Plating" }, Effect = "Glow", Scale = 1.14,
		Colors = colors(rgb(112, 114, 120), rgb(82, 84, 90), rgb(192, 112, 62), rgb(210, 132, 72), rgb(255, 92, 42)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Inferno_5 = {
		Feature = "Sharp red-and-black striker armor",
		Shell = "Armored", Knuckles = "Spikes", Cuff = "Flared", Emblem = "Crest", Extras = { "Fins" }, Scale = 1.16,
		Colors = colors(rgb(172, 32, 32), rgb(26, 22, 22), rgb(62, 22, 22), rgb(255, 62, 42)),
		Mats = mats(M.SmoothPlastic, M.Metal, M.Metal),
	},
	Inferno_6 = {
		Feature = "Thick volcanic plates split by lava seams",
		Shell = "Armored", Knuckles = "Rocks", Cuff = "Bracer", Extras = { "Channels", "Plating" }, Effect = "Embers", Scale = 1.2,
		Colors = colors(rgb(42, 34, 32), rgb(72, 52, 46), rgb(92, 72, 62), rgb(255, 142, 52), rgb(255, 132, 42)),
		Mats = mats(M.Basalt, M.CrackedLava, M.Metal),
	},
	Inferno_7 = {
		Feature = "Horned obsidian grips with blood-red inlays",
		Shell = "Claw", Knuckles = "Horns", Cuff = "Crown", Emblem = "Diamond", Extras = { "Inlay" }, Effect = "Glow", Scale = 1.2,
		Colors = colors(rgb(24, 20, 26), rgb(142, 22, 32), rgb(122, 102, 92), rgb(222, 42, 42), rgb(222, 42, 42)),
		Mats = mats(M.Glass, M.SmoothPlastic, M.Metal),
	},
	Inferno_8 = {
		Feature = "Cracked armor glowing from within",
		Shell = "Armored", Knuckles = "Rocks", Cuff = "Bracer", Extras = { "Channels" }, Effect = "Embers", Scale = 1.22,
		Colors = colors(rgb(36, 32, 32), rgb(62, 42, 38), rgb(92, 62, 42), rgb(255, 112, 32), rgb(255, 102, 32)),
		Mats = mats(M.Basalt, M.CrackedLava, M.Metal),
	},
	Inferno_9 = {
		Feature = "Black-metal gauntlets bearing a fiery crest",
		Shell = "Gauntlet", Knuckles = "Spikes", Cuff = "Crown", Emblem = "Crest", Extras = { "Plating", "Fins", "Channels" }, Effect = "Embers", Scale = 1.24,
		Colors = colors(rgb(30, 28, 32), rgb(62, 58, 62), rgb(202, 122, 52), rgb(255, 152, 62), rgb(255, 122, 42)),
		Mats = mats(M.Metal, M.DiamondPlate, M.Metal),
	},
	Inferno_10 = {
		Feature = "Obsidian claws forged with molten gold",
		Shell = "Claw", Knuckles = "Blades", Cuff = "Crown", Emblem = "Sun", Extras = { "Inlay", "Fins", "Halo" }, Effect = "Embers", Scale = 1.28,
		Colors = colors(rgb(26, 22, 26), rgb(255, 190, 62), rgb(255, 216, 112), rgb(255, 142, 42), rgb(255, 142, 42)),
		Mats = mats(M.Glass, M.Foil, M.Foil),
	},

	-- Cosmic Frontier: obsidian, polished titanium, violet, electric cyan and white light.
	Cosmic_1 = {
		Feature = "Clean dark gloves with silver star emblems",
		Shell = "Boxing", Knuckles = "Pad", Cuff = "Strap", Emblem = "Star", Extras = { "Stitching" }, Scale = 1.12,
		Colors = colors(rgb(30, 32, 46), rgb(52, 56, 76), rgb(202, 206, 222), rgb(222, 226, 255)),
		Mats = mats(M.SmoothPlastic, M.SmoothPlastic, M.Metal),
	},
	Cosmic_2 = {
		Feature = "Violet armor with nebula-pink inlays",
		Shell = "Gauntlet", Knuckles = "Plates", Cuff = "Bracer", Extras = { "Inlay" }, Scale = 1.14,
		Colors = colors(rgb(112, 62, 192), rgb(72, 42, 132), rgb(82, 222, 255), rgb(255, 142, 232)),
		Mats = mats(M.SmoothPlastic, M.SmoothPlastic, M.SmoothPlastic),
	},
	Cosmic_3 = {
		Feature = "Titanium knuckles circled by tiny orbits",
		Shell = "Armored", Knuckles = "Segmented", Cuff = "Rings", Extras = { "Orbit" }, Scale = 1.16,
		Colors = colors(rgb(172, 176, 192), rgb(92, 96, 116), rgb(62, 66, 82), rgb(122, 202, 255), rgb(122, 202, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Cosmic_4 = {
		Feature = "Angular titanium with quantum energy lines",
		Shell = "Gauntlet", Knuckles = "Blades", Cuff = "Flared", Extras = { "Channels" }, Effect = "Glow", Scale = 1.18,
		Colors = colors(rgb(182, 186, 202), rgb(42, 46, 62), rgb(222, 226, 236), rgb(62, 232, 255), rgb(62, 232, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Cosmic_5 = {
		Feature = "Luminous white panels around a pulsar core",
		Shell = "Armored", Knuckles = "Plates", Cuff = "Bracer", Emblem = "Orb", Extras = { "Inlay" }, Effect = "Glow", Scale = 1.2,
		Colors = colors(rgb(242, 242, 252), rgb(142, 82, 232), rgb(202, 206, 222), rgb(182, 132, 255), rgb(232, 202, 255)),
		Mats = mats(M.SmoothPlastic, M.SmoothPlastic, M.Metal),
	},
	Cosmic_6 = {
		Feature = "Obsidian crushers around a dark singularity",
		Shell = "Gauntlet", Knuckles = "Segmented", Cuff = "Crown", Emblem = "Ring", Extras = { "Channels" }, Effect = "Cosmic", Scale = 1.22,
		Colors = colors(rgb(16, 14, 22), rgb(42, 32, 62), rgb(92, 82, 112), rgb(172, 92, 255), rgb(172, 92, 255)),
		Mats = mats(M.Glass, M.SmoothPlastic, M.Metal),
	},
	Cosmic_7 = {
		Feature = "Radiating silver-and-gold supernova panels",
		Shell = "Armored", Knuckles = "Spikes", Cuff = "Flared", Emblem = "Sun", Extras = { "Plating" }, Effect = "Glow", Scale = 1.24,
		Colors = colors(rgb(212, 216, 226), rgb(240, 196, 82), rgb(255, 232, 152), rgb(255, 222, 152), rgb(255, 222, 152)),
		Mats = mats(M.Metal, M.Foil, M.Foil),
	},
	Cosmic_8 = {
		Feature = "Segmented celestial armor with orbiting stars",
		Shell = "Armored", Knuckles = "Segmented", Cuff = "Crown", Emblem = "Star", Extras = { "Plating", "Orbit", "Inlay" }, Effect = "Cosmic", Scale = 1.28,
		Colors = colors(rgb(42, 46, 82), rgb(202, 206, 232), rgb(240, 200, 92), rgb(182, 202, 255), rgb(182, 202, 255)),
		Mats = mats(M.SmoothPlastic, M.Metal, M.Foil),
	},
	Cosmic_9 = {
		Feature = "Layered violet-and-cyan dimensional shards",
		Shell = "Claw", Knuckles = "Crystal", Cuff = "Rings", Emblem = "Diamond", Extras = { "Shards", "Channels" }, Effect = "Cosmic", Scale = 1.28,
		Colors = colors(rgb(102, 52, 182), rgb(62, 222, 255), rgb(32, 32, 52), rgb(122, 242, 255), rgb(122, 242, 255)),
		Mats = mats(M.SmoothPlastic, M.Glass, M.Metal),
	},
	Cosmic_10 = {
		Feature = "The ultimate black-titanium cosmic claws",
		Shell = "Claw", Knuckles = "Blades", Cuff = "Crown", Emblem = "Orb", Extras = { "Fins", "Orbit", "Halo", "Channels" }, Effect = "Cosmic", Scale = 1.32,
		Colors = colors(rgb(18, 18, 26), rgb(182, 186, 202), rgb(152, 82, 255), rgb(82, 232, 255), rgb(82, 232, 255)),
		Mats = mats(M.Metal, M.Metal, M.SmoothPlastic),
	},
}

return GloveDesigns
