--!strict
-- ===========================================================
--  ShopConfig
--
--  Create the passes and products on the Creator Dashboard,
--  then paste their ids here. PRICES ARE SET ON THE DASHBOARD,
--  not in this file -- the shop fetches and displays whatever
--  you set there.
--
--  An id of 0 means "not set up yet": the item still shows in
--  the shop, greyed out, and nothing errors.
-- ===========================================================

local ShopConfig = {}

ShopConfig.GamePasses = {
	{
		key  = "Sledgehammer",
		id   = 0,
		name = "Sledgehammer",
		desc = "Triple damage, longer reach, and debris that really travels.",
	},
	{
		key  = "AdminCommands",
		id   = 0,   -- price this one at 1999 on the dashboard
		name = "Admin Commands",
		desc = "Chat commands: /nuke, /rebuild, /speed, /jump, /heal, /day, /night.",
	},
}

ShopConfig.Products = {
	{
		key  = "DemolitionCharge",
		id   = 0,
		name = "Demolition Charge",
		desc = "Blows a hole clean through the house, centred on where you stand.",
	},
}

-- The hammer you carry is decided by your tier. The Sledgehammer
-- pass moves you from 1 to 2; everything else reads from here.
ShopConfig.HammerTiers = {
	[1] = {
		name      = "Hammer",
		damage    = 1,
		reach     = 12,
		knockback = 34,
		cooldown  = 0.45,
		headSize  = Vector3.new(1.5, 1.5, 2.8),
		headColor = Color3.fromRGB(96, 100, 110),
	},
	[2] = {
		name      = "Sledgehammer",
		damage    = 3,
		reach     = 16,
		knockback = 85,
		cooldown  = 0.5,
		headSize  = Vector3.new(2.3, 2.3, 4.2),
		headColor = Color3.fromRGB(196, 148, 62),
	},
}

ShopConfig.Admin = {
	MinSpeed = 0,
	MaxSpeed = 150,
	MinJump  = 0,
	MaxJump  = 300,
}

ShopConfig.DemolitionCharge = {
	Radius    = 16,
	Knockback = 110,
}

return ShopConfig
