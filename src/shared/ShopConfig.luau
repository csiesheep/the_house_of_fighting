--!strict
-- ===========================================================
--  ShopConfig
--
--  `robux` is the price you intend to charge. It is a DISPLAY
--  HINT only -- the real price is whatever you set on the
--  Creator Dashboard, and the shop shows the live figure once
--  the id is filled in. Setting it here charges nobody.
--
--  An id of 0 means "not set up yet": the item still appears
--  in the shop with its intended price, greyed out.
-- ===========================================================

local ShopConfig = {}

ShopConfig.GamePasses = {
	{
		key = "SpeedCoil", id = 0, robux = 199,
		name = "Speed Coil",
		desc = "Hold it and you move at more than twice the pace.",
	},
	{
		key = "GravityCoil", id = 0, robux = 199,
		name = "Gravity Coil",
		desc = "Hold it and you float. Jump onto roofs instead of round to the door.",
	},
	{
		key = "FusionCoil", id = 0, robux = 399,
		name = "Fusion Coil",
		desc = "Drop a live coil and back away. Five seconds later the wall is gone.",
	},
	{
		key = "RainbowCarpet", id = 0, robux = 599,
		name = "Rainbow Carpet",
		desc = "Lay down hovering rainbow platforms. Build your own way up.",
	},
	{
		key = "Sledgehammer", id = 0, robux = 499,
		name = "Sledgehammer",
		desc = "Triple damage, longer reach, and debris that really travels.",
	},
	{
		key = "AdminCommands", id = 0, robux = 1999,
		name = "Admin Commands",
		desc = "Chat commands: /nuke, /rebuild, /speed, /jump, /heal, /reset.",
	},
}

ShopConfig.Products = {
	{
		key = "DemolitionCharge", id = 0, robux = 99,
		name = "Demolition Charge",
		desc = "Blows a hole clean through whatever you are standing next to.",
	},
}

-- The hammer you carry is decided by your tier. The Sledgehammer
-- pass moves you from 1 to 2; everything else reads from here.
ShopConfig.HammerTiers = {
	[1] = {
		name = "Hammer", damage = 1, reach = 12, knockback = 34, cooldown = 0.45,
		hitRadius = 6,    -- studs around the hammer head that count as a hit
		maxHits   = 1,    -- bricks damaged per swing
		headSize = Vector3.new(1.5, 1.5, 2.8),
		headColor = Color3.fromRGB(96, 100, 110),
	},
	[2] = {
		name = "Sledgehammer", damage = 3, reach = 16, knockback = 85, cooldown = 0.5,
		hitRadius = 9,
		maxHits   = 4,
		headSize = Vector3.new(2.3, 2.3, 4.2),
		headColor = Color3.fromRGB(196, 148, 62),
	},
}

-- The swing animation, driven straight onto the shoulder joint.
-- The hit lands at the end of ChopTime, so raising these slows the
-- weapon down in a way you can see and react to.
ShopConfig.Swing = {
	RaiseTime  = 0.14,   -- rearing back
	ChopTime   = 0.10,   -- coming down; impact at the end of this
	HoldTime   = 0.06,   -- pause on impact, so the hit reads
	ReturnTime = 0.18,   -- back to rest

	RaiseAngle = -145,   -- degrees at the shoulder, arm up and back
	ChopAngle  = 40,     -- follow through past vertical
}

ShopConfig.Gear = {
	SpeedCoil = {
		toolName = "Speed Coil",
		colour   = Color3.fromRGB(255, 214, 64),
		walkSpeed = 42,
	},
	GravityCoil = {
		toolName = "Gravity Coil",
		colour   = Color3.fromRGB(120, 200, 255),
		jumpPower = 140,
		walkSpeed = 22,
	},
	FusionCoil = {
		toolName  = "Fusion Coil",
		colour    = Color3.fromRGB(255, 96, 64),
		fuse      = 5,      -- seconds between dropping it and the bang
		radius    = 22,
		knockback = 150,
		cooldown  = 12,     -- before you can drop another
	},
	RainbowCarpet = {
		toolName  = "Rainbow Carpet",
		size      = Vector3.new(14, 0.6, 14),
		maxPanels = 6,      -- oldest is removed past this
		lifetime  = 45,
		cooldown  = 1.5,
	},
}

ShopConfig.Admin = {
	MinSpeed = 0, MaxSpeed = 150,
	MinJump  = 0, MaxJump  = 300,
}

ShopConfig.DemolitionCharge = {
	Radius = 16,
	Knockback = 110,
}

return ShopConfig
