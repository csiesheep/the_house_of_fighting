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

function SwingArc.driverFor(joint: Instance): Driver?
	if joint:IsA("JointInstance") then
		local rest = joint.C0
		return {
			name = joint.ClassName .. ":" .. joint.Name,
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
			name = joint.ClassName .. ":" .. joint.Name,
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

return SwingArc
