--!strict
-- Tuning for the obby that spirals up the inside of the arena wall.

local ObbyConfig = {}

ObbyConfig.Course = {
	Origin = Vector3.new(0, 24, 0),    -- arena floor, same as StageConfig

	-- Sits between the houses and inside the boundary, so it needs no
	-- gap in the wall and never clips a roof.
	EntryAngleDeg = 55,
	EntryRadius   = 44,
	Radius        = 56,

	PlatformCount = 14,
	PlatformSize  = Vector3.new(6, 1, 6),
	Rise          = 3.4,     -- studs gained per platform

	-- Edge-to-edge gap to clear, interpolated across the course. The
	-- generator clamps every jump to this, so a random angle can never
	-- produce a platform you cannot reach.
	StartGap = 1.5,
	EndGap   = 4.5,

	AngleStepDeg   = 11,
	AngleJitterDeg = 5,

	Seed = nil,   -- set a number for the same course every refresh
}

ObbyConfig.Rules = {
	RefreshSeconds = 600,   -- ten minutes, then a fresh layout
	Reward         = 10,    -- coins for reaching the top
}

ObbyConfig.Palette = {
	Entry  = Color3.fromRGB(120, 200, 255),
	Step   = Color3.fromRGB(238, 232, 220),
	StepAlt = Color3.fromRGB(214, 206, 192),
	Finish = Color3.fromRGB(255, 205, 70),
}

return ObbyConfig
