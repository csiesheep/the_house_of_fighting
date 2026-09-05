--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- market UI
--
--  The coin shop. Opens from the stall in the plaza, or from
--  the button. Shows your balance and what each item costs.
--
--  Buttons are enabled from the same numbers the server checks
--  against, but the client is only asking -- the server does
--  the deducting and the granting.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local MarketConfig = require(ReplicatedStorage:WaitForChild("MarketConfig"))
local Theme        = require(ReplicatedStorage:WaitForChild("Theme"))

local remotes        = ReplicatedStorage:WaitForChild("MarketRemotes")
local openMarket     = remotes:WaitForChild("OpenMarket")
local buyItem        = remotes:WaitForChild("BuyItem")
local purchaseResult = remotes:WaitForChild("PurchaseResult")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "MarketUi"
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
panel.Size = UDim2.new(0, 420, 0, 470)
panel.Position = UDim2.new(0.5, -210, 0.5, -235)
panel.BackgroundColor3 = Theme.Panel
panel.Visible = false
panel.Parent = gui
round(panel, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 30)
title.Position = UDim2.new(0, 18, 0, 14)
title.BackgroundTransparency = 1
title.TextColor3 = Theme.Ink
title.Font = Enum.Font.GothamBlack
title.TextSize = 21
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "MARKET"
title.Parent = panel

local balance = Instance.new("TextLabel")
balance.Size = UDim2.new(1, -70, 0, 18)
balance.Position = UDim2.new(0, 18, 0, 43)
balance.BackgroundTransparency = 1
balance.TextColor3 = Theme.Muted
balance.Font = Enum.Font.GothamMedium
balance.TextSize = 13
balance.TextXAlignment = Enum.TextXAlignment.Left
balance.Text = "0 coins"
balance.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.Position = UDim2.new(1, -48, 0, 16)
closeButton.BackgroundColor3 = Theme.Control
closeButton.TextColor3 = Theme.Ink
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

local marketButton = Instance.new("TextButton")
marketButton.Size = UDim2.new(0, 132, 0, 46)
marketButton.Position = UDim2.new(1, -150, 1, -118)
marketButton.BackgroundColor3 = Color3.fromRGB(226, 168, 52)
marketButton.TextColor3 = Color3.fromRGB(32, 22, 6)
marketButton.Font = Enum.Font.GothamBold
marketButton.TextSize = 18
marketButton.Text = "MARKET"
marketButton.Parent = gui
round(marketButton, 10)

marketButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)
closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)
openMarket.OnClientEvent:Connect(function()
	panel.Visible = true
end)

-- -----------------------------------------------------------
--  Toast
-- -----------------------------------------------------------

local toast = Instance.new("TextLabel")
toast.Size = UDim2.new(0, 320, 0, 46)
toast.Position = UDim2.new(0.5, -160, 0.72, 0)
toast.BackgroundColor3 = Theme.Panel
toast.TextColor3 = Theme.Ink
toast.Font = Enum.Font.GothamBold
toast.TextSize = 16
toast.Visible = false
toast.Parent = gui
round(toast, 10)

local function say(message: string, good: boolean)
	toast.Text = message
	toast.BackgroundColor3 = good and Theme.Ready or Theme.Accent
	toast.TextColor3 = good and Theme.ReadyInk or Theme.AccentInk
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0

	task.wait(2)
	local fade = TweenInfo.new(0.6)
	TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	task.wait(0.7)
	toast.Visible = false
end

-- -----------------------------------------------------------
--  Rows
-- -----------------------------------------------------------

local refreshers: { () -> () } = {}

local function addRow(item, index: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 84)
	row.BackgroundColor3 = Theme.Row
	row.LayoutOrder = index
	row.Parent = list
	round(row, 10)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -136, 0, 24)
	name.Position = UDim2.new(0, 14, 0, 12)
	name.BackgroundTransparency = 1
	name.TextColor3 = Theme.Ink
	name.Font = Enum.Font.GothamBold
	name.TextSize = 17
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = item.name
	name.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -136, 0, 40)
	desc.Position = UDim2.new(0, 14, 0, 36)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Theme.Muted
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Text = item.desc
	desc.Parent = row

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.new(0, 108, 0, 42)
	buy.Position = UDim2.new(1, -120, 0.5, -21)
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 15
	buy.Text = tostring(item.price)
	buy.Parent = row
	round(buy, 8)

	local function coinValue(): number
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		return (coins and coins:IsA("IntValue")) and coins.Value or 0
	end

	local function refresh()
		if player:GetAttribute("Owns_" .. item.key) == true then
			buy.Text = "OWNED"
			buy.BackgroundColor3 = Theme.Owned
			buy.TextColor3 = Theme.ReadyInk
			buy.AutoButtonColor = false
			return
		end

		local affordable = coinValue() >= item.price
		buy.Text = ("%d coins"):format(item.price)
		buy.BackgroundColor3 = affordable and Theme.Accent or Theme.Disabled
		buy.TextColor3 = affordable and Theme.AccentInk or Theme.DisabledInk
		buy.AutoButtonColor = affordable
	end

	buy.MouseButton1Click:Connect(function()
		if player:GetAttribute("Owns_" .. item.key) == true then
			return
		end
		buyItem:FireServer(item.key)
	end)

	table.insert(refreshers, refresh)
	player:GetAttributeChangedSignal("Owns_" .. item.key):Connect(refresh)
	refresh()
end

for index, item in ipairs(MarketConfig.Items) do
	addRow(item, index)
end

purchaseResult.OnClientEvent:Connect(function(_key: string, ok: boolean, message: string)
	task.spawn(say, message, ok)
end)

-- -----------------------------------------------------------
--  Balance tracking
-- -----------------------------------------------------------

task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 30)
	local coins = stats and stats:WaitForChild("Coins", 10)
	if not (coins and coins:IsA("IntValue")) then
		return
	end

	local function update()
		balance.Text = ("%d coins"):format(coins.Value)
		for _, refresh in ipairs(refreshers) do
			refresh()
		end
	end

	coins.Changed:Connect(update)
	update()
end)
