--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the neighbourhood
--
--  Places several houses around the arena, rebuilds them once
--  they have all been flattened, and runs the switch timer
--  that lets players call in a new set.
-- ===========================================================

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local HouseConfig  = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local StageConfig  = require(ReplicatedStorage:WaitForChild("StageConfig"))
local HouseStyles  = require(script.Parent.HouseStyles)
local HouseBuilder = require(script.Parent.HouseBuilder)

local HOUSE = HouseConfig.House
local TAG   = HouseConfig.BreakableTag

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "HouseRemotes"

-- server -> client: readyAt is a workspace:GetServerTimeNow() stamp, so
-- the client can run its own countdown without per-second chatter
local switchState = Instance.new("RemoteEvent")
switchState.Name = "SwitchState"
switchState.Parent = remotes

local requestSwitch = Instance.new("RemoteEvent")
requestSwitch.Name = "RequestSwitch"
requestSwitch.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Building the neighbourhood
-- ===========================================================

local neighbourhood: Folder? = nil
local rng = Random.new()
local switchReadyAt = 0
local currentNames = {}

local function plotPositions(): { Vector3 }
	local positions = {}
	local count = HOUSE.HouseCount
	local origin = StageConfig.Arena.Origin

	if count == 1 then
		return { origin }
	end

	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		table.insert(positions, origin + Vector3.new(
			math.cos(angle) * HOUSE.PlotRadius,
			0,
			math.sin(angle) * HOUSE.PlotRadius
		))
	end
	return positions
end

local function buildNeighbourhood()
	local folder = Instance.new("Folder")
	folder.Name = "Neighbourhood"

	currentNames = {}
	local positions = plotPositions()

	-- draw styles without repeating until the list runs out, so a
	-- switch actually looks different rather than rolling the same
	-- house three times
	local pool = table.clone(HouseStyles)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	for index, position in ipairs(positions) do
		local style = pool[((index - 1) % #pool) + 1]
		local house = HouseBuilder.build(style, position)
		house.Parent = folder
		table.insert(currentNames, style.name)
	end

	folder.Parent = workspace   -- parent once, at the end
	neighbourhood = folder

	local bricks = #folder:GetDescendants()
	print(("Neighbourhood built: %s -- %d breakable parts")
		:format(table.concat(currentNames, ", "), bricks))
end

local function broadcastSwitchState()
	switchState:FireAllClients(switchReadyAt, currentNames)
end

local function rebuildNow()
	if neighbourhood then
		neighbourhood:Destroy()
		neighbourhood = nil
	end
	buildNeighbourhood()
	switchReadyAt = workspace:GetServerTimeNow() + HOUSE.SwitchCooldown
	broadcastSwitchState()
end

rebuildNow()

-- ===========================================================
--  Switching
-- ===========================================================

requestSwitch.OnServerEvent:Connect(function(player)
	-- the client hides the button early, but the server is what decides
	if workspace:GetServerTimeNow() < switchReadyAt then
		return
	end
	print(("%s switched the neighbourhood"):format(player.Name))
	rebuildNow()
end)

-- late joiners need the current deadline
game:GetService("Players").PlayerAdded:Connect(function(player)
	task.wait(1)
	switchState:FireClient(player, switchReadyAt, currentNames)
end)

-- ===========================================================
--  Rebuild once the place has been flattened
-- ===========================================================

local rebuildSignal = Instance.new("BindableEvent")
rebuildSignal.Name = "RebuildHouse"
rebuildSignal.Parent = ServerStorage
rebuildSignal.Event:Connect(rebuildNow)

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

		print(("Neighbourhood flattened. Rebuilding in %ds."):format(HOUSE.RebuildDelay))
		task.wait(HOUSE.RebuildDelay)
		rebuildNow()
	end
end)
