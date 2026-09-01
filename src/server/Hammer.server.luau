--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the hammer
--
--  Hold the mouse and the character keeps swinging: the arm
--  rears back over the shoulder, chops down, and the hit lands
--  at the bottom of the chop rather than the instant you
--  clicked. Damage follows the animation, not the input.
--
--  Which hammer you get is read from the HammerTier attribute,
--  set by Shop.server.luau. This script never asks who owns
--  what -- it just rebuilds the tool when the tier changes.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local ShopConfig  = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Breaking    = require(ReplicatedStorage:WaitForChild("Breaking"))

local TAG = HouseConfig.BreakableTag
local HANDLE_SIZE = HouseConfig.Hammer.HandleSize
local SWING = ShopConfig.Swing

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
--  Animating the arm
--
--  Roblox has no built-in swing animation to load, so the
--  shoulder joint is driven directly. R15 and R6 keep it in
--  different places, hence the lookup.
-- ===========================================================

local restC0: { [Motor6D]: CFrame } = {}

local function shoulderOf(character: Model): Motor6D?
	local upper = character:FindFirstChild("RightUpperArm")
	if upper then
		local motor = upper:FindFirstChild("RightShoulder")
		if motor and motor:IsA("Motor6D") then
			return motor
		end
	end

	local torso = character:FindFirstChild("Torso")
	if torso then
		local motor = torso:FindFirstChild("Right Shoulder")
		if motor and motor:IsA("Motor6D") then
			return motor
		end
	end

	return nil
end

-- Always tween back to the pose the joint had before we ever touched
-- it. Tweening back to "wherever it is now" lets the arm drift a few
-- degrees per swing until the character is holding it sideways.
local function poseOf(motor: Motor6D): CFrame
	local rest = restC0[motor]
	if not rest then
		rest = motor.C0
		restC0[motor] = rest
	end
	return rest
end

local function playSwing(character: Model, tool: Tool)
	local motor = shoulderOf(character)

	if not motor then
		-- unusual rig: fall back to snapping the grip so the swing is
		-- still visible, even if the arm does not move
		tool.Grip = restGrip * CFrame.Angles(0, 0, math.rad(-75))
		task.wait(SWING.RaiseTime + SWING.ChopTime)
		tool.Grip = restGrip
		return
	end

	local rest = poseOf(motor)

	TweenService:Create(motor, TweenInfo.new(SWING.RaiseTime, Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out), {
		C0 = rest * CFrame.Angles(math.rad(SWING.RaiseAngle), 0, 0),
	}):Play()
	task.wait(SWING.RaiseTime)

	TweenService:Create(motor, TweenInfo.new(SWING.ChopTime, Enum.EasingStyle.Quad,
		Enum.EasingDirection.In), {
		C0 = rest * CFrame.Angles(math.rad(SWING.ChopAngle), 0, 0),
	}):Play()
	task.wait(SWING.ChopTime)

	-- the caller lands the hit here, at the bottom of the chop

	task.delay(SWING.HoldTime, function()
		if motor.Parent then
			TweenService:Create(motor, TweenInfo.new(SWING.ReturnTime,
				Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = rest }):Play()
		end
	end)
end

-- ===========================================================
--  Landing the hit
-- ===========================================================

local function connect(player: Player, spec)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return
	end

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
		Breaking.damage(hit, spec.damage, origin, spec.knockback, player)
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
		playSwing(character, tool)
		connect(player, spec)

		-- the animation already consumed part of the cooldown
		local spent = SWING.RaiseTime + SWING.ChopTime
		local remaining = spec.cooldown - spent
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

	-- clear any hammer they are holding or carrying, at any tier.
	-- matching on tier names rather than "every Tool" so upgrading
	-- does not also confiscate their coils.
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
	holding[player] = nil
	looping[player] = nil
end)

print("Hammer ready: hold to swing, tier 1 and 2 configured")
