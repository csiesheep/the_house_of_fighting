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
local RunService         = game:GetService("RunService")

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

-- Every pass becomes a Pass_<key> attribute. Other scripts watch the
-- attribute they care about, so adding a pass to ShopConfig needs no
-- change here -- only in whatever script grants the perk.
local function refreshPasses(player: Player)
	for _, pass in ipairs(ShopConfig.GamePasses) do
		player:SetAttribute("Pass_" .. pass.key, ownsPass(player, pass.id))
	end

	-- two derived conveniences, so consumers do not repeat the mapping
	player:SetAttribute("HammerTier", player:GetAttribute("Pass_Sledgehammer") == true and 2 or 1)
	player:SetAttribute("Admin", player:GetAttribute("Pass_AdminCommands") == true)
end

-- grant the moment they buy, rather than making them rejoin
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, wasPurchased)
	if wasPurchased then
		refreshPasses(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	-- set every attribute to a known value first, so listeners never
	-- read nil while UserOwnsGamePassAsync is still in flight
	for _, pass in ipairs(ShopConfig.GamePasses) do
		player:SetAttribute("Pass_" .. pass.key, false)
	end
	player:SetAttribute("HammerTier", 1)
	player:SetAttribute("Admin", false)

	task.spawn(refreshPasses, player)
end)

-- ===========================================================
--  Developer products (consumables)
-- ===========================================================

-- GetDataStore throws outright in Studio when "Enable Studio Access to
-- API Services" is off. Losing receipt de-duplication is survivable;
-- taking the whole shop script down with it is not.
local receiptStore: DataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("PurchaseReceipts")
	end)
	if ok then
		receiptStore = store
	else
		warn("DataStore unavailable -- purchases will not be de-duplicated. "
			.. "Turn on Game Settings > Security > Enable Studio Access to API Services.")
	end
end

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
			local destroyed = Breaking.explode(root.Position, charge.Radius, charge.Knockback, player)
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

	if not receiptStore then
		-- No store. In Studio that is just the API setting being off and
		-- purchases are simulated anyway, so let testing proceed. In a
		-- live game it means we cannot promise a single grant, and
		-- refusing is the only honest answer.
		if not RunService:IsStudio() then
			warn("Refusing purchase: no DataStore, cannot guarantee single grant.")
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	else
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
	end

	local ok, granted = pcall(handler, player)
	if not (ok and granted) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if receiptStore then
		pcall(function()
			receiptStore:SetAsync(key, true)
		end)
	end

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
