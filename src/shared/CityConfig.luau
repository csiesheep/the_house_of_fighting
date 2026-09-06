--!strict
-- ===========================================================
--  CityConfig
--
--  The grid, what stands on each block, and the street
--  furniture that makes it read as a city rather than a set of
--  boxes on tarmac.
--
--  Block layout is written out by hand rather than rolled, so
--  the market keeps the middle and the towers do not all end
--  up in one corner. "." is an empty lot.
-- ===========================================================

local CityConfig = {}

CityConfig.Grid = {
	Cols = 5,
	Rows = 5,
	BlockSize = 64,
	RoadWidth = 24,
	LaneMark = 1.6,   -- width of the painted centre line
}

-- T tower   H houses   P park (trees)   C car park   M market   . empty
CityConfig.Layout = {
	"T H T C T",
	"P T . T H",
	"T . M . T",
	"H T . T P",
	"T C T H T",
}

CityConfig.Brick = {
	Size = Vector3.new(4, 2, 2),
	Health = 2,
}

-- ===========================================================
--  Towers
--
--  Shells, not solid blocks: a filled tower would be twenty
--  times the parts for an interior nobody ever sees.
--
--  windows says which bricks are glass:
--    bands    every Nth course is a full ribbon
--    grid     alternating bricks on alternating courses
--    columns  vertical strips running the whole height
--    shop     one tall glazed floor at street level
-- ===========================================================

CityConfig.TowerRules = {
	BaseCourses = 2,          -- what counts as "the ground floor"
	CollapseFraction = 0.45,  -- how much of it has to go
	Glass = Color3.fromRGB(158, 196, 214),
	LitGlass = Color3.fromRGB(255, 232, 176),
	LitChance = 0.18,         -- windows that are lit rather than plain
}

CityConfig.TowerStyles = {
	{
		name = "Glass Tower",
		widthBricks = 5, depthBricks = 5, courses = 20,
		windows = "bands", bandEvery = 2, roof = "antenna",
		wall = Color3.fromRGB(96, 118, 138),
		accent = Color3.fromRGB(140, 168, 190),
	},
	{
		name = "Brick Office",
		widthBricks = 6, depthBricks = 5, courses = 12,
		windows = "grid", roof = "parapet",
		wall = Color3.fromRGB(150, 88, 70),
		accent = Color3.fromRGB(206, 198, 184),
	},
	{
		name = "Concrete Slab",
		widthBricks = 7, depthBricks = 4, courses = 16,
		windows = "columns", roof = "watertower",
		wall = Color3.fromRGB(146, 146, 142),
		accent = Color3.fromRGB(96, 98, 102),
	},
	{
		name = "Deco Spire",
		widthBricks = 5, depthBricks = 5, courses = 18,
		windows = "grid", roof = "stepped",
		wall = Color3.fromRGB(224, 210, 186),
		accent = Color3.fromRGB(168, 140, 96),
	},
	{
		name = "Corner Shop",
		widthBricks = 6, depthBricks = 5, courses = 5,
		windows = "shop", roof = "awning",
		wall = Color3.fromRGB(198, 168, 120),
		accent = Color3.fromRGB(180, 62, 58),
	},
	{
		name = "Tower Block",
		widthBricks = 4, depthBricks = 4, courses = 24,
		windows = "grid", roof = "parapet",
		wall = Color3.fromRGB(178, 172, 160),
		accent = Color3.fromRGB(120, 116, 110),
	},
}

-- ===========================================================
--  Street furniture
-- ===========================================================

CityConfig.Street = {
	LampsPerBlock    = 4,
	PlantersPerBlock = 3,
	BenchesPerBlock  = 2,
	BinsPerBlock     = 1,
	Inset            = 3,     -- from the block edge onto the pavement
	Health           = 1,     -- one hammer blow; they are dressing, not walls

	Lamp = {
		PostHeight = 14,
		ArmLength  = 4,
		Post   = Color3.fromRGB(58, 62, 68),
		Shade  = Color3.fromRGB(40, 42, 46),
		Bulb   = Color3.fromRGB(255, 238, 196),
		Range  = 26,
	},
	Planter = {
		Pot   = Color3.fromRGB(168, 118, 88),
		Soil  = Color3.fromRGB(78, 58, 44),
		Bush  = { Color3.fromRGB(96, 158, 82), Color3.fromRGB(214, 96, 118),
		          Color3.fromRGB(232, 186, 92) },
	},
	Bench = {
		Slats = Color3.fromRGB(146, 104, 62),
		Legs  = Color3.fromRGB(56, 58, 62),
	},
	Bin = {
		Body = Color3.fromRGB(64, 82, 70),
		Lid  = Color3.fromRGB(44, 56, 48),
	},
	TrafficLight = {
		Post = Color3.fromRGB(52, 54, 58),
		Height = 16,
		ArmLength = 9,
	},
}

CityConfig.Tree = {
	PerPark = 12,
	TrunkHeight = 14,
	TrunkWidth = 2.4,
	CanopyLayers = 3,
	Health = 4,            -- axe swings to fell it
	Reward = 12,           -- coins for felling one
	Trunk = Color3.fromRGB(94, 66, 46),
	Leaves = {
		Color3.fromRGB(86, 148, 74),
		Color3.fromRGB(104, 164, 84),
		Color3.fromRGB(72, 128, 66),
	},
}

CityConfig.Car = {
	PerLot = 8,
	BrickHealth = 2,
	Body = Vector3.new(7, 2.6, 14),
	Cabin = Vector3.new(6.2, 2.4, 7),
	Wheel = Vector3.new(1.6, 3.2, 3.2),
	Palette = {
		Color3.fromRGB(198, 66, 62),
		Color3.fromRGB(62, 104, 186),
		Color3.fromRGB(226, 196, 84),
		Color3.fromRGB(230, 230, 236),
		Color3.fromRGB(56, 62, 72),
		Color3.fromRGB(96, 168, 132),
	},
}

CityConfig.Rules = {
	RebuildDelay   = 10,    -- seconds after the city is flattened
	SwitchCooldown = 300,   -- five minutes before the rebuild button appears
	CollapseBonus  = 150,   -- coins for bringing a tower down
}

return CityConfig
