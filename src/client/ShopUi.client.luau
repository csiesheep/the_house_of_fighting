--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- shop UI
--
--  Purchase prompts are raised from the client, which is how
--  MarketplaceService is meant to be driven. The server never
--  trusts the client for the grant: it hears back from Roblox
--  through ProcessReceipt and PromptGamePassPurchaseFinished.
-- ===========================================================

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))

local player = Players.LocalPlayer

local INK    = Color3.fromRGB(240, 236, 232)
local MUTED  = Color3.fromRGB(158, 150, 148)
local PANEL  = Color3.fromRGB(26, 22, 26)
local ROW    = Color3.fromRGB(40, 34, 40)
local ACCENT = Color3.fromRGB(214, 84, 74)
local OWNED  = Color3.fromRGB(84, 168, 106)

local gui = Instance.new("ScreenGui")
gui.Name = "ShopUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- -----------------------------------------------------------
--  Panel
-- -----------------------------------------------------------

local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
panel.Size = UDim2.new(0, 400, 0, 430)
panel.Position = UDim2.new(0.5, -200, 0.5, -215)
panel.BackgroundColor3 = PANEL
panel.Visible = false
panel.Parent = gui
round(panel, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 30)
title.Position = UDim2.new(0, 18, 0, 14)
title.BackgroundTransparency = 1
title.TextColor3 = INK
title.Font = Enum.Font.GothamBlack
title.TextSize = 21
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "SHOP"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -70, 0, 18)
subtitle.Position = UDim2.new(0, 18, 0, 43)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = MUTED
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "Paid with Robux from your account"
subtitle.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.Position = UDim2.new(1, -48, 0, 16)
closeButton.BackgroundColor3 = Color3.fromRGB(58, 50, 58)
closeButton.TextColor3 = INK
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "X"
closeButton.Parent = panel
round(closeButton, 8)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -28, 1, -92)
list.Position = UDim2.new(0, 14, 0, 78)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local shopButton = Instance.new("TextButton")
shopButton.Name = "ShopButton"
shopButton.Size = UDim2.new(0, 132, 0, 46)
shopButton.Position = UDim2.new(1, -150, 1, -64)
shopButton.BackgroundColor3 = ACCENT
shopButton.TextColor3 = Color3.fromRGB(24, 14, 12)
shopButton.Font = Enum.Font.GothamBold
shopButton.TextSize = 18
shopButton.Text = "SHOP"
shopButton.Parent = gui
round(shopButton, 10)

shopButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)
closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

-- -----------------------------------------------------------
--  Rows
-- -----------------------------------------------------------

local order = 0

local function addRow(item, infoType: EnumItem, isOwned: (() -> boolean)?, prompt: () -> ())
	order += 1

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 84)
	row.BackgroundColor3 = ROW
	row.LayoutOrder = order
	row.Parent = list
	round(row, 10)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -126, 0, 24)
	name.Position = UDim2.new(0, 14, 0, 12)
	name.BackgroundTransparency = 1
	name.TextColor3 = INK
	name.Font = Enum.Font.GothamBold
	name.TextSize = 17
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = item.name
	name.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -126, 0, 40)
	desc.Position = UDim2.new(0, 14, 0, 36)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = MUTED
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Text = item.desc
	desc.Parent = row

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.new(0, 98, 0, 42)
	buy.Position = UDim2.new(1, -110, 0.5, -21)
	buy.BackgroundColor3 = ACCENT
	buy.TextColor3 = Color3.fromRGB(24, 14, 12)
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 15
	buy.Text = "..."
	buy.Parent = row
	round(buy, 8)

	-- No id yet: show the intended price so the shop reads as finished
	-- during development, but make it obviously not buyable.
	if not (item.id and item.id > 0) then
		buy.Text = item.robux and ("R$ " .. item.robux) or "soon"
		buy.BackgroundColor3 = Color3.fromRGB(74, 66, 74)
		buy.TextColor3 = Color3.fromRGB(150, 142, 150)
		buy.AutoButtonColor = false
		return
	end

	local function refresh()
		if isOwned and isOwned() then
			buy.Text = "OWNED"
			buy.BackgroundColor3 = OWNED
			buy.AutoButtonColor = false
			return
		end

		buy.BackgroundColor3 = ACCENT
		buy.AutoButtonColor = true

		-- GetProductInfo yields, so keep it off the construction path
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(item.id, infoType)
			end)
			if ok and info and info.PriceInRobux then
				buy.Text = "R$ " .. info.PriceInRobux
			else
				buy.Text = "Buy"
			end
		end)
	end

	buy.MouseButton1Click:Connect(function()
		if isOwned and isOwned() then
			return
		end
		prompt()
	end)

	refresh()
	return refresh
end

-- -----------------------------------------------------------
--  Items
-- -----------------------------------------------------------

local refreshers: { () -> () } = {}

for _, pass in ipairs(ShopConfig.GamePasses) do
	-- every pass has a Pass_<key> attribute, so no per-item mapping here
	local attribute = "Pass_" .. pass.key

	local refresh = addRow(pass, Enum.InfoType.GamePass, function()
		return player:GetAttribute(attribute) == true
	end, function()
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end)

	if refresh then
		table.insert(refreshers, refresh)
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
end

for _, product in ipairs(ShopConfig.Products) do
	-- consumables are never "owned"; they can be bought again
	addRow(product, Enum.InfoType.Product, nil, function()
		MarketplaceService:PromptProductPurchase(player, product.id)
	end)
end

-- The server flips those attributes only once Roblox confirms the
-- purchase, so the OWNED state follows the grant, never the click.
