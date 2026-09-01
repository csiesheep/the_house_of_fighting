--!strict
-- Shared tuning for the stage. Read by the server (which builds it)
-- and the client (which draws the HUD).
--
-- This is a placeholder arena so the project has something playable
-- while the actual game design is decided. Every value here is meant
-- to be replaced, not built on.

local StageConfig = {}

StageConfig.Arena = {
	Radius     = 46,                    -- studs from centre to edge
	TileSize   = 8,
	TileHeight = 1,
	Origin     = Vector3.new(0, 24, 0),

	-- 0 gives a ring-out arena: step off the edge and you fall.
	-- Raise it to enclose the space and turn it into a room.
	WallHeight = 0,

	SpawnCount  = 8,
	SpawnRadius = 32,
}

StageConfig.Respawn = {
	FallGrace = 30,    -- studs below the floor before you are pulled back
	CheckRate = 0.3,   -- seconds between checks
}

StageConfig.Palette = {
	TileA  = Color3.fromRGB(48, 44, 58),
	TileB  = Color3.fromRGB(38, 35, 47),
	Edge   = Color3.fromRGB(214, 84, 74),
	Spawn  = Color3.fromRGB(90, 210, 255),
}

return StageConfig
