--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- monetisation
--
--  Owns MarketplaceService. Grants translate into two player
--  attributes, HammerTier and Admin, and nothing else in the
--  game talks to MarketplaceService at all.
-- ===========================================================

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Breaking   = require(ReplicatedStorage:WaitForChild("Breaking"))

-- ===========================================================
--  Game passes -> attributes
-- ===========================================================

local function ownsPass(player: Player, passId: number): boolean
	if not passId or passId <= 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns == true
end

local function refreshPasses(player: Player)
	local tier = 1
	local admin = false

	for _, pass in ipairs(ShopConfig.GamePasses) do
		if ownsPass(player, pass.id) then
			if pass.key == "Sledgehammer" then
				tier = math.max(tier, 2)
			elseif pass.key == "AdminCommands" then
				admin = true
			end
		end
	end

	player:SetAttribute("HammerTier", tier)
	player:SetAttribute("Admin", admin)
end

-- grant the moment they buy, rather than making them rejoin
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, wasPurchased)
	if wasPurchased then
		refreshPasses(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("HammerTier", 1)
	player:SetAttribute("Admin", false)
	task.spawn(refreshPasses, player)
end)

-- ===========================================================
--  Developer products (consumables)
-- ===========================================================

local receiptStore = DataStoreService:GetDataStore("PurchaseReceipts")

local productHandlers: { [number]: (Player) -> boolean } = {}

for _, product in ipairs(ShopConfig.Products) do
	if product.id and product.id > 0 and product.key == "DemolitionCharge" then
		productHandlers[product.id] = function(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				return false
			end

			local charge = ShopConfig.DemolitionCharge
			local destroyed = Breaking.explode(root.Position, charge.Radius, charge.Knockback)
			print(("%s set off a charge: %d bricks"):format(player.Name, destroyed))
			return true
		end
	end
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- they left mid-purchase; Roblox calls us again when they return
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = productHandlers[receiptInfo.ProductId]
	if not handler then
		warn("Unknown product id: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Never grant the same PurchaseId twice. Without this, a server
	-- restart mid-purchase can hand out a paid item more than once.
	local key = "receipt_" .. receiptInfo.PurchaseId
	local alreadyGranted = false
	local readOk = pcall(function()
		alreadyGranted = receiptStore:GetAsync(key) ~= nil
	end)
	if not readOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if alreadyGranted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, granted = pcall(handler, player)
	if not (ok and granted) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	pcall(function()
		receiptStore:SetAsync(key, true)
	end)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===========================================================

for _, pass in ipairs(ShopConfig.GamePasses) do
	if not pass.id or pass.id == 0 then
		warn(("Game pass %q has no id yet -- create it on the Creator Dashboard and paste the id into ShopConfig."):format(pass.name))
	end
end
for _, product in ipairs(ShopConfig.Products) do
	if not product.id or product.id == 0 then
		warn(("Product %q has no id yet -- create it on the Creator Dashboard and paste the id into ShopConfig."):format(product.name))
	end
end
