--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the city
--
--  Fills the block grid: towers, houses, parks of choppable
--  trees, and car parks. Replaces the old ring of houses.
--
--  Towers are the interesting one. Take enough of the ground
--  floor out and the whole thing comes down on its own,
--  because a shell standing on nothing should not keep
--  standing.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Debris            = game:GetService("Debris")

local CityConfig   = require(ReplicatedStorage:WaitForChild("CityConfig"))
local StageConfig  = require(ReplicatedStorage:WaitForChild("StageConfig"))
local HouseConfig  = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local Breaking     = require(ReplicatedStorage:WaitForChild("Breaking"))
local HouseStyles  = require(script.Parent.HouseStyles)
local HouseBuilder = require(script.Parent.HouseBuilder)

local GRID   = CityConfig.Grid
local TOWER  = CityConfig.Tower
local TREE   = CityConfig.Tree
local CAR    = CityConfig.Car
local RULES  = CityConfig.Rules
local ORIGIN = StageConfig.Bounds.Origin
local TAG    = HouseConfig.BreakableTag

-- ===========================================================
--  Remotes
--
--  Same names the old neighbourhood used, so the existing
--  switch button keeps working unchanged.
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "HouseRemotes"

local switchState = Instance.new("RemoteEvent")
switchState.Name = "SwitchState"
switchState.Parent = remotes

local requestSwitch = Instance.new("RemoteEvent")
requestSwitch.Name = "RequestSwitch"
requestSwitch.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Helpers
-- ===========================================================

local city: Folder? = nil
local rng = Random.new()
local switchReadyAt = 0

type Tower = {
	folder: Folder,
	base: { [BasePart]: boolean },
	baseTotal: number,
	baseLeft: number,
	collapsed: boolean,
	centre: Vector3,
}

local towers: { Tower } = {}
local baseOf: { [BasePart]: Tower } = {}

type Tree = { model: Model, health: number, felled: boolean }
local trees: { [BasePart]: Tree } = {}

local function blockCentre(index: number, count: number): number
	local half = (count * GRID.BlockSize + (count + 1) * GRID.RoadWidth) / 2
	return -half + GRID.RoadWidth + (index - 1) * (GRID.BlockSize + GRID.RoadWidth)
		+ GRID.BlockSize / 2
end

