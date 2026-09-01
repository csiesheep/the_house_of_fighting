--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the hammer
--
--  Gives every player a hammer and turns swings into damage.
--
--  Which hammer you get is read from the HammerTier attribute,
--  set by Shop.server.luau. This script never asks who owns
--  what -- it just rebuilds the tool when the tier changes.
--
--  Hit detection is a server raycast from the character's eye
--  line, not Handle.Touched. Touched fires on brushing past a
--  wall, which would let you demolish the house by walking
--  along it.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local ShopConfig  = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Breaking    = require(ReplicatedStorage:WaitForChild("Breaking"))

local TAG = HouseConfig.BreakableTag
local HANDLE_SIZE = HouseConfig.Hammer.HandleSize

local function tierOf(player: Player)
	local tier = (player:GetAttribute("HammerTier") :: number?) or 1
	return ShopConfig.HammerTiers[tier] or ShopConfig.HammerTiers[1]
end

-- ===========================================================
--  The tool
-- ===========================================================

local restGrip = CFrame.new(0, -HANDLE_SIZE.Y / 2 + 0.6, 0) * CFrame.Angles(math.rad(90), 0, 0)
local swingGrip = restGrip * CFrame.Angles(0, 0, math.rad(-75))

local function buildHammer(spec): Tool
	local tool = Instance.new("Tool")
	tool.Name = spec.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Swing at the house"
	tool.Grip = restGrip

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = HANDLE_SIZE
	handle.Color = HouseConfig.Palette.Handle
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = spec.headSize
	head.Color = spec.headColor
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, HANDLE_SIZE.Y / 2, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	return tool
end

-- ===========================================================
--  Swinging
-- ===========================================================

local lastSwing: { [Player]: number } = {}

local function onActivated(player: Player, tool: Tool)
	local spec = tierOf(player)

	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < spec.cooldown then
		return
	end
	lastSwing[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return
	end

	-- crude swing: snap the grip forward, then let it fall back
	tool.Grip = swingGrip
	task.delay(0.18, function()
		if tool.Parent then
			tool.Grip = restGrip
		end
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local origin = root.Position + Vector3.new(0, 1.2, 0)
	local result = workspace:Raycast(origin, root.CFrame.LookVector * spec.reach, params)
	if not result then
		return
	end

	local hit = result.Instance
	if hit and hit:IsA("BasePart") and CollectionService:HasTag(hit, TAG) then
		Breaking.damage(hit, spec.damage, origin, spec.knockback)
	end
end

-- ===========================================================
--  Handing it out
-- ===========================================================

local function giveHammer(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local spec = tierOf(player)

	-- clear any hammer they are holding or carrying, at any tier
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, existing in ipairs(container:GetChildren()) do
				if existing:IsA("Tool") then
					existing:Destroy()
				end
			end
		end
	end

	local tool = buildHammer(spec)
	tool.Activated:Connect(function()
		onActivated(player, tool)
	end)
	tool.Parent = backpack
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)   -- Backpack is emptied on respawn; wait it out
		giveHammer(player)
	end)

	-- buying the Sledgehammer mid-round swaps the tool in place
	player:GetAttributeChangedSignal("HammerTier"):Connect(function()
		if player.Character then
			giveHammer(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
end)

print("Hammer ready: tier 1 and 2 configured")
