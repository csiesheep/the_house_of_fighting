--!strict
-- ===========================================================
--  Breaking
--
--  Everything that can damage the house goes through here: the
--  hammer, admin /nuke, demolition charges, and whatever comes
--  next. The house itself stays ignorant of all of them.
-- ===========================================================

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local TAG = HouseConfig.BreakableTag

local Breaking = {}

-- Fired whenever a brick is destroyed, with whoever caused it (or nil
-- for anything uncredited, like an admin /nuke). Scoring listens to
-- this, so Breaking never has to know leaderstats exist.
local destroyedEvent = Instance.new("BindableEvent")
Breaking.Destroyed = destroyedEvent.Event

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

function Breaking.shatter(brick: BasePart, fromPosition: Vector3, knockback: number, credit: Player?)
	if not CollectionService:HasTag(brick, TAG) then
		return
	end
	CollectionService:RemoveTag(brick, TAG)

	collapseAbove(brick)

	brick.Anchored = false
	brick.CanCollide = true

	local push = brick.Position - fromPosition
	if push.Magnitude < 0.1 then
		push = Vector3.yAxis
	end

	local mass = brick:GetMass()
	brick:ApplyImpulse(push.Unit * mass * knockback + Vector3.new(0, mass * 12, 0))
	brick:ApplyAngularImpulse(Vector3.new(
		math.random(-1, 1), math.random(-1, 1), math.random(-1, 1)
	) * mass * 6)

	Debris:AddItem(brick, HouseConfig.Hammer.DebrisLife)
	destroyedEvent:Fire(credit, brick)
end

function Breaking.damage(brick: BasePart, amount: number, fromPosition: Vector3, knockback: number, credit: Player?)
	local health = (brick:GetAttribute("Health") :: number?) or 0
	local maxHealth = (brick:GetAttribute("MaxHealth") :: number?) or 1

	health -= amount

	if health > 0 then
		brick:SetAttribute("Health", health)
		-- visible wear, so you can see what is nearly gone
		local wear = 1 - health / maxHealth
		brick.Transparency = 0.3 * wear
		brick.Color = brick.Color:Lerp(Color3.fromRGB(90, 78, 72), 0.35 * wear)
		return false
	end

	Breaking.shatter(brick, fromPosition, knockback, credit)
	return true
end

-- Blow a spherical hole in whatever is standing.
function Breaking.explode(centre: Vector3, radius: number, knockback: number, credit: Player?): number
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged(TAG)

	local hit = workspace:GetPartBoundsInRadius(centre, radius, params)
	for _, part in ipairs(hit) do
		if part:IsA("BasePart") then
			Breaking.shatter(part, centre, knockback, credit)
		end
	end
	return #hit
end

function Breaking.flatten(fromPosition: Vector3, knockback: number, credit: Player?): number
	local bricks = CollectionService:GetTagged(TAG)
	for _, part in ipairs(bricks) do
		if part:IsA("BasePart") then
			Breaking.shatter(part, fromPosition, knockback, credit)
		end
	end
	return #bricks
end

return Breaking
