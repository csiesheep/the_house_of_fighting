--!strict
-- The ground you fight on and the wall that keeps you here.

local StageConfig = {}

StageConfig.Arena = {
	Radius     = 56,                    -- decorative tiling reaches this far
	TileSize   = 8,
	TileHeight = 1,
	Origin     = Vector3.new(0, 24, 0),

	SpawnCount  = 8,
	SpawnRadius = 50,                   -- outside the houses, inside the wall
}

-- A solid slab under the tiles. The tiles are a jagged circle, so without
-- this there are gaps near the diagonals you could drop through.
StageConfig.Base = {
	Radius = 68,
	Depth  = 8,
	Inset  = 0.1,     -- sits this far below the tile tops, to avoid z-fighting
}

StageConfig.Boundary = {
	Radius    = 66,
	Height    = 90,   -- tall enough that a Gravity Coil will not clear it
	Thickness = 3,
	Segments  = 64,
	Transparency = 0.55,
}

StageConfig.Respawn = {
	FallGrace = 40,    -- studs below the floor before you are pulled back
	CheckRate = 0.3,
}

StageConfig.Palette = {
	TileA    = Color3.fromRGB(48, 44, 58),
	TileB    = Color3.fromRGB(38, 35, 47),
	Base     = Color3.fromRGB(28, 26, 34),
	Edge     = Color3.fromRGB(214, 84, 74),
	Spawn    = Color3.fromRGB(90, 210, 255),
	Boundary = Color3.fromRGB(72, 78, 104),
}

return StageConfig
