--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the hammer
--
--  Gives every player a hammer and turns swings into damage.
--
--  Hit detection is a server raycast from the character's eye
--  line, not Handle.Touched. Touched fires on brushing past a
--  wall, which would let you demolish the house by walking
--  along it.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local HAMMER = HouseConfig.Hammer
local TAG    = HouseConfig.BreakableTag

-- ===========================================================
--  Breaking a brick
-- ===========================================================

-- Anything resting on the brick that just died gets unanchored, so
-- the wall above sags and drops instead of floating there.
local function collapseAbove(brick: BasePart)
	if not HouseConfig.House.CollapseAbove then
		return
	end

	local size = brick.Size
	local origin = brick.Position + Vector3.new(0, size.Y, 0)
	local region = Vector3.new(size.X * 0.9, size.Y * 1.2, size.Z * 0.9)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged(TAG)

	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(origin), region, params)) do
		if part ~= brick and part:IsA("BasePart") and part.Anchored then
			part.Anchored = false
		end
	end
end

local function shatter(brick: BasePart, fromPosition: Vector3)
	CollectionService:RemoveTag(brick, TAG)

	brick.Anchored = false
	brick.CanCollide = true

	local push = brick.Position - fromPosition
	if push.Magnitude < 0.1 then
		push = Vector3.yAxis
	end
	local mass = brick:GetMass()
	brick:ApplyImpulse(push.Unit * mass * HAMMER.Knockback + Vector3.new(0, mass * 12, 0))
	brick:ApplyAngularImpulse(Vector3.new(
		math.random(-1, 1), math.random(-1, 1), math.random(-1, 1)
	) * mass * 6)

	Debris:AddItem(brick, HAMMER.DebrisLife)
end

local function damage(brick: BasePart, amount: number, fromPosition: Vector3)
	local health = (brick:GetAttribute("Health") :: number?) or 0
	local maxHealth = (brick:GetAttribute("MaxHealth") :: number?) or 1

	health -= amount

	if health > 0 then
		brick:SetAttribute("Health", health)
		-- visible damage: the brick lightens and cracks open as it weakens
		local wear = 1 - health / maxHealth
		brick.Transparency = 0.3 * wear
		brick.Color = brick.Color:Lerp(Color3.fromRGB(90, 78, 72), 0.35 * wear)
		return
	end

	collapseAbove(brick)
	shatter(brick, fromPosition)
end

-- ===========================================================
--  The tool
-- ===========================================================

local function buildHammer(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Hammer"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Swing at the house"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = HAMMER.HandleSize
	handle.Color = HouseConfig.Palette.Handle
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = HAMMER.HeadSize
	head.Color = HouseConfig.Palette.Head
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, HAMMER.HandleSize.Y / 2, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	-- tilt it so the head sits above the fist rather than through it
	tool.Grip = CFrame.new(0, -HAMMER.HandleSize.Y / 2 + 0.6, 0)
		* CFrame.Angles(math.rad(90), 0, 0)

	return tool
end

local restGrip = CFrame.new(0, -HAMMER.HandleSize.Y / 2 + 0.6, 0) * CFrame.Angles(math.rad(90), 0, 0)
local swingGrip = restGrip * CFrame.Angles(0, 0, math.rad(-75))

local lastSwing: { [Player]: number } = {}

local function onActivated(player: Player, tool: Tool)
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < HAMMER.Cooldown then
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
	local result = workspace:Raycast(origin, root.CFrame.LookVector * HAMMER.Reach, params)
	if not result then
		return
	end

	local hit = result.Instance
	if hit and hit:IsA("BasePart") and CollectionService:HasTag(hit, TAG) then
		damage(hit, HAMMER.Damage, origin)
	end
end

local function giveHammer(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	for _, existing in ipairs(backpack:GetChildren()) do
		if existing.Name == "Hammer" then
			existing:Destroy()
		end
	end

	local tool = buildHammer()
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
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
end)

print("Hammer ready: reach " .. HAMMER.Reach .. " studs, " .. HAMMER.Damage .. " damage per swing")
