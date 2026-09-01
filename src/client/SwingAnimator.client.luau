--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- swing animation
--
--  The arm is posed here, on the client, not on the server.
--
--  The server was setting the shoulder joint every frame and
--  the arm never moved. Characters are simulated by the client
--  that owns them, and that client keeps reasserting its own
--  joint state, so a server-side pose gets masked before
--  anyone sees it.
--
--  Instead the server just announces "this player swung" and
--  every client plays the arc locally on that character. No
--  replication to fight, and it looks the same to everyone.
--
--  The real fix is an uploaded Animation asset played through
--  the Animator. That needs an asset id, so until there is one
--  this poses the joint directly.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local SwingArc = require(ReplicatedStorage:WaitForChild("SwingArc"))
local remotes  = ReplicatedStorage:WaitForChild("CombatRemotes")
local swung    = remotes:WaitForChild("SwingStarted")

-- one swing at a time per character, so holding the mouse does not
-- stack arcs on top of each other and jitter the arm
local active: { [Model]: boolean } = {}
local reported: { [Model]: boolean } = {}

local function play(character: Model)
	if active[character] then
		return
	end

	local joint = SwingArc.armJointOf(character)
	local driver = joint and SwingArc.driverFor(joint) or nil

	if not reported[character] then
		reported[character] = true
		if driver then
			print(("SwingAnimator: posing %s on %s"):format(driver.name, character.Name))
		else
			warn(("SwingAnimator: no drivable arm joint on %s"):format(character.Name))
		end
	end

	if not driver then
		return
	end

	active[character] = true
	local started = os.clock()
	local connection: RBXScriptConnection

	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started

		if elapsed >= SwingArc.Total or not character.Parent then
			connection:Disconnect()
			active[character] = nil
			if character.Parent then
				driver.reset()
			end
			return
		end

		driver.apply(SwingArc.angleAt(elapsed))
	end)
end

swung.OnClientEvent:Connect(function(who: Player)
	local character = who and who.Character
	if character then
		play(character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		active[character] = nil
		reported[character] = nil
	end
end)
