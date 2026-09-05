--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the hourly spin
--
--  Every hour one effect is drawn and runs for five minutes.
--
--  Effects reach the rest of the game through two channels and
--  nothing else: player attributes for anything per-player,
--  and workspace attributes for anything global. Score, Obby
--  and Hammer read those multipliers without ever knowing an
--  event system exists.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage:WaitForChild("EventConfig"))
local Movement    = require(ReplicatedStorage:WaitForChild("Movement"))

local TIMING  = EventConfig.Timing
local EFFECTS = EventConfig.Effects

local BASE_GRAVITY = workspace.Gravity
local SCALE_VALUES = { "BodyDepthScale", "BodyWidthScale", "BodyHeightScale", "HeadScale" }

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "EventRemotes"

-- index of the winning effect, plus when it ends. The spin animation
-- is the client's business; the server only names the winner.
local spinStarted = Instance.new("RemoteEvent")
spinStarted.Name = "SpinStarted"
spinStarted.Parent = remotes

local eventEnded = Instance.new("RemoteEvent")
eventEnded.Name = "EventEnded"
eventEnded.Parent = remotes

local nextSpin = Instance.new("RemoteEvent")
nextSpin.Name = "NextSpin"
nextSpin.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Applying an effect
-- ===========================================================

local active: { key: string, index: number, endsAt: number }? = nil

local function setScale(player: Player, scale: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	-- R6 has no scale values; nothing to do there
	for _, name in ipairs(SCALE_VALUES) do
		local value = humanoid:FindFirstChild(name)
		if value and value:IsA("NumberValue") then
			value.Value = scale
		end
	end
end

local function applyToPlayer(player: Player, effect)
	if effect and effect.speedMultiplier then
		player:SetAttribute("EventSpeedMult", effect.speedMultiplier)
	else
		player:SetAttribute("EventSpeedMult", 1)
	end
	Movement.reset(player)

	setScale(player, (effect and effect.bodyScale) or 1)
end

local function start(index: number)
	local effect = EFFECTS[index]
	if not effect then
		return
	end

	active = {
		key = effect.key,
		index = index,
		endsAt = workspace:GetServerTimeNow() + TIMING.DurationSeconds,
	}

	-- global multipliers, read by whoever cares
	workspace:SetAttribute("CoinMultiplier", effect.coinMultiplier or 1)
	workspace:SetAttribute("DamageMultiplier", effect.damageMultiplier or 1)
	workspace.Gravity = BASE_GRAVITY * (effect.gravityMultiplier or 1)

	for _, player in ipairs(Players:GetPlayers()) do
		applyToPlayer(player, effect)
	end

	spinStarted:FireAllClients(index, (active :: any).endsAt)
	print(("Event: %s for %d seconds"):format(effect.name, TIMING.DurationSeconds))
end

local function finish()
	if not active then
		return
	end
	local name = active.key
	active = nil

	workspace:SetAttribute("CoinMultiplier", 1)
	workspace:SetAttribute("DamageMultiplier", 1)
	workspace.Gravity = BASE_GRAVITY

	for _, player in ipairs(Players:GetPlayers()) do
		applyToPlayer(player, nil)
	end

	eventEnded:FireAllClients()
	print(("Event over: %s"):format(name))
end

-- ===========================================================
--  The schedule
-- ===========================================================

local rng = Random.new()
local nextAt = 0

local function announceNext(player: Player?)
	if player then
		nextSpin:FireClient(player, nextAt)
	else
		nextSpin:FireAllClients(nextAt)
	end
end

workspace:SetAttribute("CoinMultiplier", 1)
workspace:SetAttribute("DamageMultiplier", 1)

task.spawn(function()
	nextAt = workspace:GetServerTimeNow() + TIMING.FirstSpinDelay
	announceNext(nil)

	while true do
		local wait = nextAt - workspace:GetServerTimeNow()
		if wait > 0 then
			task.wait(wait)
		end

		start(rng:NextInteger(1, #EFFECTS))
		task.wait(TIMING.DurationSeconds)
		finish()

		nextAt = workspace:GetServerTimeNow()
			+ math.max(0, TIMING.IntervalSeconds - TIMING.DurationSeconds)
		announceNext(nil)
	end
end)

-- ===========================================================
--  Joining and respawning
-- ===========================================================

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("EventSpeedMult", 1)
	player:SetAttribute("EventJumpMult", 1)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)   -- after every other script has had its turn
		local current = active
		applyToPlayer(player, current and EFFECTS[current.index] or nil)
	end)

	task.wait(1)
	local current = active
	if current then
		spinStarted:FireClient(player, current.index, current.endsAt)
	else
		announceNext(player)
	end
end)

print(("Events ready: %d effects, one every %d minutes for %d minutes")
	:format(#EFFECTS, TIMING.IntervalSeconds / 60, TIMING.DurationSeconds / 60))
