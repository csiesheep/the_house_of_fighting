--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- swing animation
--
--  The arm is posed here, on the client. Posing it on the
--  server did nothing: characters are simulated by the client
--  that owns them, and that client reasserts its own joint
--  state before anything reaches the screen.
--
--  CALIBRATION MODE
--  ----------------
--  Four guesses at which property of this rig's shoulder joint
--  actually moves the arm all missed, so it is no longer a
--  guess. With ShopConfig.Swing.Calibrate on, each swing tries
--  the next candidate and prints what it tried. Swing a dozen
--  times, note which one moved your arm, and that number goes
--  into Swing.Channel / Swing.Axis to end the search.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local SwingArc   = require(ReplicatedStorage:WaitForChild("SwingArc"))
local remotes    = ReplicatedStorage:WaitForChild("CombatRemotes")
local swung      = remotes:WaitForChild("SwingStarted")

local SWING = ShopConfig.Swing
local player = Players.LocalPlayer

local active: { [Model]: boolean } = {}
local attempt = 0

local function driverFor(character: Model): (SwingArc.Driver?, string)
	local joint = SwingArc.armJointOf(character)
	if not joint then
		return nil, "no arm joint found"
	end

	if not SWING.Calibrate then
		local driver = SwingArc.driverFor(joint, SWING.Channel, SWING.Axis)
		return driver, driver and driver.name or ("cannot drive " .. SWING.Channel)
	end

	local combos = SwingArc.combosFor(joint)
	if #combos == 0 then
		return nil, "no candidates for " .. joint.ClassName
	end

	-- walk the list, one candidate per swing, wrapping at the end
	attempt += 1
	local index = ((attempt - 1) % #combos) + 1
	local combo = combos[index]

	local driver = SwingArc.driverFor(joint, combo.channel, combo.axis)
	local label = ("[%d/%d] %s axis %s"):format(index, #combos, combo.channel, combo.axis)

	if not driver then
		return nil, label .. " -- not available on this joint"
	end
	return driver, label
end

local function play(character: Model, announce: boolean)
	if active[character] then
		return
	end

	local driver, label = driverFor(character)

	if announce then
		if driver then
			print("SWING TEST " .. label)
		else
			warn("SWING TEST " .. label)
		end
	end

	if not driver then
		return
	end

	active[character] = true
	local started = os.clock()

	-- Bound just after RenderPriority.Character, which is when the
	-- Animator poses the rig. RenderStepped runs before that, so a
	-- write there is overwritten in the same frame.
	local step = "Swing_" .. character.Name .. "_" .. tostring(started)

	RunService:BindToRenderStep(step, Enum.RenderPriority.Character.Value + 1, function()
		local elapsed = os.clock() - started

		if elapsed >= SwingArc.Total or not character.Parent then
			RunService:UnbindFromRenderStep(step)
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
		-- only narrate your own swings, or the log is unreadable
		play(character, who == player)
	end
end)

Players.PlayerRemoving:Connect(function(who)
	local character = who.Character
	if character then
		active[character] = nil
	end
end)
