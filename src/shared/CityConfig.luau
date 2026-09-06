--!strict
-- ===========================================================
--  CityConfig
--
--  The grid, and what stands on each block.
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
	"T H P C T",
	"H . T . H",
	"P T M T P",
	"H . T . H",
	"T C P H T",
}

CityConfig.Tower = {
	-- footprint in bricks; walls only, so a tower is a shell
	WidthBricks = 5,
	DepthBricks = 5,
	Courses = 15,
	BrickSize = Vector3.new(4, 2, 2),
	BrickHealth = 2,

	-- how much of the ground floor has to go before it comes down
	BaseCourses = 2,
	CollapseFraction = 0.45,

	Palette = {
		Color3.fromRGB(150, 156, 168),
		Color3.fromRGB(122, 132, 150),
		Color3.fromRGB(176, 168, 156),
		Color3.fromRGB(96, 108, 124),
	},
	Glass = Color3.fromRGB(158, 196, 214),
	GlassEvery = 3,        -- every third course is windows
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
