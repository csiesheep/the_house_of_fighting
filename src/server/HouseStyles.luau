--!strict
-- ===========================================================
--  HouseStyles
--
--  Blueprints, not geometry. HouseBuilder turns each of these
--  into bricks. Add a table here and it joins the rotation --
--  no other file changes.
-- ===========================================================

export type Style = {
	name: string,
	widthBricks: number,     -- along X
	depthBricks: number,     -- along Z
	heightBricks: number,    -- wall rows per storey
	storeys: number,
	roof: string,            -- "gable" | "flat" | "hip"
	roofRise: number,        -- studs from wall top to ridge
	chimney: boolean,
	doorWidth: number,
	doorHeight: number,
	windowRows: { number },
	wall: Color3,
	wallAlt: Color3,
	roofColor: Color3,
	trim: Color3,
	material: Enum.Material,
}

local HouseStyles: { Style } = {
	{
		name = "Cottage",
		widthBricks = 6, depthBricks = 5, heightBricks = 4, storeys = 1,
		roof = "gable", roofRise = 11, chimney = true,
		doorWidth = 1, doorHeight = 3, windowRows = { 3 },
		wall      = Color3.fromRGB(198, 176, 148),
		wallAlt   = Color3.fromRGB(182, 160, 133),
		roofColor = Color3.fromRGB(122, 62, 52),
		trim      = Color3.fromRGB(92, 66, 48),
		material  = Enum.Material.Sandstone,
	},
	{
		name = "Brick Terrace",
		widthBricks = 7, depthBricks = 5, heightBricks = 5, storeys = 2,
		roof = "gable", roofRise = 9, chimney = true,
		doorWidth = 2, doorHeight = 3, windowRows = { 3, 4 },
		wall      = Color3.fromRGB(150, 92, 74),
		wallAlt   = Color3.fromRGB(132, 80, 64),
		roofColor = Color3.fromRGB(74, 64, 82),
		trim      = Color3.fromRGB(206, 196, 178),
		material  = Enum.Material.Brick,
	},
	{
		name = "Beach Hut",
		widthBricks = 5, depthBricks = 4, heightBricks = 3, storeys = 1,
		roof = "hip", roofRise = 7, chimney = false,
		doorWidth = 1, doorHeight = 2, windowRows = { 2 },
		wall      = Color3.fromRGB(126, 176, 180),
		wallAlt   = Color3.fromRGB(108, 158, 162),
		roofColor = Color3.fromRGB(214, 196, 154),
		trim      = Color3.fromRGB(238, 236, 228),
		material  = Enum.Material.WoodPlanks,
	},
	{
		name = "Concrete Block",
		widthBricks = 8, depthBricks = 6, heightBricks = 5, storeys = 2,
		roof = "flat", roofRise = 0, chimney = false,
		doorWidth = 2, doorHeight = 3, windowRows = { 3, 5 },
		wall      = Color3.fromRGB(142, 142, 138),
		wallAlt   = Color3.fromRGB(126, 126, 122),
		roofColor = Color3.fromRGB(88, 88, 92),
		trim      = Color3.fromRGB(70, 74, 78),
		material  = Enum.Material.Concrete,
	},
	{
		name = "Manor",
		widthBricks = 9, depthBricks = 7, heightBricks = 5, storeys = 2,
		roof = "hip", roofRise = 13, chimney = true,
		doorWidth = 2, doorHeight = 3, windowRows = { 3, 4, 5 },
		wall      = Color3.fromRGB(228, 222, 210),
		wallAlt   = Color3.fromRGB(210, 204, 192),
		roofColor = Color3.fromRGB(58, 62, 74),
		trim      = Color3.fromRGB(70, 60, 52),
		material  = Enum.Material.Marble,
	},
}

return HouseStyles
