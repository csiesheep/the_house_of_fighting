--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the hammer
--
--  Hold the mouse and the character keeps swinging. The hit
--  lands at the bottom of the chop, and it lands where the
--  hammer head actually is, not along a ray from the chest.
--
--  Rig note: characters here reported zero Motor6D joints, so
--  the arm driver looks for anything joint-shaped rather than
--  one class, and says exactly what it found when it fails.
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
--  Driving the arm, whatever the rig calls its joints
--
--  A driver is just "put the arm at this angle" plus "put it
--  back". Motor6D and friends expose C0; AnimationConstraint
--  exposes Transform. Anything else, we do not pretend.
-- ===========================================================

type Driver = {
	name: string,
	apply: (number) -> (),
	reset: () -> (),
}

local function endsOf(joint: Instance): (BasePart?, BasePart?)
	if joint:IsA("JointInstance") then
		return joint.Part0, joint.Part1
	end
	if joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		local p0 = a0 and a0.Parent
		local p1 = a1 and a1.Parent
		return (p0 and p0:IsA("BasePart")) and p0 or nil,
			(p1 and p1:IsA("BasePart")) and p1 or nil
	end
	return nil, nil
end

local function isJoint(instance: Instance): boolean
	return instance:IsA("JointInstance") or instance:IsA("AnimationConstraint")
end

local function driverFor(joint: Instance): Driver?
	if joint:IsA("JointInstance") then
		local rest = joint.C0
		return {
			name = joint.Name,
			apply = function(degrees)
				joint.C0 = rest * CFrame.Angles(math.rad(degrees), 0, 0)
			end,
			reset = function()
				joint.C0 = rest
			end,
		}
	end

	if joint:IsA("AnimationConstraint") then
		local rest = joint.Transform
		return {
			name = joint.Name,
			apply = function(degrees)
				joint.Transform = rest * CFrame.Angles(math.rad(degrees), 0, 0)
			end,
			reset = function()
				joint.Transform = rest
			end,
		}
	end

	return nil
end

local function gripHandOf(character: Model): BasePart?
	local grip = character:FindFirstChild("RightGrip", true)
	if grip and grip:IsA("Weld") and grip.Part0 then
		return grip.Part0
	end
	local named = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return (named and named:IsA("BasePart")) and named or nil
end

local function jointDriving(character: Model, part: BasePart?): Instance?
	if not part then
		return nil
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if isJoint(descendant) then
			local _, child = endsOf(descendant)
			if child == part then
				return descendant
			end
		end
	end
	return nil
end

-- walk hand -> wrist -> elbow -> shoulder, stopping at the torso
local function armJointOf(character: Model): Instance?
	local joint = jointDriving(character, gripHandOf(character))
	if not joint then
		return nil
	end

	for _ = 1, 4 do
		local parent = select(1, endsOf(joint))
		if not parent or string.find(string.lower(parent.Name), "torso") then
			break
		end
		local up = jointDriving(character, parent)
		if not up then
			break
		end
		joint = up
	end

	return joint
end

-- ===========================================================
--  Diagnostics, once per life
-- ===========================================================

local reported: { [Player]: boolean } = {}

local function report(player: Player, character: Model, driver: Driver?)
	if reported[player] then
		return
	end
	reported[player] = true

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rig = humanoid and humanoid.RigType.Name or "unknown"

	if driver then
		print(("Hammer: %s is %s, driving joint %q"):format(player.Name, rig, driver.name))
		return
	end

	warn(("Hammer: %s is %s and has no drivable arm joint. Swinging the tool only.")
		:format(player.Name, rig))

	local hand = gripHandOf(character)
	warn("  grip hand: " .. (hand and hand.Name or "none"))

	-- Last time this printed "Motor6Ds (0)", which told us the class was
	-- wrong but not what the right one is. So: count every class in the
	-- character, and list anything joint-shaped in full.
	local counts: { [string]: number } = {}
	local joints = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		local class = descendant.ClassName
		counts[class] = (counts[class] or 0) + 1
		if isJoint(descendant) then
			local p0, p1 = endsOf(descendant)
			table.insert(joints, ("%s:%s[%s->%s]"):format(
				class, descendant.Name,
				p0 and p0.Name or "?", p1 and p1.Name or "?"))
		end
	end

	local classList = {}
	for class, count in pairs(counts) do
		table.insert(classList, ("%s x%d"):format(class, count))
	end
	table.sort(classList)

	warn("  classes: " .. table.concat(classList, ", "))
	warn("  joints (" .. #joints .. "): " .. (#joints > 0 and table.concat(joints, ", ") or "none"))
end

-- ===========================================================
--  The swing arc
-- ===========================================================

local SWING_TOTAL = SWING.RaiseTime + SWING.ChopTime + SWING.HoldTime + SWING.ReturnTime
local IMPACT_AT = SWING.RaiseTime + SWING.ChopTime

local function angleAt(t: number): number
	if t < SWING.RaiseTime then
		local a = t / SWING.RaiseTime
		return SWING.RaiseAngle * (1 - (1 - a) * (1 - a))
	end
	t -= SWING.RaiseTime

	if t < SWING.ChopTime then
		local a = t / SWING.ChopTime
		return SWING.RaiseAngle + (SWING.ChopAngle - SWING.RaiseAngle) * (a * a)
	end
	t -= SWING.ChopTime

	if t < SWING.HoldTime then
		return SWING.ChopAngle
	end
	t -= SWING.HoldTime

	if t < SWING.ReturnTime then
		return SWING.ChopAngle * (1 - t / SWING.ReturnTime)
	end

	return 0
end

-- Driven per frame: the Animator rewrites the pose every frame, so a
-- tween that sets the joint once at the start loses the argument.
local function playSwing(player: Player, character: Model, tool: Tool)
	local joint = armJointOf(character)
	local driver = joint and driverFor(joint) or nil
	report(player, character, driver)

	-- With no joint, the tool carries the motion. Scaled well down:
	-- the full arc is 185 degrees, and putting all of that into the
	-- wrist looked like the hammer spinning rather than a chop.
	local gripFactor = driver and 0 or 0.45

	local started = os.clock()
	local connection: RBXScriptConnection

	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		local finished = elapsed >= SWING_TOTAL
		local degrees = finished and 0 or angleAt(elapsed)

		if driver then
			driver.apply(degrees)
		end
		if tool.Parent and gripFactor > 0 then
			tool.Grip = restGrip * CFrame.Angles(math.rad(degrees * gripFactor), 0, 0)
		end

		if finished then
			connection:Disconnect()
			if driver then
				driver.reset()
			end
			if tool.Parent then
				tool.Grip = restGrip
			end
		end
	end)
end

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
		playSwing(player, character, tool)

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
		reported[player] = nil     -- rig can differ between lives
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
	reported[player] = nil
end)

print("Hammer ready: hold to swing, head-centred hits")
