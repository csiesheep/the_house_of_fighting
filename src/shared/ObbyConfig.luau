--!strict
-- ===========================================================
--  ObbyConfig
--
--  Five graded courses on platforms reaching out beyond the
--  boundary wall, one per gate.
--
--  A course is a string of segments, not a row of gaps. Each
--  tier draws from a different pool of obstacle types, so
--  difficulty is variety as much as distance: Beginner is
--  jumps and planks, Impossible is lava, spinners, vanishing
--  platforms and wall climbs.
--
--  Every jump these produce still respects the character's
--  real jump budget. Obstacles change what is between the
--  platforms, never how far apart they can be.
-- ===========================================================

local ObbyConfig = {}

ObbyConfig.Course = {
	Origin = Vector3.new(0, 24, 0),   -- arena floor height

	BridgeFrom  = 132,   -- inner end of the walkway, on the arena floor
	StartRadius = 178,   -- where the first platform sits
	BridgeWidth = 12,

	LateralSwing  = 7,   -- how far the path weaves side to side
	ClaimCooldown = 120, -- seconds before the same tier pays you again
}

-- Shared shapes. Anything that would change a jump distance is
-- derived from the tier instead, so tuning a tier cannot be undone
-- by an obstacle.
ObbyConfig.Obstacles = {
	Beam = {
		Width = 2.4,          -- narrow enough to fall off, wide enough to walk
		LengthFactor = 3.2,   -- multiples of the tier spacing
	},
	Lava = {
		Drop = 5,             -- how far below the platforms the pool sits
		Overhang = 4,         -- how far past the gap it spreads
		Colour = Color3.fromRGB(255, 92, 40),
	},
	Mover = {
		Travel = 20,          -- studs from end to end
		Period = 3.4,         -- seconds for a full there-and-back
		Responsiveness = 45,
	},
	Spinner = {
		Length = 24,
		Thickness = 1.6,
		Speed = 2.0,          -- radians per second
		Height = 3.2,         -- above the platform surface
		Colour = Color3.fromRGB(226, 88, 96),
	},
	Fader = {
		Count = 3,            -- platforms in the sequence
		OnTime = 2.0,
		OffTime = 1.3,
		Stagger = 0.9,        -- offset between neighbours, so they alternate
	},
	WallJump = {
		Separation = 6,       -- between the two walls
		RungRise = 3.5,       -- climb per hop; jump height allows about 6.3
		Rungs = 4,
		LedgeSize = Vector3.new(4, 0.8, 3),
		WallHeight = 22,
		WallThickness = 1.5,
	},
}

-- `types` is a weighted bag: repeat an entry to make it likelier.
ObbyConfig.Tiers = {
	{
		key = "Beginner", name = "BEGINNER", gate = 1, reward = 5, seed = 1001,
		segments = 8, platform = 10.0, rise = 2.0, gap = 1.0,
		checkpointEvery = 4,
		types = { "jump", "jump", "jump", "beam" },
		colour = Color3.fromRGB(126, 220, 150),
	},
	{
		key = "Noob", name = "NOOB", gate = 2, reward = 10, seed = 2002,
		segments = 10, platform = 8.0, rise = 2.6, gap = 2.2,
		checkpointEvery = 4,
		types = { "jump", "jump", "beam", "mover" },
		colour = Color3.fromRGB(120, 200, 255),
	},
	{
		key = "Medium", name = "MEDIUM", gate = 3, reward = 15, seed = 3003,
		segments = 12, platform = 6.0, rise = 3.2, gap = 3.2,
		checkpointEvery = 4,
		types = { "jump", "jump", "beam", "mover", "lava" },
		colour = Color3.fromRGB(255, 205, 70),
	},
	{
		key = "Pro", name = "PRO", gate = 4, reward = 20, seed = 4004,
		segments = 15, platform = 5.0, rise = 3.8, gap = 4.2,
		checkpointEvery = 5,
		types = { "jump", "beam", "mover", "lava", "lava", "fader", "spinner" },
		colour = Color3.fromRGB(255, 138, 62),
	},
	{
		key = "Impossible", name = "IMPOSSIBLE", gate = 5, reward = 50, seed = 5005,
		segments = 18, platform = 3.5, rise = 4.4, gap = 5.2,
		checkpointEvery = 6,
		types = { "jump", "lava", "lava", "mover", "spinner", "fader", "fader", "walljump" },
		colour = Color3.fromRGB(236, 78, 92),
	},
}

ObbyConfig.Palette = {
	Bridge     = Color3.fromRGB(206, 200, 190),
	Finish     = Color3.fromRGB(255, 205, 70),
	Checkpoint = Color3.fromRGB(120, 240, 255),
}

-- Recovery for anyone who misses a jump out here. Triggered above the
-- arena's own fall check, so the courses catch their own fallers and
-- return them to their last checkpoint rather than the spawn ring.
ObbyConfig.Recovery = {
	BeyondRadius = 145,
	DropBelow    = 12,
	CheckRate    = 0.3,
}

return ObbyConfig
