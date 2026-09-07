--!strict
-- ===========================================================
--  StageConfig
--
--  The ground is a rectangle now, not a disc: a city block
--  grid needs straight edges and right angles.
--
--  Numbers here and in CityConfig have to agree. The map is
--  Cols * BlockSize + (Cols + 1) * RoadWidth on each axis, so
--  changing the grid means changing HalfX and HalfZ to match.
-- ===========================================================

local StageConfig = {}

StageConfig.Bounds = {
	HalfX = 248,     -- 7 blocks of 48 plus 8 roads of 20
	HalfZ = 248,
	Origin = Vector3.new(0, 24, 0),
}

StageConfig.Base = {
	Overhang = 18,   -- how far the slab runs past the wall
	Depth = 8,
	Inset = 0.1,     -- below the road surface, so nothing z-fights
}

StageConfig.Boundary = {
	Height = 90,     -- tall enough that a Gravity Coil will not clear it
	Thickness = 3,
	SegmentLength = 32,
	Transparency = 0.75,
	GateHalfWidth = 16,
}

-- Where the obby walkways leave the map. Each is a point on the wall
-- plus the direction the course runs. ObbyConfig tiers index into this.
-- Each sits on a road line, so a walkway out is the street continuing
-- rather than a bridge off the back of a block.
StageConfig.Gates = {
	{ key = "North West", position = Vector3.new(-102, 0, -248), out = Vector3.new(0, 0, -1) },
	{ key = "North East", position = Vector3.new(102, 0, -248),  out = Vector3.new(0, 0, -1) },
	{ key = "East",       position = Vector3.new(248, 0, 34),    out = Vector3.new(1, 0, 0) },
	{ key = "South",      position = Vector3.new(-34, 0, 248),   out = Vector3.new(0, 0, 1) },
	{ key = "West",       position = Vector3.new(-248, 0, -34),  out = Vector3.new(-1, 0, 0) },
}

-- On the market block's own pavement. Any further out and you would
-- spawn in the road, which now has traffic on it.
StageConfig.Spawns = {
	Count = 8,
	Radius = 20,
}

StageConfig.Respawn = {
	FallGrace = 40,
	CheckRate = 0.3,
}

StageConfig.Palette = {
	Road      = Color3.fromRGB(72, 72, 78),
	RoadLine  = Color3.fromRGB(226, 214, 138),
	Pavement  = Color3.fromRGB(178, 176, 170),
	Base      = Color3.fromRGB(52, 54, 58),
	Spawn     = Color3.fromRGB(96, 198, 255),
	Boundary  = Color3.fromRGB(198, 220, 240),
}

return StageConfig
