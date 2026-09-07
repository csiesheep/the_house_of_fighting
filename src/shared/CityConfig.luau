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

-- S skyscraper  T tower  A apartments  H houses  P park  C car park
-- M market  . empty
--
-- Laid out like a real city rather than a skyline: two skyscrapers at
-- the centre, offices around them, then apartments, then houses on
-- the outside. Height falls off as you walk away from the middle,
-- which is what makes somewhere feel like it has a downtown.
CityConfig.Layout = {
	"H H A P H",
	"H A T T A",
	"A T M S T",
	"H A T S A",
	"H C A P C",
}

-- Every block is a pavement ring around whatever stands on it: kerb
-- at the road edge, walkable sidewalk, then the building's own pad.
CityConfig.Sidewalk = {
	Width      = 8,     -- of the walkable ring
	KerbWidth  = 2,
	KerbRise   = 0.9,   -- above the road surface
	WalkRise   = 0.6,
	PadRise    = 0.75,  -- the inner pad the building sits on

	Kerb     = Color3.fromRGB(206, 204, 198),
	Walk     = Color3.fromRGB(180, 178, 172),
	WalkAlt  = Color3.fromRGB(170, 168, 162),
	Pad      = Color3.fromRGB(158, 156, 150),
	Grass    = Color3.fromRGB(112, 156, 92),
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
--
--  brickScale multiplies the brick, so a skyscraper is built
--  from panels rather than bricks. At the normal size a 100
--  stud tower is about a thousand parts on its own; at scale 2
--  it is a quarter of that and looks the part besides.
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

-- Mid-rise residential: the bulk of the map. Balconies are what stop
-- these reading as short offices.
CityConfig.ApartmentStyles = {
	{
		name = "Brick Apartments",
		widthBricks = 7, depthBricks = 5, courses = 9,
		windows = "grid", roof = "parapet", balconies = true,
		wall = Color3.fromRGB(164, 106, 84),
		accent = Color3.fromRGB(214, 206, 192),
	},
	{
		name = "Modern Flats",
		widthBricks = 6, depthBricks = 6, courses = 11,
		windows = "bands", bandEvery = 2, roof = "parapet", balconies = true,
		wall = Color3.fromRGB(206, 202, 194),
		accent = Color3.fromRGB(124, 140, 156),
	},
	{
		name = "Walk-Up",
		widthBricks = 5, depthBricks = 5, courses = 6,
		windows = "grid", roof = "parapet", balconies = true,
		wall = Color3.fromRGB(188, 168, 132),
		accent = Color3.fromRGB(120, 92, 70),
	},
	{
		name = "Corner Block",
		widthBricks = 8, depthBricks = 4, courses = 8,
		windows = "columns", roof = "parapet", balconies = true,
		wall = Color3.fromRGB(146, 152, 148),
		accent = Color3.fromRGB(196, 118, 74),
	},
}

CityConfig.Balcony = {
	Depth = 2.4,
	Rail = 1.4,
	Colour = Color3.fromRGB(196, 192, 186),
}

-- The tall ones. Same builder, coarser panels.
CityConfig.SkyscraperStyles = {
	{
		name = "Glass Skyscraper",
		widthBricks = 6, depthBricks = 6, courses = 20, brickScale = 2,
		windows = "bands", bandEvery = 2, roof = "antenna",
		wall = Color3.fromRGB(74, 96, 118),
		accent = Color3.fromRGB(128, 158, 184),
	},
	{
		name = "Steel Spire",
		widthBricks = 5, depthBricks = 5, courses = 24, brickScale = 2,
		windows = "columns", roof = "stepped",
		wall = Color3.fromRGB(108, 112, 124),
		accent = Color3.fromRGB(186, 192, 202),
	},
	{
		name = "Corporate Slab",
		widthBricks = 6, depthBricks = 5, courses = 18, brickScale = 2,
		windows = "grid", roof = "parapet",
		wall = Color3.fromRGB(160, 152, 140),
		accent = Color3.fromRGB(96, 92, 88),
	},
}

-- ===========================================================
--  Street furniture
-- ===========================================================

CityConfig.Street = {
	LampsPerBlock    = 2,
	TreesPerBlock    = 3,     -- planted along the sidewalk itself
	PlantersPerBlock = 2,
	BenchesPerBlock  = 1,
	BinsPerBlock     = 1,
	Inset            = 4,     -- from the block edge onto the pavement
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

-- The smaller ones lining the pavements. A park tree on a sidewalk
-- would put its canopy over two lanes of traffic.
CityConfig.StreetTree = {
	TrunkHeight = 11,
	TrunkWidth = 1.6,
	CanopyLayers = 2,
	CanopySpread = 8,
	Health = 3,
	Reward = 8,
	BedSize = 4.5,
	Bed = Color3.fromRGB(74, 56, 42),
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

-- Cars driving the road grid. Anchored and moved by the server rather
-- than simulated: two dozen physics vehicles would spend more compute
-- than the whole rest of the map and drive worse for it.
CityConfig.Traffic = {
	PerLane   = 1,
	LaneOffset = 6,     -- from the centre line of the road
	Speed     = 26,     -- studs per second
	SpeedJitter = 6,
	Damage    = 22,     -- to anyone it runs into
	HitCooldown = 1.5,

	StopTime     = 1,   -- seconds waited at each crossing
	-- Far enough back that the car's nose stops short of the stripes.
	-- A 14 stud car centred here has its front at 13, and the crossing
	-- ends at 12.
	StopApproach = 20,
}

-- Zebra crossings on every approach to every junction. The stripes run
-- with the traffic and spread across the road, which is the way round
-- that reads as a crossing from a car and from the pavement both.
CityConfig.Crosswalk = {
	Stripes     = 3,
	StripeWidth = 3.4,
	BandDepth   = 6,
	Colour      = Color3.fromRGB(236, 234, 226),
	Rise        = 0.02,   -- barely above the tarmac, to avoid z-fighting
	Approach    = 9,      -- centre of the band, back from the junction
}

CityConfig.Rules = {
	RebuildDelay   = 10,    -- seconds after the city is flattened
	SwitchCooldown = 300,   -- five minutes before the rebuild button appears
	CollapseBonus  = 150,   -- coins for bringing a tower down
}

return CityConfig
