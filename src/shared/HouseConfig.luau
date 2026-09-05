--!strict
-- Global house settings. The individual house designs live in
-- src/server/HouseStyles.luau -- add a table there to put a new
-- one into the rotation.

local HouseConfig = {}

HouseConfig.House = {
	BrickSize   = Vector3.new(4, 2, 2),   -- long, tall, thick
	BrickHealth = 2,                      -- hammer blows to destroy one brick

	HouseCount = 10,     -- houses standing at once; one of each style
	PlotRadius = 96,     -- ring radius. At 10 houses this gives 59 studs
	                     -- between neighbours, against 56 needed for the
	                     -- widest style, so nothing clips.

	-- When a brick breaks, unanchor whatever was resting on it so the
	-- wall sags instead of leaving bricks floating in mid air.
	CollapseAbove = true,

	RebuildDelay   = 8,    -- seconds after the last brick falls
	SwitchCooldown = 300,  -- 5 minutes before the switch button appears
}

HouseConfig.Hammer = {
	-- Reach, damage, cooldown, knockback and head size are per tier and
	-- live in ShopConfig.HammerTiers -- edit them there, not here.
	DebrisLife = 6,     -- seconds before broken bricks are cleaned up
	HandleSize = Vector3.new(0.5, 4, 0.5),
}

HouseConfig.Palette = {
	Handle = Color3.fromRGB(120, 84, 52),
	Head   = Color3.fromRGB(96, 100, 110),
}

HouseConfig.BreakableTag = "Breakable"

return HouseConfig
