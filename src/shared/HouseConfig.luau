--!strict
-- Tuning for the breakable house and the hammer that ruins it.

local HouseConfig = {}

HouseConfig.House = {
	-- sits on the arena floor; keep in step with StageConfig.Arena.Origin
	Origin = Vector3.new(0, 24, 0),

	BrickSize    = Vector3.new(4, 2, 2),   -- long, tall, thick
	WidthBricks  = 8,   -- front/back walls, in bricks
	DepthBricks  = 6,   -- side walls, in bricks
	HeightBricks = 6,   -- rows of bricks

	BrickHealth = 3,    -- hammer blows to destroy one brick

	DoorWidth  = 2,     -- bricks wide, centred on the front wall
	DoorHeight = 3,     -- bricks tall
	WindowRows = { 4, 5 },   -- rows punched out of the side walls

	Roof = true,

	-- When a brick breaks, unanchor whatever was resting on it so the
	-- wall sags instead of leaving bricks floating in mid air.
	CollapseAbove = true,

	RebuildDelay = 8,   -- seconds after the last brick falls
}

HouseConfig.Hammer = {
	Reach      = 12,    -- studs
	Damage     = 1,
	Cooldown   = 0.45,  -- seconds between swings
	Knockback  = 34,    -- how hard shattered bricks fly
	DebrisLife = 6,     -- seconds before broken bricks are cleaned up

	HandleSize = Vector3.new(0.5, 4, 0.5),
	HeadSize   = Vector3.new(1.5, 1.5, 2.8),
}

HouseConfig.Palette = {
	Brick     = Color3.fromRGB(150, 92, 74),
	BrickAlt  = Color3.fromRGB(132, 80, 64),
	Roof      = Color3.fromRGB(74, 64, 82),
	Frame     = Color3.fromRGB(206, 196, 178),
	Handle    = Color3.fromRGB(120, 84, 52),
	Head      = Color3.fromRGB(96, 100, 110),
}

HouseConfig.BreakableTag = "Breakable"

return HouseConfig
