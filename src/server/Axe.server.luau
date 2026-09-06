--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the axe
--
--  Everyone carries one alongside the hammer. It fells trees
--  and does nothing to brickwork, which is the whole point of
--  having two tools rather than one that does everything.
--
--  Felling is City.server.luau's business; this only decides
--  what got hit and asks. Swings reuse the hammer's animation
--  remote, so the arm moves the same way.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")

local CityConfig = require(ReplicatedStorage:WaitForChild("CityConfig"))
local SwingArc   = require(ReplicatedStorage:WaitForChild("SwingArc"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))

local AXE = {
	Damage = 1,
	Reach = 14,
	Cooldown = 0.5,
	HandleSize = Vector3.new(0.45, 3.6, 0.45),
}

local chopTree = ServerStorage:WaitForChild("ChopTree") :: BindableFunction
local combat = ReplicatedStorage:WaitForChild("CombatRemotes")
local swung = combat:WaitForChild("SwingStarted") :: RemoteEvent

local restGrip = CFrame.new(0, -AXE.HandleSize.Y / 2 + 0.6, 0)
	* CFrame.Angles(math.rad(90), 0, 0)

-- ===========================================================
--  The tool
-- ===========================================================

local function buildAxe(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Axe"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Hold to chop trees"
	tool.Grip = restGrip

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = AXE.HandleSize
	handle.Color = Color3.fromRGB(122, 88, 56)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool

	local function piece(name: string, size: Vector3, offset: CFrame,
		colour: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = colour
		part.Material = material
		part.CanCollide = false
		part.Massless = true
		part.CFrame = handle.CFrame * offset
		part.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = handle
	end

	piece("Head", Vector3.new(0.5, 1.9, 1.1),
		CFrame.new(0, AXE.HandleSize.Y / 2 - 0.4, 0),
		Color3.fromRGB(176, 182, 194), Enum.Material.Metal)
	piece("Blade", Vector3.new(0.22, 2.4, 1.9),
		CFrame.new(0, AXE.HandleSize.Y / 2 - 0.4, 0.9),
		Color3.fromRGB(214, 220, 230), Enum.Material.Metal)
	piece("Collar", Vector3.new(0.6, 0.4, 0.6),
		CFrame.new(0, AXE.HandleSize.Y / 2 - 1.6, 0),
		Color3.fromRGB(70, 66, 62), Enum.Material.Metal)

	return tool
end

-- ===========================================================
--  Swinging
-- ===========================================================

-- The tool carries part of the arc from the server, so a click always
-- produces visible motion whatever the rig does with the arm.
local function animateGrip(tool: Tool)
	local factor = ShopConfig.Swing.GripFactor
	if factor <= 0 then
		return
	end

	task.spawn(function()
		local started = os.clock()
		local connection: RBXScriptConnection

		connection = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - started
			if elapsed >= SwingArc.Total or not tool.Parent then
				connection:Disconnect()
				if tool.Parent then
					tool.Grip = restGrip
				end
				return
			end
			tool.Grip = restGrip
				* CFrame.Angles(math.rad(SwingArc.angleAt(elapsed) * factor), 0, 0)
		end)
	end)
end

local function chop(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("Choppable")

	local centre = root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 1.5, 0)
	local nearby = workspace:GetPartBoundsInRadius(centre, AXE.Reach, params)
	if #nearby == 0 then
		return
	end

	table.sort(nearby, function(a, b)
		return (a.Position - centre).Magnitude < (b.Position - centre).Magnitude
	end)

	local target = nearby[1]
	if not target:IsA("BasePart") then
		return
	end

	-- a visible bite out of the trunk, so swings feel like progress
	-- even before it comes down
	if target.Name == "Trunk" then
		target.Color = target.Color:Lerp(Color3.fromRGB(52, 36, 24), 0.25)
	end

	chopTree:Invoke(target, AXE.Damage, player.Name)
end

-- ===========================================================
--  Hold to keep chopping
-- ===========================================================

local holding: { [Player]: boolean } = {}
local looping: { [Player]: boolean } = {}

local function chopLoop(player: Player, tool: Tool)
	if looping[player] then
		return
	end
	looping[player] = true

	while holding[player] and tool.Parent do
		if not player.Character then
			break
		end

		swung:FireAllClients(player)
		animateGrip(tool)

		task.wait(SwingArc.ImpactAt)
		chop(player)

		local remaining = AXE.Cooldown - SwingArc.ImpactAt
		if remaining > 0 then
			task.wait(remaining)
		else
			task.wait()
		end
	end

	looping[player] = false
end

local function giveAxe(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			local existing = container:FindFirstChild("Axe")
			if existing then
				existing:Destroy()
			end
		end
	end

	local tool = buildAxe()

	tool.Activated:Connect(function()
		holding[player] = true
		task.spawn(chopLoop, player, tool)
	end)
	tool.Deactivated:Connect(function()
		holding[player] = false
	end)
	tool.Unequipped:Connect(function()
		holding[player] = false
	end)

	tool.Parent = backpack
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		holding[player] = false
		task.wait(0.25)   -- after the hammer has been handed out
		giveAxe(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	holding[player] = nil
	looping[player] = nil
end)

print(("Axe ready: %d reach, %d swings per tree"):format(AXE.Reach, CityConfig.Tree.Health))
