--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the market
--
--  A stall in the middle of the plaza that sells for coins.
--  Owns prices and the coin balance; grants by setting
--  Owns_<key> attributes, which Weapons.server.luau watches.
--
--  Nothing here touches Robux. That ladder is ShopConfig's.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketConfig = require(ReplicatedStorage:WaitForChild("MarketConfig"))

local STALL = MarketConfig.Stall

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "MarketRemotes"

local openMarket = Instance.new("RemoteEvent")
openMarket.Name = "OpenMarket"
openMarket.Parent = remotes

local buyItem = Instance.new("RemoteEvent")
buyItem.Name = "BuyItem"
buyItem.Parent = remotes

local purchaseResult = Instance.new("RemoteEvent")
purchaseResult.Name = "PurchaseResult"
purchaseResult.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  The stall
-- ===========================================================

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame,
	colour: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildStall()
	local stall = Instance.new("Model")
	stall.Name = "Market"

	local base = STALL.Position

	makePart(stall, "Floor", Vector3.new(22, 1, 22),
		CFrame.new(base + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(96, 82, 66), Enum.Material.WoodPlanks)

	-- four posts and a canopy, so it reads as a stall from across the plaza
	for _, corner in ipairs({
		Vector3.new(-9, 0, -9), Vector3.new(9, 0, -9),
		Vector3.new(-9, 0, 9), Vector3.new(9, 0, 9),
	}) do
		makePart(stall, "Post", Vector3.new(1, 12, 1),
			CFrame.new(base + corner + Vector3.new(0, 7, 0)),
			Color3.fromRGB(84, 68, 54), Enum.Material.Wood)
	end

	makePart(stall, "Canopy", Vector3.new(24, 1, 24),
		CFrame.new(base + Vector3.new(0, 13.5, 0)),
		Color3.fromRGB(196, 76, 66), Enum.Material.Fabric)

	local counter = makePart(stall, "Counter", Vector3.new(20, 4, 2.5),
		CFrame.new(base + Vector3.new(0, 3, -8)),
		Color3.fromRGB(126, 104, 82), Enum.Material.Wood)

	makePart(stall, "Trim", Vector3.new(20, 0.5, 3),
		CFrame.new(base + Vector3.new(0, 5.2, -8)),
		Color3.fromRGB(255, 205, 70), Enum.Material.Neon)

	-- a sign you can read from the far side of the plaza
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(16, 4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	sign.MaxDistance = 400
	sign.AlwaysOnTop = false
	sign.Parent = counter

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 235, 190)
	label.TextStrokeTransparency = 0.3
	label.Text = "MARKET"
	label.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Market"
	prompt.ObjectText = "Spend your coins"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = STALL.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	prompt.Triggered:Connect(function(player)
		openMarket:FireClient(player)
	end)

	stall.Parent = workspace
	return stall
end

buildStall()

-- ===========================================================
--  Buying
-- ===========================================================

local byKey: { [string]: any } = {}
for _, item in ipairs(MarketConfig.Items) do
	byKey[item.key] = item
end

local function coinsOf(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	return (coins and coins:IsA("IntValue")) and coins or nil
end

buyItem.OnServerEvent:Connect(function(player, key)
	if type(key) ~= "string" then
		return
	end

	local item = byKey[key]
	if not item then
		return
	end

	-- Every check is here, not on the client. The UI hides what you
	-- cannot afford, but the UI is not what decides.
	if player:GetAttribute("Owns_" .. key) == true then
		purchaseResult:FireClient(player, key, false, "You already own that")
		return
	end

	local coins = coinsOf(player)
	if not coins then
		return
	end

	if coins.Value < item.price then
		purchaseResult:FireClient(player, key, false,
			("Need %d more coins"):format(item.price - coins.Value))
		return
	end

	coins.Value -= item.price
	player:SetAttribute("Owns_" .. key, true)

	purchaseResult:FireClient(player, key, true, ("Bought %s"):format(item.name))
	print(("%s bought %s for %d coins"):format(player.Name, item.name, item.price))
end)

-- ===========================================================
--  Joining
-- ===========================================================

Players.PlayerAdded:Connect(function(player)
	-- known-false to start; Score restores what was actually owned
	for _, item in ipairs(MarketConfig.Items) do
		if player:GetAttribute("Owns_" .. item.key) == nil then
			player:SetAttribute("Owns_" .. item.key, false)
		end
	end
end)

print(("Market open: %d items, %d coins per brick")
	:format(#MarketConfig.Items, MarketConfig.Economy.CoinsPerBrick))
