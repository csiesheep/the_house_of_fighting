--!strict
-- ===========================================================
--  SwingArc
--
--  The shape of a swing, and the machinery to find and drive
--  whichever joint a rig uses for the right arm.
--
--  Shared because the server owns the timing (when the hit
--  lands) while the client owns the motion (see
--  SwingAnimator.client.luau for why).
-- ===========================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))

local SWING = ShopConfig.Swing

local SwingArc = {}

SwingArc.Total = SWING.RaiseTime + SWING.ChopTime + SWING.HoldTime + SWING.ReturnTime
SwingArc.ImpactAt = SWING.RaiseTime + SWING.ChopTime

-- degrees at the shoulder, t seconds into the swing
function SwingArc.angleAt(t: number): number
	if t < SWING.RaiseTime then
		local a = t / SWING.RaiseTime
		return SWING.RaiseAngle * (1 - (1 - a) * (1 - a))              -- ease out, rearing back
	end
	t -= SWING.RaiseTime

	if t < SWING.ChopTime then
		local a = t / SWING.ChopTime
		return SWING.RaiseAngle + (SWING.ChopAngle - SWING.RaiseAngle) * (a * a)  -- accelerate down
	end
	t -= SWING.ChopTime

	if t < SWING.HoldTime then
		return SWING.ChopAngle                                          -- land on it
	end
	t -= SWING.HoldTime

	if t < SWING.ReturnTime then
		return SWING.ChopAngle * (1 - t / SWING.ReturnTime)
	end

	return 0
end

-- ===========================================================
--  Finding the arm, whatever the rig calls its joints
-- ===========================================================

export type Driver = {
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
		local p0, p1 = a0 and a0.Parent, a1 and a1.Parent
		return (p0 and p0:IsA("BasePart")) and p0 or nil,
			(p1 and p1:IsA("BasePart")) and p1 or nil
	end
	return nil, nil
end

local function isJoint(instance: Instance): boolean
	return instance:IsA("JointInstance") or instance:IsA("AnimationConstraint")
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
function SwingArc.armJointOf(character: Model): Instance?
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

local function rotation(axis: string, degrees: number): CFrame
	local r = math.rad(degrees)
	if axis == "Y" then
		return CFrame.Angles(0, r, 0)
	elseif axis == "Z" then
		return CFrame.Angles(0, 0, r)
	end
	return CFrame.Angles(r, 0, 0)
end

-- Which properties are worth writing to on this joint. Rather than
-- keep guessing which one a rig responds to, the client walks this
-- list one swing at a time and prints what it tried.
function SwingArc.combosFor(joint: Instance): { { channel: string, axis: string } }
	local channels: { string }
	if joint:IsA("JointInstance") then
		channels = { "C0", "C1" }
	elseif joint:IsA("AnimationConstraint") then
		channels = { "Transform", "Attachment0", "Attachment1" }
	else
		return {}
	end

	local combos = {}
	for _, channel in ipairs(channels) do
		for _, axis in ipairs({ "X", "Z", "Y" }) do
			table.insert(combos, { channel = channel, axis = axis })
		end
	end
	return combos
end

-- Build a driver for one specific property on one specific axis.
-- Returns nil when this joint has no such property, so the caller can
-- skip it rather than erroring.
function SwingArc.driverFor(joint: Instance, channel: string, axis: string): Driver?
	local label = ("%s:%s %s/%s"):format(joint.ClassName, joint.Name, channel, axis)

	-- a CFrame property directly on the joint
	if channel == "C0" or channel == "C1" or channel == "Transform" then
		local ok, rest = pcall(function()
			return (joint :: any)[channel] :: CFrame
		end)
		if not ok or typeof(rest) ~= "CFrame" then
			return nil
		end
		return {
			name = label,
			apply = function(degrees)
				(joint :: any)[channel] = rest * rotation(axis, degrees)
			end,
			reset = function()
				(joint :: any)[channel] = rest
			end,
		}
	end

	-- the CFrame of one of the joint's attachments
	if channel == "Attachment0" or channel == "Attachment1" then
		local ok, anchor = pcall(function()
			return (joint :: any)[channel]
		end)
		if not ok or not anchor or not anchor:IsA("Attachment") then
			return nil
		end
		local rest = anchor.CFrame
		return {
			name = label,
			apply = function(degrees)
				anchor.CFrame = rest * rotation(axis, degrees)
			end,
			reset = function()
				anchor.CFrame = rest
			end,
		}
	end

	return nil
end

return SwingArc
