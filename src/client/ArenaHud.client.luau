--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- client HUD
--
--  Bricks smashed and your coin balance, tucked into the top
--  left corner. It used to sit centred at the top, which is
--  exactly where you are looking when you swing at a wall.
--
--  Both counters are read straight off leaderstats, so the
--  server stays the only thing that can change them.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Theme"))

local player = Players.LocalPlayer

local INK   = Theme.Ink
local MUTED = Theme.Muted
local GOLD  = Color3.fromRGB(198, 146, 26)

local gui = Instance.new("ScreenGui")
gui.Name = "HouseHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Stats"
card.Size = UDim2.new(0, 168, 0, 92)
card.Position = UDim2.new(0, 14, 0, 14)
card.BackgroundColor3 = Theme.Panel
card.BackgroundTransparency = 0.18
card.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = card

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 10)
padding.Parent = card

-- -----------------------------------------------------------
--  One row per stat: caption left, number right
-- -----------------------------------------------------------

local function makeRow(y: number, caption: string, colour: Color3): TextLabel
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(0.5, 0, 0, 22)
	tag.Position = UDim2.new(0, 0, 0, y)
	tag.BackgroundTransparency = 1
	tag.TextColor3 = MUTED
	tag.Font = Enum.Font.GothamMedium
	tag.TextSize = 12
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.Text = caption
	tag.Parent = card

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(0.5, 0, 0, 22)
	value.Position = UDim2.new(0.5, 0, 0, y)
	value.BackgroundTransparency = 1
	value.TextColor3 = colour
	value.Font = Enum.Font.GothamBlack
	value.TextSize = 19
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = "0"
	value.Parent = card

	return value
end

local coinsLabel  = makeRow(0, "COINS", GOLD)
local bricksLabel = makeRow(26, "BRICKS", INK)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 16)
status.Position = UDim2.new(0, 0, 0, 54)
status.BackgroundTransparency = 1
status.TextColor3 = MUTED
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "1 in the house"
status.Parent = card

local function refreshPlayers()
	local count = #Players:GetPlayers()
	status.Text = count == 1 and "1 in the house" or (count .. " in the house")
end

Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)
refreshPlayers()

-- -----------------------------------------------------------
--  Live values
-- -----------------------------------------------------------

-- Big numbers get hard to read fast, so 12400 shows as 12.4k
local function short(value: number): string
	if value >= 1000000 then
		return ("%.1fM"):format(value / 1000000)
	elseif value >= 10000 then
		return ("%.1fk"):format(value / 1000)
	end
	return tostring(value)
end

local function track(name: string, label: TextLabel, rest: Color3)
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 30)
		local value = stats and stats:WaitForChild(name, 10)
		if not (value and value:IsA("IntValue")) then
			return
		end

		local function show()
			label.Text = short(value.Value)
		end

		value.Changed:Connect(function()
			show()
			label.TextColor3 = Theme.Flash
			TweenService:Create(label, TweenInfo.new(0.4), { TextColor3 = rest }):Play()
		end)
		show()
	end)
end

track("Coins", coinsLabel, GOLD)
track("Bricks", bricksLabel, INK)
