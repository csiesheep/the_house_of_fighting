--!strict
-- ===========================================================
--  HouseBuilder
--
--  Turns a HouseStyles blueprint into breakable bricks.
--
--  Everything is laid out in the house's own space -- X across
--  the front, Z front-to-back, Y up from the floor -- and then
--  placed by a pivot CFrame. That is what lets ten houses ring
--  a plaza with their doors facing inward instead of all
--  pointing the same way like a car park.
--
--  Everything it makes is tagged Breakable and carries Health,
--  including the glass, the door and the roof. Nothing here
--  knows what will eventually hit it.
-- ===========================================================

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local HouseStyles = require(script.Parent.HouseStyles)

local TAG = HouseConfig.BreakableTag
local BRICK = HouseConfig.House.BrickSize

local HouseBuilder = {}

-- ===========================================================
--  Parts
-- ===========================================================

local function makePart(
	parent: Instance, size: Vector3, cframe: CFrame,
	color: Color3, material: Enum.Material, health: number, transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = "Brick"
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Health", health)
	part:SetAttribute("MaxHealth", health)
	part.Parent = parent
	CollectionService:AddTag(part, TAG)
	return part
end

-- ===========================================================
--  Walls
--
--  The door goes in the -Z wall, which is the pivot's
--  LookVector, so a house placed with CFrame.lookAt facing the
--  plaza has its front door facing the plaza.
-- ===========================================================

local function buildWalls(folder: Folder, style: HouseStyles.Style, pivot: CFrame)
	local width = style.widthBricks * BRICK.X
	local depth = style.depthBricks * BRICK.X
	local rows = style.heightBricks * style.storeys
	local health = HouseConfig.House.BrickHealth

	local doorStart = math.floor((style.widthBricks - style.doorWidth) / 2) + 1
	local doorEnd = doorStart + style.doorWidth - 1

	local windowRow: { [number]: boolean } = {}
	for _, row in ipairs(style.windowRows) do
		windowRow[row] = true
	end

	-- front and back walls run along X
	for _, side in ipairs({ -1, 1 }) do
		local z = side * depth / 2

		for row = 1, rows do
			for col = 1, style.widthBricks do
				local x = -width / 2 + (col - 0.5) * BRICK.X
				local y = (row - 0.5) * BRICK.Y
				local at = pivot * CFrame.new(x, y, z)

				local isDoorway = side == -1
					and row <= style.doorHeight
					and col >= doorStart
					and col <= doorEnd

				if isDoorway then
					-- a door you can smash, rather than a hole
					makePart(folder, Vector3.new(BRICK.X, BRICK.Y, BRICK.Z * 0.4), at,
						style.trim, Enum.Material.WoodPlanks, health)
					continue
				end

				local isWindow = windowRow[row] and (col == 2 or col == style.widthBricks - 1)
				if isWindow then
					makePart(folder, Vector3.new(BRICK.X, BRICK.Y, BRICK.Z * 0.25), at,
						Color3.fromRGB(180, 214, 226), Enum.Material.Glass, 1, 0.55)
					continue
				end

				local color = ((row + col) % 2 == 0) and style.wall or style.wallAlt
				makePart(folder, BRICK, at, color, style.material, health)
			end
		end
	end

	-- side walls run along Z, so the brick is turned end on
	for _, side in ipairs({ -1, 1 }) do
		local x = side * width / 2

		for row = 1, rows do
			for col = 1, style.depthBricks do
				local z = -depth / 2 + (col - 0.5) * BRICK.X
				local y = (row - 0.5) * BRICK.Y
				local at = pivot * CFrame.new(x, y, z)

				local isWindow = windowRow[row] and (col == 2 or col == style.depthBricks - 1)
				if isWindow then
					makePart(folder, Vector3.new(BRICK.Z * 0.25, BRICK.Y, BRICK.X), at,
						Color3.fromRGB(180, 214, 226), Enum.Material.Glass, 1, 0.55)
					continue
				end

				local color = ((row + col) % 2 == 0) and style.wall or style.wallAlt
				makePart(folder, Vector3.new(BRICK.Z, BRICK.Y, BRICK.X), at,
					color, style.material, health)
			end
		end
	end

	-- an upper floor, so a two storey house is not one tall empty box
	if style.storeys > 1 then
		for storey = 1, style.storeys - 1 do
			local y = storey * style.heightBricks * BRICK.Y
			makePart(folder,
				Vector3.new(width - BRICK.Z, 0.8, depth - BRICK.Z),
				pivot * CFrame.new(0, y, 0),
				style.trim, Enum.Material.WoodPlanks, health)
		end
	end
end

-- ===========================================================
--  Roofs
-- ===========================================================

local function buildGableEnd(folder: Folder, style: HouseStyles.Style, pivot: CFrame,
	z: number, wallTop: number)
	local width = style.widthBricks * BRICK.X
	local courses = math.max(1, math.floor(style.roofRise / BRICK.Y))
	local health = HouseConfig.House.BrickHealth

	for course = 1, courses do
		local shrink = course / (courses + 1)
		local courseWidth = width * (1 - shrink)
		if courseWidth < BRICK.X * 0.5 then
			break
		end
		makePart(folder,
			Vector3.new(courseWidth, BRICK.Y, BRICK.Z),
			pivot * CFrame.new(0, wallTop + (course - 0.5) * BRICK.Y, z),
			style.wallAlt, style.material, health)
	end
end

local function buildRoof(folder: Folder, style: HouseStyles.Style, pivot: CFrame)
	local width = style.widthBricks * BRICK.X
	local depth = style.depthBricks * BRICK.X
	local wallTop = style.heightBricks * style.storeys * BRICK.Y
	local health = HouseConfig.House.BrickHealth

	if style.roof == "flat" then
		for col = 1, style.widthBricks do
			for row = 1, style.depthBricks do
				local x = -width / 2 + (col - 0.5) * BRICK.X
				local z = -depth / 2 + (row - 0.5) * BRICK.X
				makePart(folder, Vector3.new(BRICK.X, BRICK.Y, BRICK.X),
					pivot * CFrame.new(x, wallTop + BRICK.Y / 2, z),
					style.roofColor, Enum.Material.Slate, health)
			end
		end
		return
	end

	-- gable and hip both slope down along X from a ridge running in Z
	local run = width / 2
	local rise = style.roofRise
	local slope = math.sqrt(run * run + rise * rise)
	local pitch = math.atan2(rise, run)
	local overhang = 2

	for _, side in ipairs({ -1, 1 }) do
		local panel = makePart(folder,
			Vector3.new(slope + overhang, 1.2, depth + overhang * 2),
			pivot * CFrame.new(side * run / 2, wallTop + rise / 2, 0)
				* CFrame.Angles(0, 0, -side * pitch),
			style.roofColor, Enum.Material.Slate, health)
		panel.Name = "Roof"
	end

	if style.roof == "gable" then
		buildGableEnd(folder, style, pivot, -depth / 2, wallTop)
		buildGableEnd(folder, style, pivot, depth / 2, wallTop)
	else
		-- hip: close the ends with sloped panels instead of vertical gables
		local endRun = depth / 2
		local endSlope = math.sqrt(endRun * endRun + rise * rise)
		local endPitch = math.atan2(rise, endRun)

		for _, side in ipairs({ -1, 1 }) do
			local panel = makePart(folder,
				Vector3.new(width + overhang, 1.2, endSlope + overhang),
				pivot * CFrame.new(0, wallTop + rise / 2, side * endRun / 2)
					* CFrame.Angles(side * endPitch, 0, 0),
				style.roofColor, Enum.Material.Slate, health)
			panel.Name = "Roof"
		end
	end
end

local function buildChimney(folder: Folder, style: HouseStyles.Style, pivot: CFrame)
	if not style.chimney then
		return
	end

	local width = style.widthBricks * BRICK.X
	local depth = style.depthBricks * BRICK.X
	local wallTop = style.heightBricks * style.storeys * BRICK.Y
	local health = HouseConfig.House.BrickHealth

	local x = width / 2 - BRICK.X
	local z = depth / 2 - BRICK.X
	local stack = math.max(3, math.floor(style.roofRise / BRICK.Y) + 2)

	for course = 1, stack do
		makePart(folder,
			Vector3.new(BRICK.X * 0.8, BRICK.Y, BRICK.X * 0.8),
			pivot * CFrame.new(x, wallTop + (course - 0.5) * BRICK.Y, z),
			style.wallAlt, style.material, health)
	end
end

-- ===========================================================

function HouseBuilder.build(style: HouseStyles.Style, pivot: CFrame): Folder
	local folder = Instance.new("Folder")
	folder.Name = style.name:gsub("%s", "")

	buildWalls(folder, style, pivot)
	buildRoof(folder, style, pivot)
	buildChimney(folder, style, pivot)

	return folder
end

function HouseBuilder.footprint(style: HouseStyles.Style): (number, number)
	return style.widthBricks * BRICK.X, style.depthBricks * BRICK.X
end

return HouseBuilder
