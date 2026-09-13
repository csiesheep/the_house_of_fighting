--!strict
-- ===========================================================
--  LobbyConfig
--
--  Where everyone arrives. A railed platform floating high
--  above the market: out of reach of the fighting, and a
--  landmark you can see from anywhere in the streets.
-- ===========================================================

local LobbyConfig = {}

LobbyConfig.Place = {
	-- well above the tallest skyscraper, and outside the height the
	-- trowel is allowed to build to, so nobody can brick their way up
	Centre = Vector3.new(0, 324, 0),
	Size = Vector3.new(120, 2, 120),
	TileCount = 6,        -- chequer across the floor, per side
	RailHeight = 7,
}

-- offsets from the centre of the floor
LobbyConfig.Spawn = {
	Offset = Vector3.new(0, 0, 40),
}

LobbyConfig.Portal = {
	Offset = Vector3.new(0, 0, -42),
	Width = 20,
	Height = 18,
	Cooldown = 1.5,
}

LobbyConfig.Board = {
	Offset = Vector3.new(-52, 0, 0),
}

LobbyConfig.Palette = {
	FloorA  = Color3.fromRGB(236, 232, 224),
	FloorB  = Color3.fromRGB(214, 208, 198),
	Rail    = Color3.fromRGB(198, 222, 244),
	Trim    = Color3.fromRGB(58, 60, 72),
	Portal  = Color3.fromRGB(120, 200, 255),
	Pillar  = Color3.fromRGB(46, 48, 60),
	Title   = Color3.fromRGB(34, 32, 40),
	Accent  = Color3.fromRGB(214, 84, 74),
}

LobbyConfig.HowToPlay = {
	"HAMMER   hold click to smash bricks for coins",
	"AXE   chop trees down",
	"TROWEL   click to build, Q to build under you",
	"CARS   press E to drive (Driver's Licence)",
	"MARKET   press E at the stall in the middle",
	"OBBIES   through the gates in the city wall",
	"TOWERS   break the ground floor, it all falls",
}

return LobbyConfig
