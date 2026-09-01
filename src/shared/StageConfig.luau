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
	Transparency = 0.75,   -- barely there, so the wall does not shade the arena
}

StageConfig.Respawn = {
	FallGrace = 40,    -- studs below the floor before you are pulled back
	CheckRate = 0.3,
}

StageConfig.Palette = {
	TileA    = Color3.fromRGB(226, 222, 213),
	TileB    = Color3.fromRGB(210, 206, 196),
	Base     = Color3.fromRGB(188, 185, 176),
	Edge     = Color3.fromRGB(226, 128, 112),
	Spawn    = Color3.fromRGB(96, 198, 255),
	Boundary = Color3.fromRGB(198, 220, 240),
}

return StageConfig
