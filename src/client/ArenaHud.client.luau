--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- client HUD
--
--  Title card, bricks smashed, and your coin balance. Both
--  counters are read straight off leaderstats, so the server
--  stays the only thing that can change them.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Theme"))

local player = Players.LocalPlayer

local INK   = Theme.Ink
local MUTED = Theme.Muted
local PANEL = Theme.Panel
local GOLD  = Color3.fromRGB(198, 146, 26)

local gui = Instance.new("ScreenGui")
gui.Name = "HouseHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Size = UDim2.new(0, 300, 0, 128)
card.Position = UDim2.new(0.5, -150, 0, 14)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = Theme.PanelTransparency
card.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = card

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.Position = UDim2.new(0, 0, 0, 8)
title.BackgroundTransparency = 1
title.TextColor3 = INK
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.Text = "THE HOUSE OF FIGHTING"
title.Parent = card

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 16)
status.Position = UDim2.new(0, 0, 0, 34)
status.BackgroundTransparency = 1
status.TextColor3 = MUTED
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.Text = "1 in the house"
status.Parent = card

-- -----------------------------------------------------------
--  Two counters, side by side
-- -----------------------------------------------------------

local function makeStat(x: number, caption: string, colour: Color3): TextLabel
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0.5, -12, 0, 60)
	holder.Position = UDim2.new(x, x == 0 and 10 or 2, 0, 58)
	holder.BackgroundTransparency = 1
	holder.Parent = card

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(1, 0, 0, 34)
	value.BackgroundTransparency = 1
	value.TextColor3 = colour
	value.Font = Enum.Font.GothamBlack
	value.TextSize = 27
	value.Text = "0"
	value.Parent = holder

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(1, 0, 0, 16)
	tag.Position = UDim2.new(0, 0, 0, 34)
	tag.BackgroundTransparency = 1
	tag.TextColor3 = MUTED
	tag.Font = Enum.Font.GothamMedium
	tag.TextSize = 12
	tag.Text = caption
	tag.Parent = holder

	return value
end

local bricksLabel = makeStat(0, "BRICKS", INK)
local coinsLabel  = makeStat(0.5, "COINS", GOLD)

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
			TweenService:Create(label, TweenInfo.new(0.45), { TextColor3 = rest }):Play()
		end)
		show()
	end)
end

track("Bricks", bricksLabel, INK)
track("Coins", coinsLabel, GOLD)
