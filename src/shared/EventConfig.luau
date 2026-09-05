--!strict
-- ===========================================================
--  EventConfig
--
--  The hourly spin. One effect is drawn at random and runs for
--  five minutes, then everything goes back to normal.
--
--  Effects are data here; Events.server.luau holds what each
--  one actually does.
-- ===========================================================

local EventConfig = {}

EventConfig.Timing = {
	IntervalSeconds = 3600,   -- an hour between spins
	DurationSeconds = 300,    -- five minutes of the effect
	FirstSpinDelay  = 120,    -- grace period after the server starts
}

-- Order matters: the spin wheel shows them in this order, and the
-- server sends an index rather than a name.
EventConfig.Effects = {
	{
		key = "Sprinters",
		name = "SPRINTERS",
		blurb = "Everyone moves at more than double speed",
		colour = Color3.fromRGB(96, 200, 255),
		speedMultiplier = 2.2,
	},
	{
		key = "MoonGravity",
		name = "MOON GRAVITY",
		blurb = "Half gravity. Roofs are suddenly reachable",
		colour = Color3.fromRGB(178, 156, 255),
		gravityMultiplier = 0.5,
	},
	{
		key = "TinyTitans",
		name = "TINY TITANS",
		blurb = "Everyone shrinks. Same hammer, smaller arms",
		colour = Color3.fromRGB(126, 220, 150),
		bodyScale = 0.55,
	},
	{
		key = "Giants",
		name = "GIANTS",
		blurb = "Everyone grows. Doorways become a problem",
		colour = Color3.fromRGB(255, 158, 86),
		bodyScale = 1.5,
	},
	{
		key = "DoubleCoins",
		name = "DOUBLE COINS",
		blurb = "Every brick and every obby run pays twice",
		colour = Color3.fromRGB(255, 205, 70),
		coinMultiplier = 2,
	},
	{
		key = "GlassHouses",
		name = "GLASS HOUSES",
		blurb = "Triple damage. The neighbourhood will not last",
		colour = Color3.fromRGB(255, 110, 96),
		damageMultiplier = 3,
	},
}

return EventConfig
