--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the city
--
--  Decides what stands where, watches towers for collapse, and
--  rebuilds the place when it has all come down.
--
--  The parts themselves are CityBuild's job. This script had
--  grown into layout, geometry, collapse tracking and
--  scheduling all at once, so the geometry moved out.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Debris            = game:GetService("Debris")

local CityConfig   = require(ReplicatedStorage:WaitForChild("CityConfig"))
local StageConfig  = require(ReplicatedStorage:WaitForChild("StageConfig"))
local HouseConfig  = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local Breaking     = require(ReplicatedStorage:WaitForChild("Breaking"))
local CityBuild    = require(script.Parent.CityBuild)
local HouseStyles  = require(script.Parent.HouseStyles)
local HouseBuilder = require(script.Parent.HouseBuilder)

local GRID   = CityConfig.Grid
local RULES  = CityConfig.Rules
local TOWER  = CityConfig.TowerRules
local STREET = CityConfig.Street
local TREE    = CityConfig.Tree
local CAR     = CityConfig.Car
local TRAFFIC = CityConfig.Traffic
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
--  State
-- ===========================================================

local city: Folder? = nil
local rng = Random.new()
local switchReadyAt = 0

type Tower = {
	folder: Folder,
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

-- ===========================================================
--  Street dressing
--
--  Furniture goes on the pavement edge of every block, facing
--  the road, which is what turns a grid of boxes into streets.
-- ===========================================================

local function edgePoints(centre: Vector3, count: number, inset: number, phase: number?)
	local half = GRID.BlockSize / 2 - inset
	local points = {}

	for i = 1, count do
		-- walk the perimeter, spreading evenly around all four sides.
		-- phase rotates the whole set, so lamps and trees interleave
		-- instead of landing on top of each other.
		local t = (((i - 0.5) / count) + (phase or 0)) % 1 * 4
		local side = math.floor(t)
		local along = (t - side) * 2 - 1     -- -1 .. 1 along that side

		local offset, facing
		if side == 0 then
			offset, facing = Vector3.new(along * half, 0, -half), 0
		elseif side == 1 then
			offset, facing = Vector3.new(half, 0, along * half), math.pi / 2
		elseif side == 2 then
			offset, facing = Vector3.new(-along * half, 0, half), math.pi
		else
			offset, facing = Vector3.new(-half, 0, -along * half), -math.pi / 2
		end

		table.insert(points, { position = centre + offset, facing = facing })
	end

	return points
end

local function dressBlock(folder: Instance, centre: Vector3)
	for _, spot in ipairs(edgePoints(centre, STREET.LampsPerBlock, STREET.Inset)) do
		CityBuild.lamp(folder, spot.position, spot.facing + math.pi)
	end

	-- offset from the lamps so the pavement alternates lamp, tree, lamp
	for _, spot in ipairs(edgePoints(centre, STREET.TreesPerBlock, STREET.Inset, 0.17)) do
		local model = CityBuild.streetTree(folder, spot.position, rng)
		local record: Tree = {
			model = model, health = CityConfig.StreetTree.Health, felled = false,
		}
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				trees[part] = record
			end
		end
	end

	for _, spot in ipairs(edgePoints(centre, STREET.PlantersPerBlock, STREET.Inset + 1, 0.4)) do
		CityBuild.planter(folder, spot.position, rng)
	end
	for _, spot in ipairs(edgePoints(centre, STREET.BenchesPerBlock, STREET.Inset + 2, 0.6)) do
		CityBuild.bench(folder, spot.position, spot.facing)
	end
	for _, spot in ipairs(edgePoints(centre, STREET.BinsPerBlock, STREET.Inset + 2, 0.85)) do
		CityBuild.bin(folder, spot.position)
	end
end

-- The surface the building itself stands on, inside the sidewalk ring.
-- Grass under the parks, concrete everywhere else.
local function buildBlockPad(folder: Instance, centre: Vector3, kind: string)
	local WALK = CityConfig.Sidewalk
	local inner = GRID.BlockSize - (WALK.Width + WALK.KerbWidth) * 2

	CityBuild.makePart(folder, "Lot", Vector3.new(inner, 1.6, inner),
		CFrame.new(centre + Vector3.new(0, WALK.PadRise - 0.8, 0)),
		kind == "P" and WALK.Grass or WALK.Pad,
		kind == "P" and Enum.Material.Grass or Enum.Material.Concrete)
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

-- The widest a building may be before it stands on its own pavement.
local function padSize(): number
	local WALK = CityConfig.Sidewalk
	return GRID.BlockSize - (WALK.Width + WALK.KerbWidth) * 2
end

-- Styles are written by hand and the grid gets retuned; rather than
-- keep the two in sync by memory, drop anything that no longer fits
-- and say so once. Silently building over the sidewalk would look
-- like a placement bug rather than a sizing one.
local function fitting(styles, label: string, brickWidth: number)
	local limit = padSize()
	local kept, dropped = {}, {}

	for _, style in ipairs(styles) do
		local scale = style.brickScale or 1
		local widest = math.max(style.widthBricks, style.depthBricks) * brickWidth * scale
		if widest <= limit then
			table.insert(kept, style)
		else
			table.insert(dropped, ("%s (%d)"):format(style.name, widest))
		end
	end

	if #dropped > 0 then
		warn(("%s: %d style(s) too wide for a %d stud pad, skipped -- %s")
			:format(label, #dropped, limit, table.concat(dropped, ", ")))
	end
	if #kept == 0 then
		warn(("%s: nothing fits a %d stud pad; falling back to the full list")
			:format(label, limit))
		return styles
	end
	return kept
end

local function registerTower(folder: Folder, base: { [BasePart]: boolean },
	baseTotal: number, centre: Vector3)
	local record: Tower = {
		folder = folder, baseTotal = baseTotal, baseLeft = baseTotal,
		collapsed = false, centre = centre,
	}
	for part in pairs(base) do
		baseOf[part] = record
	end
	table.insert(towers, record)
end

-- ===========================================================
--  Traffic
--
--  Anchored and driven by the server rather than simulated.
--  Two dozen physics vehicles would cost more than the rest of
--  the map put together and drive worse for it.
-- ===========================================================

type Car = {
	model: Model,
	base: Vector3,      -- the lane point at t = 0
	along: Vector3,     -- unit direction of travel
	span: number,       -- half the length of the run
	t: number,
	speed: number,
	crashed: boolean,

	-- t values where this car meets a crossing, in the order it will
	-- reach them. Precomputed rather than measured each frame: the
	-- grid does not move, so neither do the stop lines.
	stops: { number },
	nextStop: number,
	waitingUntil: number,
}

local traffic: { Car } = {}
local trafficOf: { [BasePart]: Car } = {}
local lastHit: { [Player]: number } = {}

local function roadLine(index: number, count: number): number
	local half = (count * GRID.BlockSize + (count + 1) * GRID.RoadWidth) / 2
	return -half + GRID.RoadWidth / 2 + (index - 1) * (GRID.BlockSize + GRID.RoadWidth)
end

-- Every junction this lane passes through, as a t value, stopped a
-- little short so the car halts at the crossing rather than in it.
local function stopsAlong(along: Vector3, span: number): { number }
	local crossAxis = math.abs(along.X) > 0.5 and "Z" or "X"
	local count = crossAxis == "Z" and GRID.Rows or GRID.Cols
	local direction = math.abs(along.X) > 0.5 and along.X or along.Z

	local stops = {}
	for i = 1, count + 1 do
		local coordinate = roadLine(i, count)
		-- position along the lane is direction * t, so t = coordinate * direction
		local at = coordinate * direction - TRAFFIC.StopApproach
		if at > -span and at < span then
			table.insert(stops, at)
		end
	end

	table.sort(stops)
	return stops
end

local function addCar(folder: Instance, base: Vector3, along: Vector3, span: number, start: number)
	local model = CityBuild.car(folder, base + along * start, 0, rng)

	local stops = stopsAlong(along, span)
	local nextStop = 1
	while nextStop <= #stops and stops[nextStop] < start do
		nextStop += 1
	end

	local car: Car = {
		model = model, base = base, along = along, span = span,
		t = start,
		speed = TRAFFIC.Speed + rng:NextNumber(-TRAFFIC.SpeedJitter, TRAFFIC.SpeedJitter),
		crashed = false,
		stops = stops, nextStop = nextStop, waitingUntil = 0,
	}

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			trafficOf[part] = car
		end
	end

	-- getting run over should hurt, but not once per frame of contact
	local body = model.PrimaryPart
	if body then
		body.Touched:Connect(function(hit)
			if car.crashed then
				return
			end
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not (player and humanoid and humanoid.Health > 0) then
				return
			end
			local now = os.clock()
			if lastHit[player] and now - lastHit[player] < TRAFFIC.HitCooldown then
				return
			end
			lastHit[player] = now
			humanoid:TakeDamage(TRAFFIC.Damage)
		end)
	end

	table.insert(traffic, car)
end

local function buildTraffic(folder: Instance)
	traffic = {}
	trafficOf = {}

	local halfX = StageConfig.Bounds.HalfX
	local halfZ = StageConfig.Bounds.HalfZ

	-- roads running north to south, then east to west. One car per
	-- lane per road, offset to its own side of the centre line.
	for i = 1, GRID.Cols + 1 do
		local x = roadLine(i, GRID.Cols)
		for _, direction in ipairs({ 1, -1 }) do
			for n = 1, TRAFFIC.PerLane do
				local start = -halfZ + (n - 0.5) * (2 * halfZ / TRAFFIC.PerLane)
				addCar(folder,
					ORIGIN + Vector3.new(x - TRAFFIC.LaneOffset * direction, 0, 0),
					Vector3.new(0, 0, direction), halfZ, start * direction)
			end
		end
	end

	for i = 1, GRID.Rows + 1 do
		local z = roadLine(i, GRID.Rows)
		for _, direction in ipairs({ 1, -1 }) do
			for n = 1, TRAFFIC.PerLane do
				local start = -halfX + (n - 0.5) * (2 * halfX / TRAFFIC.PerLane)
				addCar(folder,
					ORIGIN + Vector3.new(0, 0, z + TRAFFIC.LaneOffset * direction),
					Vector3.new(direction, 0, 0), halfX, start * direction)
			end
		end
	end
end

RunService.Heartbeat:Connect(function(delta)
	local now = os.clock()

	for _, car in ipairs(traffic) do
		if car.crashed or not car.model.Parent then
			continue
		end

		if now < car.waitingUntil then
			continue          -- sitting at a crossing
		end

		car.t += car.speed * delta

		-- pull up exactly on the stop line rather than wherever this
		-- frame happened to land, or the queue looks ragged
		local stop = car.stops[car.nextStop]
		if stop and car.t >= stop then
			car.t = stop
			car.waitingUntil = now + TRAFFIC.StopTime
			car.nextStop += 1
		end

		if car.t > car.span then
			car.t = -car.span         -- off one edge, back on at the other
			car.nextStop = 1
		end

		local position = car.base + car.along * car.t
		car.model:PivotTo(CFrame.lookAt(position, position + car.along))
	end
end)

local function buildCity()
	local folder = Instance.new("Folder")
	folder.Name = "City"

	towers = {}
	baseOf = {}
	trees = {}

	local counts = { S = 0, T = 0, A = 0, H = 0, P = 0, C = 0 }
	local brick = CityConfig.Brick.Size.X
	local stylePool = fitting(CityConfig.TowerStyles, "Towers", brick)
	local skyPool = fitting(CityConfig.SkyscraperStyles, "Skyscrapers", brick)
	local flatPool = fitting(CityConfig.ApartmentStyles, "Apartments", brick)
	local housePool = fitting(HouseStyles, "Houses", HouseConfig.House.BrickSize.X)

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
				local style = stylePool[rng:NextInteger(1, #stylePool)]
				local built, base, total = CityBuild.tower(folder, centre, style, rng)
				registerTower(built, base, total, centre)
				counts.T += 1

			elseif kind == "S" then
				local style = skyPool[rng:NextInteger(1, #skyPool)]
				local built, base, total = CityBuild.tower(folder, centre, style, rng)
				registerTower(built, base, total, centre)
				counts.S += 1

			elseif kind == "A" then
				local style = flatPool[rng:NextInteger(1, #flatPool)]
				local built, base, total = CityBuild.tower(folder, centre, style, rng)
				registerTower(built, base, total, centre)
				counts.A += 1

			elseif kind == "H" then
				local style = housePool[rng:NextInteger(1, #housePool)]
				local house = HouseBuilder.build(style,
					CFrame.lookAt(centre, Vector3.new(ORIGIN.X, centre.Y, ORIGIN.Z)))
				house.Parent = folder
				counts.H += 1

			elseif kind == "P" then
				scatter(TREE.PerPark, centre, GRID.BlockSize / 2 - 10, function(at)
					local model = CityBuild.tree(folder, at, rng)
					local record: Tree = { model = model, health = TREE.Health, felled = false }
					for _, part in ipairs(model:GetDescendants()) do
						if part:IsA("BasePart") then
							trees[part] = record
						end
					end
				end)
				counts.P += 1

			elseif kind == "C" then
				scatter(CAR.PerLot, centre, GRID.BlockSize / 2 - 12, function(at)
					CityBuild.car(folder, at, rng:NextInteger(0, 1) * math.pi / 2, rng)
				end)
				counts.C += 1
			end

			-- every block gets its pad and its pavement dressing, the
			-- market and any empty lots included
			buildBlockPad(folder, centre, kind)
			dressBlock(folder, centre)
		end
	end

	-- signals on the four corners of the market block
	local mid = blockCentre(3, GRID.Cols)
	local reach = GRID.BlockSize / 2 + GRID.RoadWidth / 2
	for _, corner in ipairs({
		{ Vector3.new(-reach, 0, -reach), 0 },
		{ Vector3.new(reach, 0, -reach), math.pi / 2 },
		{ Vector3.new(reach, 0, reach), math.pi },
		{ Vector3.new(-reach, 0, reach), -math.pi / 2 },
	}) do
		CityBuild.trafficLight(folder, ORIGIN + Vector3.new(mid, 0, mid) + corner[1], corner[2])
	end

	folder.Parent = workspace
	city = folder

	buildTraffic(folder)

	print(("City built: %d skyscrapers, %d towers, %d apartments, %d houses, "
		.. "%d parks, %d car parks, %d cars driving, %d parts")
		:format(counts.S, counts.T, counts.A, counts.H, counts.P, counts.C,
			#traffic, #folder:GetDescendants()))
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
--  Collapse
--
--  Bricks go through Breaking.shatter rather than being
--  unanchored directly, so a collapse pays out, applies
--  impulses and cleans up exactly like any other demolition.
-- ===========================================================

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
			-- pushed from the base outward, so it topples rather than
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

Breaking.Destroyed:Connect(function(credit: Player?, brick: BasePart)
	-- a car that loses a panel stops being traffic and becomes wreckage
	local car = trafficOf[brick]
	if car and not car.crashed then
		car.crashed = true
		for _, piece in ipairs(car.model:GetDescendants()) do
			if piece:IsA("BasePart") then
				piece.Anchored = false
			end
		end
	end

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

Players.PlayerRemoving:Connect(function(player)
	lastHit[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(3)

		local folder = city
		if not folder then
			continue
		end

		-- stop at the first one still standing; there is no reason to
		-- count thousands of bricks to learn the answer is "not yet"
		local standing = false
		for _, part in ipairs(CollectionService:GetTagged(TAG)) do
			if part:IsDescendantOf(folder) then
				standing = true
				break
			end
		end

		if standing then
			continue
		end

		print(("City flattened. Rebuilding in %ds."):format(RULES.RebuildDelay))
		task.wait(RULES.RebuildDelay)
		rebuildNow()
	end
end)
