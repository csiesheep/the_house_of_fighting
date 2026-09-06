--!strict
-- ===========================================================
--  ObbyConfig
--
--  Five graded courses on platforms reaching out beyond the
--  boundary wall, one per gate. Harder tiers mean smaller
--  platforms, bigger gaps, a steeper climb and more of them.
--
--  Every gap here was checked against the character's real
--  jump budget. Impossible leaves about a stud of margin --
--  brutal, but clearable. Widen EndGap much further and it
--  stops being a difficulty and starts being a wall.
-- ===========================================================

local ObbyConfig = {}

ObbyConfig.Course = {
	Origin = Vector3.new(0, 24, 0),   -- arena floor height

	BridgeFrom  = 132,   -- inner end of the walkway, on the arena floor
	StartRadius = 178,   -- where the first platform sits
	BridgeWidth = 12,

	LateralSwing = 6,    -- how far the path weaves side to side
	ClaimCooldown = 120, -- seconds before the same tier pays you again
}

-- gate index refers to StageConfig.Gates.Angles
ObbyConfig.Tiers = {
	{
		key = "Beginner", name = "BEGINNER", gate = 1, reward = 5,
		steps = 8, platform = 10.0, rise = 2.0, gap = 1.0,
		colour = Color3.fromRGB(126, 220, 150),
	},
	{
		key = "Noob", name = "NOOB", gate = 2, reward = 10,
		steps = 10, platform = 8.0, rise = 2.6, gap = 2.2,
		colour = Color3.fromRGB(120, 200, 255),
	},
	{
		key = "Medium", name = "MEDIUM", gate = 3, reward = 15,
		steps = 12, platform = 6.0, rise = 3.2, gap = 3.2,
		colour = Color3.fromRGB(255, 205, 70),
	},
	{
		key = "Pro", name = "PRO", gate = 4, reward = 20,
		steps = 15, platform = 5.0, rise = 3.8, gap = 4.2,
		colour = Color3.fromRGB(255, 138, 62),
	},
	{
		key = "Impossible", name = "IMPOSSIBLE", gate = 5, reward = 50,
		steps = 18, platform = 3.5, rise = 4.4, gap = 5.2,
		colour = Color3.fromRGB(236, 78, 92),
	},
}

ObbyConfig.Palette = {
	Bridge = Color3.fromRGB(206, 200, 190),
	Finish = Color3.fromRGB(255, 205, 70),
}

-- Recovery for anyone who misses a jump out here. Triggered above the
-- arena's own fall check, so the courses catch their own fallers and
-- put them back at their entry rather than the spawn ring.
ObbyConfig.Recovery = {
	BeyondRadius = 145,
	DropBelow    = 12,
	CheckRate    = 0.3,
}

return ObbyConfig
