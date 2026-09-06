--!strict
-- ===========================================================
--  LeaderboardConfig
--
--  Three global boards standing at the edge of the map. Global
--  means OrderedDataStore, which like every other DataStore
--  needs the place published -- until then the boards say so
--  rather than standing there empty and looking broken.
-- ===========================================================

local LeaderboardConfig = {}

LeaderboardConfig.Placement = {
	Origin = Vector3.new(0, 24, 0),

	-- along the west edge road, inside the wall and off the block grid
	LineX   = -222,
	Spacing = 34,             -- studs between neighbouring boards

	BoardSize = Vector3.new(26, 18, 1.5),
	StandSize = Vector3.new(28, 3, 4),
	PromptDistance = 22,
}

LeaderboardConfig.Rules = {
	TopCount     = 100,   -- how many the full list holds
	FaceCount    = 10,    -- how many fit legibly on the board itself
	RefreshEvery = 60,    -- seconds between rebuilds
	PublishEvery = 60,    -- seconds between writing your own scores up
}

-- `stat` names a leaderstats IntValue; `attribute` names a player
-- attribute. Exactly one of the two per category.
LeaderboardConfig.Categories = {
	{
		key = "Bricks",
		title = "MOST BRICKS",
		stat = "Bricks",
		store = "Leaderboard_Bricks_v1",
		colour = Color3.fromRGB(236, 232, 226),
		suffix = "",
	},
	{
		key = "Coins",
		title = "MOST COINS",
		stat = "Coins",
		store = "Leaderboard_Coins_v1",
		colour = Color3.fromRGB(255, 205, 70),
		suffix = "",
	},
	{
		key = "Robux",
		title = "TOP SPENDERS",
		attribute = "RobuxSpent",
		store = "Leaderboard_Robux_v1",
		colour = Color3.fromRGB(120, 220, 150),
		suffix = " R$",
	},
}

return LeaderboardConfig
