--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- client HUD
--
--  PLACEHOLDER. Enough on screen to confirm the client script
--  is running and the Rojo sync reached StarterPlayerScripts.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function refresh()
	local count = #Players:GetPlayers()
	status.Text = count == 1 and "1 in the house" or (count .. " in the house")
end

Players.PlayerAdded:Connect(refresh)
Players.PlayerRemoving:Connect(refresh)
refresh()
