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
	HalfX = 232,     -- 5 blocks of 64 plus 6 roads of 24
	HalfZ = 232,
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
StageConfig.Gates = {
	{ key = "North West", position = Vector3.new(-88, 0, -232), out = Vector3.new(0, 0, -1) },
	{ key = "North East", position = Vector3.new(88, 0, -232),  out = Vector3.new(0, 0, -1) },
	{ key = "East",       position = Vector3.new(232, 0, 0),    out = Vector3.new(1, 0, 0) },
	{ key = "South",      position = Vector3.new(0, 0, 232),    out = Vector3.new(0, 0, 1) },
	{ key = "West",       position = Vector3.new(-232, 0, 0),   out = Vector3.new(-1, 0, 0) },
}

-- Spawns sit on the ring road just outside the market block, so you
-- always start on tarmac with the market in sight.
StageConfig.Spawns = {
	Count = 8,
	Radius = 62,
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
