--!strict
-- ===========================================================
--  MarketConfig
--
--  The coin shop. Nothing here costs Robux -- coins come from
--  the obby and from smashing bricks. Robux items live in
--  ShopConfig and are a separate ladder entirely.
-- ===========================================================

local MarketConfig = {}

-- How demolition pays. Without this the only income is 10 coins per
-- obby run, which makes a 10,000 coin jetpack a thousand runs.
MarketConfig.Economy = {
	BricksPerCoin = 4,     -- smash four bricks, earn a coin
}

MarketConfig.Stall = {
	Position = Vector3.new(0, 24, 0),   -- middle of the plaza
	PromptDistance = 16,
}

-- Order here is the order shown in the shop.
MarketConfig.Items = {
	{
		key = "Knife", price = 100, kind = "tool",
		name = "Knife",
		desc = "Close range, fast, and it hurts people rather than walls.",
	},
	{
		key = "Dynamite", price = 400, kind = "tool",
		name = "Dynamite",
		desc = "Throw it, count to three, lose a wall and anyone near it.",
	},
	{
		key = "SpeedBoots", price = 600, kind = "tool",
		name = "Speed Boots",
		desc = "Hold them and you cross the plaza in half the time.",
	},
	{
		key = "GrappleHook", price = 1500, kind = "tool",
		name = "Grapple Hook",
		desc = "Fire at anything in sight and get yanked to it.",
	},
	{
		key = "BodyArmour", price = 2500, kind = "passive",
		name = "Body Armour",
		desc = "Two and a half times the health, permanently. No slot needed.",
	},
	{
		key = "Jetpack", price = 10000, kind = "tool",
		name = "Jetpack",
		desc = "Hold to climb. Roofs stop being somewhere you have to reach.",
	},
}

MarketConfig.Specs = {
	Knife = {
		toolName = "Knife",
		damage = 28,
		range = 11,
		cooldown = 0.45,
		colour = Color3.fromRGB(206, 212, 222),
	},
	Dynamite = {
		toolName = "Dynamite",
		fuse = 3,
		radius = 20,
		knockback = 95,
		damage = 65,       -- to players caught in it
		cooldown = 7,
		colour = Color3.fromRGB(196, 62, 48),
	},
	SpeedBoots = {
		toolName = "Speed Boots",
		walkSpeed = 36,
		colour = Color3.fromRGB(255, 196, 64),
	},
	GrappleHook = {
		toolName = "Grapple Hook",
		range = 150,
		speed = 115,
		cooldown = 3,
		colour = Color3.fromRGB(120, 220, 180),
	},
	BodyArmour = {
		maxHealth = 250,
	},
	Jetpack = {
		toolName = "Jetpack",
		rise = 58,         -- studs per second while held
		colour = Color3.fromRGB(150, 158, 172),
	},
}

return MarketConfig
