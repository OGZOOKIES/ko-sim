-- What each of the 50 gloves looks like. Gloves/GloveBuilder turns these into models for the
-- gloves players wear AND for the shop previews, so both always match. Purely visual: stats and
-- prices live in GlovesConfig.
--
-- Every glove is a real hand shape: a rounded shell, a palm panel, a curved two-segment thumb,
-- a knuckle section and a cuff with a wrist opening. A design picks how each part is built:
--
--   Shell     Mitt | Boxing | Heavy        padded gloves (one smooth shell)
--             Combat                       slim padded glove with curled fingers showing
--             Gauntlet | Claw              armored hand with segmented fingers (Claw adds talons)
--   Knuckles  Padded | Ridge | Plates | Guard | Segmented | Spikes | Crystal | Rocks | Horns |
--             Bolt | Blades | Wood
--   Back      back-of-hand armor: None | Panel | Layered | Wood | Scales | Leaf | Ribs | Sun | Crystal
--   Cuff      Wrap | Lace | Strap | Bracer | Flared | Crown | Rings
--   Emblem    nil | Badge | Diamond | Sun | Star | Snowflake | Crest | Orb | Ring | Leaf
--   EmblemOn  "Back" (back of the hand, default) or "Cuff"
--   Thumb     which colour the thumb uses: "Primary" (default) | "Secondary" | "Trim"
--   Extras    Stitching | Seams | Straps | Rivets | Inlay | Channels | Fins | Tail | Shards | Swirl
--   Effect    nil | Glow | Sparks | Embers | Frost | Heat | Cosmic  (kept subtle; the model must
--             look right without it)
--   Scale     overall size; the family grows a little with each tier
--
-- Colors: Primary (shell), Secondary (palm, armor panels), Trim (metal, piping, straps),
--         Accent (stitching, wraps, small details), Glow (energy inlays). Mats match the first three.

local rgb = Color3.fromRGB
local M = Enum.Material