local function makeBrick(parent: Instance, name: string, size: Vector3, cframe: CFrame,
	colour: Color3, material: Enum.Material, health: number?, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	if health then
		part:SetAttribute("Health", health)
		part:SetAttribute("MaxHealth", health)
		CollectionService:AddTag(part, TAG)
	end
	return part
end

-- ===========================================================
--  Towers
-- ===========================================================

local function buildTower(parent: Instance, centre: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Tower"

	local brick = TOWER.BrickSize
	local width = TOWER.WidthBricks * brick.X
	local depth = TOWER.DepthBricks * brick.X
	local shade = TOWER.Palette[rng:NextInteger(1, #TOWER.Palette)]

	local record: Tower = {
		folder = folder, base = {}, baseTotal = 0, baseLeft = 0,
		collapsed = false, centre = centre,
	}

	for course = 1, TOWER.Courses do
		local y = (course - 0.5) * brick.Y
		local isGlass = course % TOWER.GlassEvery == 0
		local colour = isGlass and TOWER.Glass or shade
		local material = isGlass and Enum.Material.Glass or Enum.Material.Concrete
		local transparency = isGlass and 0.4 or 0

		-- shell only: walls, no floors. A solid tower would be 25 times
		-- the parts for an inside nobody sees.
		for side = -1, 1, 2 do
			for col = 1, TOWER.WidthBricks do
				local x = -width / 2 + (col - 0.5) * brick.X
				local part = makeBrick(folder, "Brick", brick,
					CFrame.new(centre + Vector3.new(x, y, side * depth / 2)),
					colour, material, TOWER.BrickHealth, transparency)
				if course <= TOWER.BaseCourses then
					record.base[part] = true
					record.baseTotal += 1
				end
			end

			for row = 1, TOWER.DepthBricks do
				local z = -depth / 2 + (row - 0.5) * brick.X
				local part = makeBrick(folder, "Brick",
					Vector3.new(brick.Z, brick.Y, brick.X),
					CFrame.new(centre + Vector3.new(side * width / 2, y, z)),
					colour, material, TOWER.BrickHealth, transparency)
				if course <= TOWER.BaseCourses then
					record.base[part] = true
					record.baseTotal += 1
				end
			end
		end
	end

	-- a flat roof, so it reads as a building rather than a chimney
	makeBrick(folder, "Roof",
		Vector3.new(width + 2, brick.Y, depth + 2),
		CFrame.new(centre + Vector3.new(0, TOWER.Courses * brick.Y + brick.Y / 2, 0)),
		shade:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Concrete, TOWER.BrickHealth)

	record.baseLeft = record.baseTotal
	for part in pairs(record.base) do
		baseOf[part] = record
	end

	table.insert(towers, record)
	folder.Parent = parent
end

-- When enough of the ground floor is gone, drop the rest. Bricks go
-- through Breaking.shatter rather than being unanchored directly, so
-- the collapse pays out and cleans up like any other demolition.
local function collapse(tower: Tower, credit: Player?)
	if tower.collapsed then
		return
	end
	tower.collapsed = true

	local from = tower.centre + Vector3.new(0, 2, 0)
	local falling = 0

	for _, part in ipairs(tower.folder:GetDescendants()) do
		if part:IsA("BasePart") and CollectionService:HasTag(part, TAG) then
			falling += 1
			-- push from the base outward, so it topples instead of
			-- puffing apart in every direction at once
			Breaking.shatter(part, from, 22, credit)
		end
	end

	if credit then
		local stats = credit:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then
			coins.Value += RULES.CollapseBonus
		end
		print(("%s brought a tower down: %d bricks, +%d bonus")
			:format(credit.Name, falling, RULES.CollapseBonus))
	end
end

-- ===========================================================
--  Trees
-- ===========================================================

local function buildTree(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "Tree"

	local lean = CFrame.Angles(
		math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(0, 360)),
		math.rad(rng:NextNumber(-4, 4)))

	local trunk = makeBrick(model, "Trunk",
		Vector3.new(TREE.TrunkWidth, TREE.TrunkHeight, TREE.TrunkWidth),
		CFrame.new(base + Vector3.new(0, TREE.TrunkHeight / 2, 0)) * lean,
		TREE.Trunk, Enum.Material.Wood)
	CollectionService:AddTag(trunk, "Choppable")

	for layer = 1, TREE.CanopyLayers do
		local spread = 13 - (layer - 1) * 3
		local leaf = makeBrick(model, "Leaves",
			Vector3.new(spread, 5, spread),
			CFrame.new(base + Vector3.new(0, TREE.TrunkHeight - 1 + (layer - 1) * 3.4, 0)) * lean,
			TREE.Leaves[rng:NextInteger(1, #TREE.Leaves)], Enum.Material.Grass)
		leaf.CanCollide = false
		CollectionService:AddTag(leaf, "Choppable")
	end

	model.PrimaryPart = trunk
	model.Parent = parent

	local record: Tree = { model = model, health = TREE.Health, felled = false }
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			trees[part] = record
		end
	end
end

-- ===========================================================
--  Cars
-- ===========================================================

local function buildCar(parent: Instance, base: Vector3, facing: number)
	local model = Instance.new("Model")
	model.Name = "Car"

	local paint = CAR.Palette[rng:NextInteger(1, #CAR.Palette)]
	local turn = CFrame.Angles(0, facing, 0)

	local body = makeBrick(model, "Body", CAR.Body,
		CFrame.new(base + Vector3.new(0, 2.6, 0)) * turn,
		paint, Enum.Material.Metal, CAR.BrickHealth)

	makeBrick(model, "Cabin", CAR.Cabin,
		CFrame.new(base + Vector3.new(0, 5.1, 0)) * turn,
		paint:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Glass,
		CAR.BrickHealth, 0.35)

	for _, offset in ipairs({
		Vector3.new(-3.4, 1.4, 4.4), Vector3.new(3.4, 1.4, 4.4),
		Vector3.new(-3.4, 1.4, -4.4), Vector3.new(3.4, 1.4, -4.4),
	}) do
		local wheel = makeBrick(model, "Wheel", CAR.Wheel,
			CFrame.new(base) * turn * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(34, 34, 38), Enum.Material.Rubber, CAR.BrickHealth)
		wheel.Shape = Enum.PartType.Cylinder
	end

	model.PrimaryPart = body
	model.Parent = parent
end

-- ===========================================================
--  Filling the blocks
-- ===========================================================

local function scatter(count: number, centre: Vector3, spread: number, place: (Vector3) -> ())
	local perRow = math.ceil(math.sqrt(count))
	local step = (spread * 2) / perRow
	local made = 0

	for i = 1, perRow do
		for j = 1, perRow do
			if made >= count then
				return
			end
			made += 1
			place(centre + Vector3.new(
				-spread + (i - 0.5) * step + rng:NextNumber(-3, 3),
				0,
				-spread + (j - 0.5) * step + rng:NextNumber(-3, 3)
			))
		end
	end
end

local function buildCity()
	local folder = Instance.new("Folder")
	folder.Name = "City"

	towers = {}
	baseOf = {}
	trees = {}

	local counts = { T = 0, H = 0, P = 0, C = 0 }
	local stylePool = table.clone(HouseStyles)

	for row = 1, GRID.Rows do
		local line = CityConfig.Layout[row]
		if not line then
			continue
		end
		local cells = line:gsub("%s", "")

		for col = 1, GRID.Cols do
			local kind = cells:sub(col, col)
			local centre = ORIGIN + Vector3.new(
				blockCentre(col, GRID.Cols), 0, blockCentre(row, GRID.Rows))

			if kind == "T" then
				buildTower(folder, centre)
				counts.T += 1

			elseif kind == "H" then
				local style = stylePool[rng:NextInteger(1, #stylePool)]
				local house = HouseBuilder.build(style,
					CFrame.lookAt(centre, Vector3.new(ORIGIN.X, centre.Y, ORIGIN.Z)))
				house.Parent = folder
				counts.H += 1

			elseif kind == "P" then
				scatter(TREE.PerPark, centre, GRID.BlockSize / 2 - 8, function(at)
					buildTree(folder, at)
				end)
				counts.P += 1

			elseif kind == "C" then
				scatter(CAR.PerLot, centre, GRID.BlockSize / 2 - 10, function(at)
					buildCar(folder, at, rng:NextInteger(0, 1) * math.pi / 2)
				end)
				counts.C += 1
			end
			-- "M" is the market block and "." is an empty lot; both stay clear
		end
	end

	folder.Parent = workspace
	city = folder

	print(("City built: %d towers, %d houses, %d parks, %d car parks, %d parts")
		:format(counts.T, counts.H, counts.P, counts.C, #folder:GetDescendants()))
end

local function rebuildNow()
	if city then
		city:Destroy()
		city = nil
	end
	buildCity()
	switchReadyAt = workspace:GetServerTimeNow() + RULES.SwitchCooldown
	switchState:FireAllClients(switchReadyAt, { "CITY" })
end

rebuildNow()

-- ===========================================================
--  Collapse watch
-- ===========================================================

Breaking.Destroyed:Connect(function(credit: Player?, brick: BasePart)
	local tower = baseOf[brick]
	if not tower or tower.collapsed then
		return
	end

	baseOf[brick] = nil
	tower.baseLeft -= 1

	if tower.baseLeft <= tower.baseTotal * (1 - TOWER.CollapseFraction) then
		-- deferred: we are inside Breaking's own destroy pass
		task.defer(collapse, tower, credit)
	end
end)

-- ===========================================================
--  Chopping, for the axe
-- ===========================================================

local chopping = Instance.new("BindableFunction")
chopping.Name = "ChopTree"

-- returns true if the tree came down, so the axe can pay out
chopping.OnInvoke = function(part: BasePart, damage: number, playerName: string?): boolean
	local record = trees[part]
	if not record or record.felled then
		return false
	end

	record.health -= damage
	if record.health > 0 then
		return false
	end

	record.felled = true
	local player = playerName and Players:FindFirstChild(playerName) or nil

	local pivot = record.model:GetPivot()
	for _, piece in ipairs(record.model:GetDescendants()) do
		if piece:IsA("BasePart") then
			trees[piece] = nil
			piece.Anchored = false
			piece.CanCollide = true
			CollectionService:RemoveTag(piece, "Choppable")
			piece:ApplyImpulse(Vector3.new(
				math.random(-1, 1), 0.4, math.random(-1, 1)
			).Unit * piece:GetMass() * 40)
			Debris:AddItem(piece, 8)
		end
	end

	if player then
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then
			local multiplier = workspace:GetAttribute("CoinMultiplier")
			if typeof(multiplier) ~= "number" or multiplier <= 0 then
				multiplier = 1
			end
			coins.Value += math.floor(TREE.Reward * multiplier)
		end
	end

	print(("Tree felled at %d, %d"):format(pivot.X, pivot.Z))
	return true
end

chopping.Parent = ServerStorage

-- ===========================================================
--  Rebuilding
-- ===========================================================

local rebuildSignal = Instance.new("BindableEvent")
rebuildSignal.Name = "RebuildHouse"
rebuildSignal.Parent = ServerStorage
rebuildSignal.Event:Connect(rebuildNow)

requestSwitch.OnServerEvent:Connect(function(player)
	-- the client hides the button early, but the server is what decides
	if workspace:GetServerTimeNow() < switchReadyAt then
		return
	end
	print(("%s rebuilt the city"):format(player.Name))
	rebuildNow()
end)

Players.PlayerAdded:Connect(function(player)
	task.wait(1)
	switchState:FireClient(player, switchReadyAt, { "CITY" })
end)

task.spawn(function()
	while true do
		task.wait(3)

		local folder = city
		if not folder then
			continue
		end

		local standing = 0
		for _, part in ipairs(CollectionService:GetTagged(TAG)) do
			if part:IsDescendantOf(folder) then
				standing += 1
				if standing > 0 then
					break
				end
			end
		end

		if standing > 0 then
			continue
		end

		print(("City flattened. Rebuilding in %ds."):format(RULES.RebuildDelay))
		task.wait(RULES.RebuildDelay)
		rebuildNow()
	end
end)
