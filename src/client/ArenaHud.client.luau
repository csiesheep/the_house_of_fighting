--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- client HUD
--
--  Title card and the brick counter. The count is read straight
--  off leaderstats, so the server stays the only thing that can
--  change it.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Theme"))

local player = Players.LocalPlayer

local INK   = Theme.Ink
local MUTED = Theme.Muted
local PANEL = Theme.Panel

local gui = Instance.new("ScreenGui")
gui.Name = "HouseHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Size = UDim2.new(0, 250, 0, 66)
card.Position = UDim2.new(0.5, -125, 0, 14)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = Theme.PanelTransparency
card.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = card

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.TextColor3 = INK
title.Font = Enum.Font.GothamBlack
title.TextSize = 19
title.Text = "THE HOUSE OF FIGHTING"
title.Parent = card

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 18)
status.Position = UDim2.new(0, 0, 0, 40)
status.BackgroundTransparency = 1
status.TextColor3 = MUTED
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.Text = "1 in the house"
status.Parent = card

local score = Instance.new("TextLabel")
score.Size = UDim2.new(1, 0, 0, 34)
score.Position = UDim2.new(0, 0, 0, 62)
score.BackgroundTransparency = 1
score.TextColor3 = INK
score.Font = Enum.Font.GothamBlack
score.TextSize = 26
score.Text = "0 bricks"
score.Parent = card

card.Size = UDim2.new(0, 250, 0, 104)

local function refresh()
	local count = #Players:GetPlayers()
	status.Text = count == 1 and "1 in the house" or (count .. " in the house")
end

Players.PlayerAdded:Connect(refresh)
Players.PlayerRemoving:Connect(refresh)
refresh()

-- leaderstats appears a moment after joining, so wait rather than
-- reading nil and giving up
task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 30)
	local bricks = stats and stats:WaitForChild("Bricks", 10)
	if not (bricks and bricks:IsA("IntValue")) then
		return
	end

	local function show()
		local value = bricks.Value
		score.Text = (value == 1) and "1 brick" or (value .. " bricks")
	end

	bricks.Changed:Connect(function()
		show()
		score.TextColor3 = Theme.Flash
		TweenService:Create(score, TweenInfo.new(0.45), { TextColor3 = INK }):Play()
	end)
	show()
end)
