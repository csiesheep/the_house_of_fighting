--!strict
-- ===========================================================
--  Movement
--
--  What "normal speed" means for a player right now.
--
--  Several things set WalkSpeed back to 16 when you put a tool
--  away -- coils, boots, the admin reset. During a Sprinters
--  event that would quietly cancel the event for anyone who
--  unequipped something. They all ask here instead.
-- ===========================================================

local Movement = {}

Movement.BaseWalkSpeed = 16
Movement.BaseJumpPower = 50

local function multiplier(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return (typeof(value) == "number" and value > 0) and value or 1
end

function Movement.walkSpeed(player: Player): number
	return Movement.BaseWalkSpeed * multiplier(player, "EventSpeedMult")
end

function Movement.jumpPower(player: Player): number
	return Movement.BaseJumpPower * multiplier(player, "EventJumpMult")
end

-- Put a player back to their current normal, event included.
function Movement.reset(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Movement.walkSpeed(player)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Movement.jumpPower(player)
end

return Movement