export type Design = {
	Feature: string,
	Shell: string,
	Knuckles: string,
	Back: string,
	Cuff: string,
	Emblem: string?,
	EmblemOn: string?,
	Thumb: string?,
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
	-- Greenfield Meadows: honest training gear growing into emerald-and-gold war gauntlets.
	Greenfield_1 = {
		Feature = "Cream padded mitts, tan palm, dark wraps and a brass badge",
		Shell = "Mitt", Knuckles = "Ridge", Back = "None", Cuff = "Wrap", Emblem = "Badge", Thumb = "Secondary",
		Extras = { "Stitching" }, Scale = 1,
		Colors = colors(rgb(238, 226, 200), rgb(182, 134, 86), rgb(198, 162, 84), rgb(58, 48, 44)),
		Mats = mats(M.Leather, M.Leather, M.Metal),
	},
	Greenfield_2 = {
		Feature = "Carved wooden knuckle guards strapped over padded leather",
		Shell = "Boxing", Knuckles = "Wood", Back = "Wood", Cuff = "Strap",
		Extras = {}, Scale = 1.02,
		Colors = colors(rgb(120, 78, 50), rgb(170, 120, 74), rgb(62, 42, 30), rgb(198, 160, 90)),
		Mats = mats(M.Leather, M.Wood, M.Leather),
	},
	Greenfield_3 = {
		Feature = "Classic dark-brown boxing leather with layered wraps",
		Shell = "Boxing", Knuckles = "Padded", Back = "None", Cuff = "Lace",
		Extras = { "Stitching", "Seams" }, Scale = 1.04,
		Colors = colors(rgb(96, 58, 36), rgb(126, 80, 50), rgb(46, 32, 24), rgb(232, 214, 186)),
		Mats = mats(M.Leather, M.Leather, M.Leather),
	},
	Greenfield_4 = {
		Feature = "Curved forged-iron knuckle plates riveted over padding",
		Shell = "Boxing", Knuckles = "Plates", Back = "None", Cuff = "Bracer",
		Extras = { "Rivets", "Straps" }, Scale = 1.05,
		Colors = colors(rgb(70, 54, 42), rgb(84, 86, 92), rgb(118, 120, 126), rgb(176, 176, 180)),
		Mats = mats(M.Leather, M.CorrodedMetal, M.Metal),
	},
	Greenfield_5 = {
		Feature = "Thick padded body with layered impact armor",
		Shell = "Heavy", Knuckles = "Segmented", Back = "Layered", Cuff = "Strap", Emblem = "Diamond", EmblemOn = "Cuff",
		Extras = { "Seams" }, Scale = 1.06,
		Colors = colors(rgb(48, 48, 54), rgb(78, 80, 88), rgb(36, 36, 40), rgb(242, 190, 40)),
		Mats = mats(M.Leather, M.Leather, M.Metal),
	},
	Greenfield_6 = {
		Feature = "Red padded knuckles, black palm and a signature wrist strap",
		Shell = "Combat", Knuckles = "Padded", Back = "Ribs", Cuff = "Strap", Emblem = "Crest", EmblemOn = "Cuff", Thumb = "Secondary",
		Extras = { "Stitching" }, Scale = 1.06,
		Colors = colors(rgb(196, 40, 40), rgb(30, 30, 34), rgb(52, 52, 58), rgb(255, 90, 70)),
		Mats = mats(M.Leather, M.Leather, M.Metal),
	},
	Greenfield_7 = {
		Feature = "Graphite padding, curved steel guard and cyan channels",
		Shell = "Boxing", Knuckles = "Guard", Back = "Panel", Cuff = "Bracer",
		Extras = { "Channels" }, Effect = "Glow", Scale = 1.08,
		Colors = colors(rgb(44, 54, 76), rgb(70, 84, 112), rgb(150, 166, 190), rgb(210, 222, 240), rgb(80, 220, 255)),
		Mats = mats(M.Leather, M.SmoothPlastic, M.Metal),
	},
	Greenfield_8 = {
		Feature = "Dark steel gauntlets with lightning-engraved guards",
		Shell = "Gauntlet", Knuckles = "Bolt", Back = "Layered", Cuff = "Flared",
		Extras = { "Channels" }, Effect = "Sparks", Scale = 1.08,
		Colors = colors(rgb(42, 46, 58), rgb(76, 82, 98), rgb(176, 182, 196), rgb(120, 190, 255), rgb(90, 170, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Greenfield_9 = {
		Feature = "Sculpted gold knuckles on layered steel with a titan crest",
		Shell = "Gauntlet", Knuckles = "Plates", Back = "Layered", Cuff = "Crown", Emblem = "Crest",
		Extras = { "Inlay" }, Effect = "Glow", Scale = 1.12,
		Colors = colors(rgb(70, 74, 84), rgb(120, 126, 138), rgb(232, 184, 60), rgb(30, 40, 86), rgb(255, 214, 130)),
		Mats = mats(M.Metal, M.Metal, M.Foil),
	},
	Greenfield_10 = {
		Feature = "Emerald armor with gold leaf motifs around a central crest",
		Shell = "Gauntlet", Knuckles = "Guard", Back = "Leaf", Cuff = "Crown", Emblem = "Crest",
		Extras = { "Inlay", "Fins" }, Effect = "Glow", Scale = 1.14,
		Colors = colors(rgb(26, 128, 72), rgb(40, 46, 44), rgb(236, 192, 72), rgb(130, 232, 150), rgb(120, 255, 160)),
		Mats = mats(M.SmoothPlastic, M.Metal, M.Foil),
	},

	-- Dust Devil Desert: sandstone, bronze, aged brass, dark leather; scorpion, dune and sun motifs.
	Desert_1 = {
		Feature = "Sand-colored wraps over bronze-plated knuckles",
		Shell = "Boxing", Knuckles = "Plates", Back = "None", Cuff = "Wrap",
		Extras = { "Seams" }, Scale = 1.06,
		Colors = colors(rgb(214, 188, 142), rgb(176, 122, 62), rgb(160, 108, 54), rgb(196, 170, 128)),
		Mats = mats(M.Fabric, M.Metal, M.Metal),
	},
	Desert_2 = {
		Feature = "Chitin-scaled gauntlets with a scorpion tail on the cuff",
		Shell = "Gauntlet", Knuckles = "Segmented", Back = "Scales", Cuff = "Strap",
		Extras = { "Tail" }, Scale = 1.08,
		Colors = colors(rgb(50, 38, 32), rgb(92, 62, 42), rgb(182, 122, 62), rgb(232, 162, 62)),
		Mats = mats(M.Leather, M.SmoothPlastic, M.Metal),
	},
	Desert_3 = {
		Feature = "Heavy sandstone plates swept back like dunes",
		Shell = "Heavy", Knuckles = "Blades", Back = "Ribs", Cuff = "Flared",
		Extras = { "Fins" }, Scale = 1.08,
		Colors = colors(rgb(208, 168, 118), rgb(174, 118, 58), rgb(132, 86, 46), rgb(242, 202, 142)),
		Mats = mats(M.Sandstone, M.Metal, M.Metal),
	},
	Desert_4 = {
		Feature = "Polished brass combat gloves with turquoise inlays",
		Shell = "Combat", Knuckles = "Plates", Back = "Layered", Cuff = "Rings", Emblem = "Diamond",
		Extras = { "Inlay" }, Scale = 1.1,
		Colors = colors(rgb(150, 98, 52), rgb(222, 176, 92), rgb(196, 146, 70), rgb(52, 210, 196)),
		Mats = mats(M.Leather, M.Foil, M.Metal),
	},
	Desert_5 = {
		Feature = "Canyon-stone knuckles riveted into thick leather",
		Shell = "Heavy", Knuckles = "Rocks", Back = "Panel", Cuff = "Bracer",
		Extras = { "Rivets" }, Scale = 1.1,
		Colors = colors(rgb(140, 86, 58), rgb(172, 104, 72), rgb(122, 122, 128), rgb(202, 142, 92)),
		Mats = mats(M.Leather, M.Rock, M.Metal),
	},
	Desert_6 = {
		Feature = "Heated bronze gauntlets with a sunburst back plate",
		Shell = "Gauntlet", Knuckles = "Guard", Back = "Sun", Cuff = "Flared",
		Extras = { "Channels" }, Effect = "Heat", Scale = 1.12,
		Colors = colors(rgb(150, 92, 46), rgb(190, 112, 52), rgb(240, 190, 72), rgb(255, 210, 120), rgb(255, 140, 40)),
		Mats = mats(M.Metal, M.Metal, M.Foil),
	},
	Desert_7 = {
		Feature = "Ceremonial gold over lapis, crowned at the wrist",
		Shell = "Gauntlet", Knuckles = "Segmented", Back = "Layered", Cuff = "Crown", Emblem = "Diamond",
		Extras = { "Inlay" }, Scale = 1.14,
		Colors = colors(rgb(32, 52, 142), rgb(236, 190, 72), rgb(255, 216, 112), rgb(44, 72, 182)),
		Mats = mats(M.SmoothPlastic, M.Foil, M.Foil),
	},
	Desert_8 = {
		Feature = "Bronze claws wrapped in a swirl of sand energy",
		Shell = "Claw", Knuckles = "Blades", Back = "Ribs", Cuff = "Rings",
		Extras = { "Swirl" }, Effect = "Heat", Scale = 1.14,
		Colors = colors(rgb(110, 72, 40), rgb(172, 112, 52), rgb(212, 162, 92), rgb(242, 212, 152), rgb(255, 202, 122)),
		Mats = mats(M.Leather, M.Metal, M.Metal),
	},
	Desert_9 = {
		Feature = "Blackened titan gloves split by molten seams",
		Shell = "Heavy", Knuckles = "Guard", Back = "Layered", Cuff = "Bracer",
		Extras = { "Channels" }, Effect = "Embers", Scale = 1.16,
		Colors = colors(rgb(38, 34, 32), rgb(68, 60, 56), rgb(120, 82, 52), rgb(255, 150, 60), rgb(255, 112, 32)),
		Mats = mats(M.Leather, M.Metal, M.Metal),
	},
	Desert_10 = {
		Feature = "Gold-and-obsidian sovereign claws with a sun crest",
		Shell = "Claw", Knuckles = "Spikes", Back = "Sun", Cuff = "Crown", Emblem = "Crest",
		Extras = { "Inlay" }, Effect = "Heat", Scale = 1.18,
		Colors = colors(rgb(26, 22, 30), rgb(40, 34, 40), rgb(240, 196, 72), rgb(255, 172, 62), rgb(255, 172, 62)),
		Mats = mats(M.Glass, M.Metal, M.Foil),
	},

	-- Frostbite Peaks: curved silver, frost blue, crystal plates; snow and glacier motifs.
	Frostbite_1 = {
		Feature = "Padded white mitts stitched with a snowflake",
		Shell = "Mitt", Knuckles = "Padded", Back = "Panel", Cuff = "Wrap", Emblem = "Snowflake",
		Extras = { "Stitching" }, Scale = 1.06,
		Colors = colors(rgb(240, 245, 250), rgb(156, 204, 240), rgb(196, 218, 240), rgb(104, 172, 232)),
		Mats = mats(M.Fabric, M.Fabric, M.Fabric),
	},
	Frostbite_2 = {
		Feature = "Faceted ice knuckles on slim silver-cuffed gloves",
		Shell = "Combat", Knuckles = "Crystal", Back = "None", Cuff = "Bracer",
		Extras = { "Seams" }, Scale = 1.08,
		Colors = colors(rgb(182, 214, 238), rgb(172, 226, 255), rgb(202, 206, 216), rgb(232, 244, 255)),
		Mats = mats(M.Leather, M.Ice, M.Metal),
	},
	Frostbite_3 = {
		Feature = "Heavy slate gloves with frozen ridges",
		Shell = "Heavy", Knuckles = "Ridge", Back = "Layered", Cuff = "Strap",
		Extras = {}, Scale = 1.1,
		Colors = colors(rgb(92, 102, 118), rgb(212, 232, 246), rgb(62, 68, 80), rgb(182, 222, 246)),
		Mats = mats(M.Slate, M.Glacier, M.Metal),
	},
	Frostbite_4 = {
		Feature = "Crystal plates grown into a navy gauntlet",
		Shell = "Gauntlet", Knuckles = "Crystal", Back = "Crystal", Cuff = "Rings",
		Extras = { "Shards" }, Effect = "Glow", Scale = 1.1,
		Colors = colors(rgb(40, 60, 104), rgb(152, 222, 255), rgb(202, 208, 222), rgb(232, 248, 255), rgb(152, 232, 255)),
		Mats = mats(M.SmoothPlastic, M.Glass, M.Metal),
	},
	Frostbite_5 = {
		Feature = "Dark steel with pale engraved ice panels",
		Shell = "Gauntlet", Knuckles = "Plates", Back = "Panel", Cuff = "Bracer", Emblem = "Snowflake",
		Extras = { "Inlay" }, Scale = 1.12,
		Colors = colors(rgb(42, 50, 64), rgb(192, 226, 246), rgb(152, 162, 178), rgb(132, 202, 242)),
		Mats = mats(M.Metal, M.Ice, M.Metal),
	},
	Frostbite_6 = {
		Feature = "Aerodynamic silver strikers with icy channels",
		Shell = "Combat", Knuckles = "Blades", Back = "Ribs", Cuff = "Flared",
		Extras = { "Fins", "Channels" }, Effect = "Frost", Scale = 1.12,
		Colors = colors(rgb(200, 206, 216), rgb(150, 160, 178), rgb(92, 102, 122), rgb(182, 226, 255), rgb(122, 212, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Frostbite_7 = {
		Feature = "Spiked polar war gauntlets",
		Shell = "Gauntlet", Knuckles = "Spikes", Back = "Layered", Cuff = "Crown", Emblem = "Crest",
		Extras = {}, Scale = 1.14,
		Colors = colors(rgb(132, 142, 158), rgb(222, 236, 250), rgb(62, 72, 92), rgb(102, 182, 242)),
		Mats = mats(M.Metal, M.Glacier, M.Metal),
	},
	Frostbite_8 = {
		Feature = "Colossal gloves under sculpted ice guards",
		Shell = "Heavy", Knuckles = "Segmented", Back = "Layered", Cuff = "Bracer",
		Extras = { "Shards" }, Effect = "Frost", Scale = 1.18,
		Colors = colors(rgb(92, 112, 142), rgb(162, 202, 236), rgb(62, 72, 92), rgb(212, 236, 255), rgb(152, 222, 255)),
		Mats = mats(M.Slate, M.Ice, M.Metal),
	},
	Frostbite_9 = {
		Feature = "Royal silver scales set with cyan crystal",
		Shell = "Gauntlet", Knuckles = "Crystal", Back = "Scales", Cuff = "Crown", Emblem = "Diamond",
		Extras = { "Inlay" }, Effect = "Glow", Scale = 1.16,
		Colors = colors(rgb(212, 216, 226), rgb(92, 222, 255), rgb(242, 246, 255), rgb(92, 222, 255), rgb(92, 222, 255)),
		Mats = mats(M.Metal, M.Glass, M.Foil),
	},
	Frostbite_10 = {
		Feature = "White-and-navy claws with luminous ice crystals",
		Shell = "Claw", Knuckles = "Crystal", Back = "Crystal", Cuff = "Crown", Emblem = "Snowflake",
		Extras = { "Fins", "Shards" }, Effect = "Frost", Scale = 1.2,
		Colors = colors(rgb(244, 248, 255), rgb(122, 214, 255), rgb(22, 30, 72), rgb(132, 222, 255), rgb(122, 222, 255)),
		Mats = mats(M.SmoothPlastic, M.Glass, M.SmoothPlastic),
	},

	-- Inferno Kingdom: dark forged metal, volcanic stone, copper, ember red, molten orange.
	Inferno_1 = {
		Feature = "Blackened gloves with ember-red stitching",
		Shell = "Boxing", Knuckles = "Padded", Back = "None", Cuff = "Wrap",
		Extras = { "Stitching" }, Scale = 1.08,
		Colors = colors(rgb(40, 34, 32), rgb(72, 58, 52), rgb(52, 40, 36), rgb(204, 52, 32)),
		Mats = mats(M.Leather, M.Leather, M.Leather),
	},
	Inferno_2 = {
		Feature = "Rough volcanic stone set into dark leather",
		Shell = "Boxing", Knuckles = "Rocks", Back = "Panel", Cuff = "Strap",
		Extras = { "Seams" }, Scale = 1.1,
		Colors = colors(rgb(60, 56, 54), rgb(82, 76, 74), rgb(112, 102, 96), rgb(160, 72, 52)),
		Mats = mats(M.Leather, M.Basalt, M.Metal),
	},
	Inferno_3 = {
		Feature = "Segmented steel knuckles over molten channels",
		Shell = "Gauntlet", Knuckles = "Segmented", Back = "None", Cuff = "Bracer",
		Extras = { "Channels" }, Effect = "Glow", Scale = 1.1,
		Colors = colors(rgb(46, 40, 40), rgb(72, 62, 60), rgb(96, 84, 80), rgb(255, 132, 52), rgb(255, 122, 32)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Inferno_4 = {
		Feature = "Forged steel plates fixed with copper rivets",
		Shell = "Gauntlet", Knuckles = "Plates", Back = "Layered", Cuff = "Flared",
		Extras = { "Rivets" }, Effect = "Glow", Scale = 1.12,
		Colors = colors(rgb(96, 98, 104), rgb(70, 72, 78), rgb(192, 112, 62), rgb(210, 132, 72), rgb(255, 92, 42)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Inferno_5 = {
		Feature = "Sharp red-and-black striker armor",
		Shell = "Combat", Knuckles = "Spikes", Back = "Ribs", Cuff = "Flared", Emblem = "Crest", EmblemOn = "Cuff",
		Extras = { "Fins" }, Scale = 1.14,
		Colors = colors(rgb(168, 30, 30), rgb(26, 22, 22), rgb(58, 22, 22), rgb(255, 62, 42)),
		Mats = mats(M.Leather, M.Metal, M.Metal),
	},
	Inferno_6 = {
		Feature = "Thick volcanic plates split by lava seams",
		Shell = "Heavy", Knuckles = "Rocks", Back = "Layered", Cuff = "Bracer",
		Extras = { "Channels" }, Effect = "Embers", Scale = 1.16,
		Colors = colors(rgb(42, 34, 32), rgb(64, 48, 44), rgb(92, 72, 62), rgb(255, 142, 52), rgb(255, 132, 42)),
		Mats = mats(M.Leather, M.CrackedLava, M.Metal),
	},
	Inferno_7 = {
		Feature = "Horned obsidian claws with blood-red scales",
		Shell = "Claw", Knuckles = "Horns", Back = "Scales", Cuff = "Crown", Emblem = "Diamond",
		Extras = { "Inlay" }, Effect = "Glow", Scale = 1.16,
		Colors = colors(rgb(24, 20, 26), rgb(140, 22, 32), rgb(122, 102, 92), rgb(222, 42, 42), rgb(222, 42, 42)),
		Mats = mats(M.Glass, M.SmoothPlastic, M.Metal),
	},
	Inferno_8 = {
		Feature = "Cracked scale armor glowing from within",
		Shell = "Heavy", Knuckles = "Guard", Back = "Scales", Cuff = "Bracer",
		Extras = { "Channels" }, Effect = "Embers", Scale = 1.18,
		Colors = colors(rgb(36, 32, 32), rgb(60, 42, 38), rgb(92, 62, 42), rgb(255, 112, 32), rgb(255, 102, 32)),
		Mats = mats(M.Leather, M.Basalt, M.Metal),
	},
	Inferno_9 = {
		Feature = "Black-metal gauntlets bearing a fiery crest",
		Shell = "Gauntlet", Knuckles = "Spikes", Back = "Ribs", Cuff = "Crown", Emblem = "Crest",
		Extras = { "Fins", "Channels" }, Effect = "Embers", Scale = 1.2,
		Colors = colors(rgb(30, 28, 32), rgb(58, 54, 58), rgb(202, 122, 52), rgb(255, 152, 62), rgb(255, 122, 42)),
		Mats = mats(M.Metal, M.DiamondPlate, M.Metal),
	},
	Inferno_10 = {
		Feature = "Obsidian claws forged with molten-gold sunburst",
		Shell = "Claw", Knuckles = "Blades", Back = "Sun", Cuff = "Crown", Emblem = "Orb",
		Extras = { "Inlay", "Fins" }, Effect = "Embers", Scale = 1.22,
		Colors = colors(rgb(26, 22, 26), rgb(46, 38, 40), rgb(255, 190, 62), rgb(255, 142, 42), rgb(255, 142, 42)),
		Mats = mats(M.Glass, M.Metal, M.Foil),
	},

	-- Cosmic Frontier: titanium, obsidian, violet and cyan inlays; geometric cosmic motifs.
	Cosmic_1 = {
		Feature = "Clean dark gloves with a silver star",
		Shell = "Boxing", Knuckles = "Padded", Back = "Panel", Cuff = "Strap", Emblem = "Star",
		Extras = { "Stitching" }, Scale = 1.12,
		Colors = colors(rgb(30, 32, 46), rgb(52, 56, 76), rgb(202, 206, 222), rgb(222, 226, 255)),
		Mats = mats(M.Leather, M.Leather, M.Metal),
	},
	Cosmic_2 = {
		Feature = "Violet combat gloves with nebula-pink inlays",
		Shell = "Combat", Knuckles = "Plates", Back = "Layered", Cuff = "Bracer",
		Extras = { "Inlay" }, Scale = 1.12,
		Colors = colors(rgb(98, 54, 172), rgb(64, 38, 120), rgb(82, 222, 255), rgb(255, 142, 232)),
		Mats = mats(M.SmoothPlastic, M.SmoothPlastic, M.Metal),
	},
	Cosmic_3 = {
		Feature = "Titanium knuckles banded like an orbit",
		Shell = "Gauntlet", Knuckles = "Segmented", Back = "Panel", Cuff = "Rings", Emblem = "Ring",
		Extras = { "Channels" }, Scale = 1.14,
		Colors = colors(rgb(172, 176, 192), rgb(92, 96, 116), rgb(62, 66, 82), rgb(122, 202, 255), rgb(122, 202, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Cosmic_4 = {
		Feature = "Angular titanium with quantum energy lines",
		Shell = "Gauntlet", Knuckles = "Blades", Back = "Ribs", Cuff = "Flared",
		Extras = { "Channels" }, Effect = "Glow", Scale = 1.16,
		Colors = colors(rgb(182, 186, 202), rgb(42, 46, 62), rgb(222, 226, 236), rgb(62, 232, 255), rgb(62, 232, 255)),
		Mats = mats(M.Metal, M.Metal, M.Metal),
	},
	Cosmic_5 = {
		Feature = "Luminous white panels around a pulsar core",
		Shell = "Gauntlet", Knuckles = "Guard", Back = "Panel", Cuff = "Bracer", Emblem = "Orb",
		Extras = { "Inlay" }, Effect = "Glow", Scale = 1.18,
		Colors = colors(rgb(242, 242, 252), rgb(142, 82, 232), rgb(202, 206, 222), rgb(182, 132, 255), rgb(232, 202, 255)),
		Mats = mats(M.SmoothPlastic, M.SmoothPlastic, M.Metal),
	},
	Cosmic_6 = {
		Feature = "Obsidian crushers around a dark singularity",
		Shell = "Heavy", Knuckles = "Segmented", Back = "None", Cuff = "Crown", Emblem = "Ring",
		Extras = { "Channels" }, Effect = "Cosmic", Scale = 1.2,
		Colors = colors(rgb(16, 14, 22), rgb(42, 32, 62), rgb(92, 82, 112), rgb(172, 92, 255), rgb(172, 92, 255)),
		Mats = mats(M.Leather, M.SmoothPlastic, M.Metal),
	},
	Cosmic_7 = {
		Feature = "Silver strikers radiating a gold supernova",
		Shell = "Combat", Knuckles = "Spikes", Back = "Sun", Cuff = "Flared",
		Extras = {}, Effect = "Glow", Scale = 1.2,
		Colors = colors(rgb(212, 216, 226), rgb(150, 156, 170), rgb(240, 196, 82), rgb(255, 222, 152), rgb(255, 222, 152)),
		Mats = mats(M.Metal, M.Metal, M.Foil),
	},
	Cosmic_8 = {
		Feature = "Segmented celestial armor marked with a star",
		Shell = "Heavy", Knuckles = "Plates", Back = "Layered", Cuff = "Crown", Emblem = "Star",
		Extras = { "Inlay" }, Effect = "Cosmic", Scale = 1.22,
		Colors = colors(rgb(42, 46, 82), rgb(202, 206, 232), rgb(240, 200, 92), rgb(182, 202, 255), rgb(182, 202, 255)),
		Mats = mats(M.SmoothPlastic, M.Metal, M.Foil),
	},
	Cosmic_9 = {
		Feature = "Violet claws split by cyan dimensional shards",
		Shell = "Claw", Knuckles = "Crystal", Back = "Crystal", Cuff = "Rings", Emblem = "Diamond", EmblemOn = "Cuff",
		Extras = { "Shards", "Channels" }, Effect = "Cosmic", Scale = 1.22,
		Colors = colors(rgb(92, 46, 170), rgb(62, 222, 255), rgb(32, 32, 52), rgb(122, 242, 255), rgb(122, 242, 255)),
		Mats = mats(M.SmoothPlastic, M.Glass, M.Metal),
	},
	Cosmic_10 = {
		Feature = "The ultimate black-titanium claws, wrapped in cosmic light",
		Shell = "Claw", Knuckles = "Blades", Back = "Layered", Cuff = "Crown", Emblem = "Orb",
		Extras = { "Fins", "Channels", "Swirl" }, Effect = "Cosmic", Scale = 1.26,
		Colors = colors(rgb(18, 18, 26), rgb(182, 186, 202), rgb(152, 82, 255), rgb(82, 232, 255), rgb(82, 232, 255)),
		Mats = mats(M.Metal, M.Metal, M.SmoothPlastic),
	},
}

return GloveDesigns
