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
local RunService        = game:GetService("RunService")

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
--  Finding the shoulder
--
--  R15 keeps it at RightUpperArm.RightShoulder, R6 at
--  Torso["Right Shoulder"]. Rather than trust either layout,
--  fall through to scanning for any Motor6D driving the right
--  arm -- rig names have moved before and will again.
-- ===========================================================

-- the joint that moves this part
local function motorDriving(character: Model, part: BasePart?): Motor6D?
	if not part then
		return nil
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Part1 == part then
			return descendant
		end
	end
	return nil
end

-- the hand the tool is actually welded into
local function gripHandOf(character: Model): BasePart?
	local grip = character:FindFirstChild("RightGrip", true)
	if grip and grip:IsA("Weld") and grip.Part0 then
		return grip.Part0
	end

	local named = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return (named and named:IsA("BasePart")) and named or nil
end

-- Walk up the skeleton from the hand until the joint we are holding
-- hangs off the torso. That last joint is the shoulder, whatever the
-- rig chose to call it -- which matters, because searching by name
-- found nothing on a stock R15 character.
local function shoulderOf(character: Model): Motor6D?
	local motor = motorDriving(character, gripHandOf(character))
	if not motor then
		return nil
	end

	for _ = 1, 4 do
		local parent = motor.Part0
		if not parent then
			break
		end
		if string.find(string.lower(parent.Name), "torso") then
			break        -- gone as far as the arm goes
		end
		local up = motorDriving(character, parent)
		if not up then
			break
		end
		motor = up
	end

	return motor
end

-- Always return to the pose the joint had before we touched it.
-- Returning to "wherever it is now" drifts the arm a few degrees per
-- swing until the character holds the hammer sideways.
local restC0: { [Motor6D]: CFrame } = {}

local function poseOf(motor: Motor6D): CFrame
	local rest = restC0[motor]
	if not rest then
		rest = motor.C0
		restC0[motor] = rest
	end
	return rest
end

-- one line per player, so a rig we cannot drive says so instead of
-- silently falling back forever
local reported: { [Player]: boolean } = {}

local function report(player: Player, character: Model, motor: Motor6D?)
	if reported[player] then
		return
	end
	reported[player] = true

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rig = humanoid and humanoid.RigType.Name or "unknown"

	if motor then
		print(("Hammer: %s is %s, swinging %s (Part0=%s)")
			:format(player.Name, rig, motor.Name, motor.Part0 and motor.Part0.Name or "?"))
		return
	end

	-- If this ever fires again, do not make anyone guess a second time:
	-- print the skeleton we actually got.
	warn(("Hammer: %s is %s and no arm joint was found. Falling back to the tool only.")
		:format(player.Name, rig))

	local hand = gripHandOf(character)
	warn("  grip hand: " .. (hand and hand.Name or "none"))

	local joints = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			table.insert(joints, ("%s[%s->%s]"):format(
				descendant.Name,
				descendant.Part0 and descendant.Part0.Name or "?",
				descendant.Part1 and descendant.Part1.Name or "?"))
		end
	end
	warn("  Motor6Ds (" .. #joints .. "): " .. (table.concat(joints, ", ") :: string))
end

-- ===========================================================
--  The swing arc
-- ===========================================================

local SWING_TOTAL = SWING.RaiseTime + SWING.ChopTime + SWING.HoldTime + SWING.ReturnTime
local IMPACT_AT = SWING.RaiseTime + SWING.ChopTime

-- degrees at time t through the swing
local function angleAt(t: number): number
	if t < SWING.RaiseTime then
		local a = t / SWING.RaiseTime
		return SWING.RaiseAngle * (1 - (1 - a) * (1 - a))          -- ease out, rearing back
	end
	t -= SWING.RaiseTime

	if t < SWING.ChopTime then
		local a = t / SWING.ChopTime
		return SWING.RaiseAngle + (SWING.ChopAngle - SWING.RaiseAngle) * (a * a)   -- ease in, accelerating down
	end
	t -= SWING.ChopTime

	if t < SWING.HoldTime then
		return SWING.ChopAngle                                      -- land on it
	end
	t -= SWING.HoldTime

	if t < SWING.ReturnTime then
		local a = t / SWING.ReturnTime
		return SWING.ChopAngle * (1 - a)
	end

	return 0
end

-- Driven per frame rather than by TweenService. The Animator writes
-- the arm pose every frame, and a tween that only sets C0 once at the
-- start loses the argument.
local function playSwing(player: Player, character: Model, tool: Tool)
	local motor = shoulderOf(character)
	report(player, character, motor)

	local rest = motor and poseOf(motor) or nil

	-- When the arm swings, leave the grip alone: rotating the hammer as
	-- well as the arm was the "spinning in the hand" you saw. With no
	-- joint, tilt the tool a little rather than whipping it through
	-- 185 degrees, which read as a spin rather than a chop.
	local gripFactor = motor and 0 or 0.3

	local started = os.clock()
	local connection: RBXScriptConnection

	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		local finished = elapsed >= SWING_TOTAL
		local degrees = finished and 0 or angleAt(elapsed)

		if motor and motor.Parent and rest then
			motor.C0 = rest * CFrame.Angles(math.rad(degrees), 0, 0)
		end

		if tool.Parent and gripFactor > 0 then
			tool.Grip = restGrip * CFrame.Angles(math.rad(degrees * gripFactor), 0, 0)
		end

		if finished then
			connection:Disconnect()
			if motor and motor.Parent and rest then
				motor.C0 = rest
			end
			if tool.Parent then
				tool.Grip = restGrip
			end
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
		playSwing(player, character, tool)

		task.wait(IMPACT_AT)
		connect(player, spec)

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
		reported[player] = nil     -- rig can differ between lives
		task.wait(0.2)             -- Backpack is emptied on respawn; wait it out
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
	reported[player] = nil
end)

print("Hammer ready: hold to swing, tier 1 and 2 configured")
