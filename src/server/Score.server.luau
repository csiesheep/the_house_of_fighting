--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- scoring
--
--  Owns leaderstats. Arena and everything else read the folder
--  this script creates rather than making their own, because
--  two scripts racing to create "leaderstats" can produce two
--  folders and a player list that shows neither.
--
--  Counts bricks by listening to Breaking.Destroyed, so nothing
--  that breaks something needs to know scoring exists.
-- ===========================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local Breaking = require(ReplicatedStorage:WaitForChild("Breaking"))

local SAVE_EVERY = 120   -- seconds

-- Same defensive pattern as the shop: GetDataStore throws outright
-- when Studio API access is off, and losing saved scores is much
-- better than losing the scoreboard.
--
-- GetDataStore succeeding proves nothing, though -- it returns fine
-- with API access off and every read and write then fails. So probe
-- with a real call, or we print "persistent" while silently losing
-- every save.
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("BrickScores")
	end)

	if ok and result then
		local reachable = pcall(function()
			return result:GetAsync("__probe")
		end)
		if reachable then
			store = result
		else
			warn("DataStore not reachable -- scores will not persist. "
				.. "Turn on Game Settings > Security > Enable Studio Access to API Services.")
		end
	else
		warn("DataStore unavailable -- scores will not persist between sessions.")
	end
end

local bricksOf: { [Player]: IntValue } = {}
local coinsOf: { [Player]: IntValue } = {}
local loaded: { [Player]: boolean } = {}

-- ===========================================================
--  Joining
-- ===========================================================

local function setup(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local bricks = Instance.new("IntValue")
	bricks.Name = "Bricks"
	bricks.Parent = stats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats

	local built = Instance.new("IntValue")
	built.Name = "Built"
	built.Parent = stats

	local falls = Instance.new("IntValue")
	falls.Name = "Falls"
	falls.Parent = stats

	stats.Parent = player
	bricksOf[player] = bricks
	coinsOf[player] = coins

	if not store then
		loaded[player] = true
		return
	end

	task.spawn(function()
		local ok, saved = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)

		-- add rather than assign: they may have smashed something or
		-- finished the obby in the second or two the load took
		if ok then
			if type(saved) == "number" then
				bricks.Value += saved            -- old single-number format
			elseif type(saved) == "table" then
				bricks.Value += tonumber(saved.bricks) or 0
				coins.Value += tonumber(saved.coins) or 0
			end
		end
		loaded[player] = true
	end)
end

local function save(player: Player)
	if not store or not loaded[player] then
		return   -- never write a score we failed to read; that erases it
	end
	local bricks = bricksOf[player]
	local coins = coinsOf[player]
	if not (bricks and coins) then
		return
	end

	local data = { bricks = bricks.Value, coins = coins.Value }
	pcall(function()
		store:SetAsync("player_" .. player.UserId, data)
	end)
end

Players.PlayerAdded:Connect(setup)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	bricksOf[player] = nil
	coinsOf[player] = nil
	loaded[player] = nil
end)

-- players already present when this script starts (Studio reloads)
for _, player in ipairs(Players:GetPlayers()) do
	if not player:FindFirstChild("leaderstats") then
		setup(player)
	end
end

-- ===========================================================
--  Counting
-- ===========================================================

Breaking.Destroyed:Connect(function(credit: Player?, _brick: BasePart)
	if not credit then
		return   -- admin /nuke and anything else uncredited does not score
	end
	local bricks = bricksOf[credit]
	if bricks then
		bricks.Value += 1
	end
end)

-- ===========================================================
--  Periodic save, so a crash does not cost a whole session
-- ===========================================================

task.spawn(function()
	while true do
		task.wait(SAVE_EVERY)
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

print("Scoring ready" .. (store and " (persistent)" or " (session only)"))
