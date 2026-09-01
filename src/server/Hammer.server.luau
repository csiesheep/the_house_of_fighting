--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the hammer
--
--  Hold the mouse and the character keeps swinging. The hit
--  lands at the bottom of the chop, and it lands where the
--  hammer head actually is, not along a ray from the chest.
--
--  The arm animation lives on the client, in
--  SwingAnimator.client.luau -- posing the joint from here did
--  nothing visible, because the client that owns a character
--  keeps reasserting its own joint state. The server announces
--  the swing and owns when the hit lands; the client owns how
--  it looks.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local ShopConfig  = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Breaking    = require(ReplicatedStorage:WaitForChild("Breaking"))
local SwingArc    = require(ReplicatedStorage:WaitForChild("SwingArc"))

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

local function buildHammer(spec): Tool
	local tool = Instance.new("Tool")
	tool.Name = spec.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Hold to swing"
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
--  Telling the clients to animate
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "CombatRemotes"

local swung = Instance.new("RemoteEvent")
swung.Name = "SwingStarted"
swung.Parent = remotes

remotes.Parent = ReplicatedStorage

local IMPACT_AT = SwingArc.ImpactAt

-- ===========================================================
--  Landing the hit
--
--  Previously a single ray forward from the chest, which missed
--  constantly: it only caught what was dead ahead at one height,
--  nowhere near where the head visibly was. Now the hit is a
--  sphere around the hammer head itself, so if the head reached
--  the brick, the brick takes it.
-- ===========================================================

local function connect(player: Player, spec, tool: Tool)
	local character = player.Character
	if not character then
		return
	end

	local head = tool:FindFirstChild("Head")
	local centre: Vector3? = (head and head:IsA("BasePart")) and head.Position or nil

	if not centre then
		local root = character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return
		end
		centre = root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 1, 0)
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged(TAG)

	local nearby = workspace:GetPartBoundsInRadius(centre :: Vector3, spec.hitRadius, params)
	if #nearby == 0 then
		return
	end

	-- nearest first, so one swing does not scatter across a whole wall
	table.sort(nearby, function(a, b)
		return (a.Position - centre :: Vector3).Magnitude
			< (b.Position - centre :: Vector3).Magnitude
	end)

	local landed = 0
	for _, brick in ipairs(nearby) do
		if landed >= spec.maxHits then
			break
		end
		if brick:IsA("BasePart") then
			Breaking.damage(brick, spec.damage, centre :: Vector3, spec.knockback, player)
			landed += 1
		end
	end
end

-- ===========================================================
--  Hold to keep swinging
-- ===========================================================

local holding: { [Player]: boolean } = {}
local looping: { [Player]: boolean } = {}

local function swingLoop(player: Player, tool: Tool)
	if looping[player] then
		return
	end
	looping[player] = true

	while holding[player] and tool.Parent do
		local character = player.Character
		if not character then
			break
		end

		local spec = tierOf(player)
		swung:FireAllClients(player)

		task.wait(IMPACT_AT)
		connect(player, spec, tool)

		local remaining = spec.cooldown - IMPACT_AT
		if remaining > 0 then
			task.wait(remaining)
		else
			task.wait()
		end
	end

	looping[player] = false
end

local function giveHammer(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local spec = tierOf(player)

	-- matching on tier names rather than "every Tool" so upgrading
	-- does not also confiscate their coils
	local isHammerName: { [string]: boolean } = {}
	for _, tier in pairs(ShopConfig.HammerTiers) do
		isHammerName[tier.name] = true
	end

	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, existing in ipairs(container:GetChildren()) do
				if existing:IsA("Tool") and isHammerName[existing.Name] then
					existing:Destroy()
				end
			end
		end
	end

	local tool = buildHammer(spec)

	tool.Activated:Connect(function()
		holding[player] = true
		task.spawn(swingLoop, player, tool)
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
		task.wait(0.2)             -- Backpack is emptied on respawn; wait it out
		giveHammer(player)
	end)

	player:GetAttributeChangedSignal("HammerTier"):Connect(function()
		if player.Character then
			giveHammer(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	holding[player] = nil
	looping[player] = nil
end)

print("Hammer ready: hold to swing, client-side arm, head-centred hits")
