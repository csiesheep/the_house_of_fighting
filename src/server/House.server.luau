--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the house
--
--  Builds a brick house out of individually breakable parts and
--  rebuilds it once the last brick is gone.
--
--  The house does not know the hammer exists. Every brick is
--  tagged Breakable with a Health attribute, and anything that
--  wants to damage one goes through that tag. Add a second
--  weapon later and nothing here changes.
-- ===========================================================

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local HOUSE = HouseConfig.House
local TAG   = HouseConfig.BreakableTag

local brick = HOUSE.BrickSize
local width = HOUSE.WidthBricks * brick.X
local depth = HOUSE.DepthBricks * brick.X

local houseFolder: Folder? = nil

-- ===========================================================
--  Building
-- ===========================================================

local function makeBrick(size: Vector3, position: Vector3, color: Color3, material: Enum.Material, parent: Instance)
	local part = Instance.new("Part")
	part.Name = "Brick"
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Health", HOUSE.BrickHealth)
	part:SetAttribute("MaxHealth", HOUSE.BrickHealth)
	part.Parent = parent
	CollectionService:AddTag(part, TAG)
	return part
end

local function brickColor(row: number, col: number): Color3
	-- offset courses, so the brickwork reads as bonded rather than a grid
	return ((row + col) % 2 == 0) and HouseConfig.Palette.Brick or HouseConfig.Palette.BrickAlt
end

local function buildHouse()
	local folder = Instance.new("Folder")
	folder.Name = "House"

	local baseY = HOUSE.Origin.Y
	local doorStart = math.floor((HOUSE.WidthBricks - HOUSE.DoorWidth) / 2) + 1
	local doorEnd = doorStart + HOUSE.DoorWidth - 1

	local windowRow: { [number]: boolean } = {}
	for _, row in ipairs(HOUSE.WindowRows) do
		windowRow[row] = true
	end

	-- front and back walls run along X
	for _, side in ipairs({ -1, 1 }) do
		local z = HOUSE.Origin.Z + side * depth / 2

		for row = 1, HOUSE.HeightBricks do
			for col = 1, HOUSE.WidthBricks do
				-- the doorway is only cut into the front wall
				local isDoor = side == -1
					and row <= HOUSE.DoorHeight
					and col >= doorStart
					and col <= doorEnd
				if isDoor then
					continue
				end

				local x = HOUSE.Origin.X - width / 2 + (col - 0.5) * brick.X
				local y = baseY + (row - 0.5) * brick.Y
				makeBrick(
					Vector3.new(brick.X, brick.Y, brick.Z),
					Vector3.new(x, y, z),
					brickColor(row, col),
					Enum.Material.Brick,
					folder
				)
			end
		end
	end

	-- side walls run along Z, so the brick is turned end on
	for _, side in ipairs({ -1, 1 }) do
		local x = HOUSE.Origin.X + side * width / 2

		for row = 1, HOUSE.HeightBricks do
			for col = 1, HOUSE.DepthBricks do
				local isWindow = windowRow[row] and (col == 2 or col == HOUSE.DepthBricks - 1)
				if isWindow then
					continue
				end

				local z = HOUSE.Origin.Z - depth / 2 + (col - 0.5) * brick.X
				local y = baseY + (row - 0.5) * brick.Y
				makeBrick(
					Vector3.new(brick.Z, brick.Y, brick.X),
					Vector3.new(x, y, z),
					brickColor(row, col),
					Enum.Material.Brick,
					folder
				)
			end
		end
	end

	-- flat roof laid over the footprint
	if HOUSE.Roof then
		local roofY = HOUSE.Origin.Y + HOUSE.HeightBricks * brick.Y + brick.Y / 2
		for col = 1, HOUSE.WidthBricks do
			for row = 1, HOUSE.DepthBricks do
				local x = HOUSE.Origin.X - width / 2 + (col - 0.5) * brick.X
				local z = HOUSE.Origin.Z - depth / 2 + (row - 0.5) * brick.X
				makeBrick(
					Vector3.new(brick.X, brick.Y, brick.X),
					Vector3.new(x, roofY, z),
					HouseConfig.Palette.Roof,
					Enum.Material.Slate,
					folder
				)
			end
		end
	end

	folder.Parent = workspace   -- parent once, at the end
	houseFolder = folder

	print(("House built: %d breakable bricks (%d x %d studs, %d rows)")
		:format(#folder:GetChildren(), width, depth, HOUSE.HeightBricks))
end

local function rebuildNow()
	if houseFolder then
		houseFolder:Destroy()
		houseFolder = nil
	end
	buildHouse()
end

buildHouse()

-- ===========================================================
--  Rebuild on demand
--
--  Exposed as a signal rather than a function so anything on the
--  server can ask for a fresh house without requiring this script.
-- ===========================================================

local rebuildSignal = Instance.new("BindableEvent")
rebuildSignal.Name = "RebuildHouse"
rebuildSignal.Parent = ServerStorage
rebuildSignal.Event:Connect(rebuildNow)

-- ===========================================================
--  Rebuild once the place has been flattened
-- ===========================================================

task.spawn(function()
	while true do
		task.wait(2)

		local standing = 0
		for _, part in ipairs(CollectionService:GetTagged(TAG)) do
			if part:IsDescendantOf(workspace) then
				standing += 1
			end
		end

		if standing > 0 then
			continue
		end

		print(("House flattened. Rebuilding in %ds."):format(HOUSE.RebuildDelay))
		task.wait(HOUSE.RebuildDelay)
		rebuildNow()
	end
end)
