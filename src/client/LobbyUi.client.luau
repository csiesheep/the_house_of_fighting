--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- lobby PLAY button
--
--  Shown only while you are in the lobby. It asks the server to
--  put you in the city; the server checks you really are in the
--  lobby before it moves you, so it cannot be used to teleport
--  back to the market from somewhere else.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")
local play    = remotes:WaitForChild("Play")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "PlayButton"
button.Size = UDim2.new(0, 240, 0, 64)
button.Position = UDim2.new(0.5, -120, 1, -150)
button.BackgroundColor3 = Color3.fromRGB(214, 84, 74)
button.TextColor3 = Color3.fromRGB(255, 250, 248)
button.Font = Enum.Font.GothamBlack
button.TextSize = 30
button.Text = "PLAY"
button.Visible = false
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = button

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 20)
hint.Position = UDim2.new(0, 0, 1, 6)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(80, 78, 88)
hint.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
hint.TextStrokeTransparency = 0.4
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 14
hint.Text = "or walk through the portal"
hint.Parent = button

local function refresh()
	button.Visible = player:GetAttribute("InLobby") == true
end

button.MouseButton1Click:Connect(function()
	play:FireServer()
end)

player:GetAttributeChangedSignal("InLobby"):Connect(refresh)
refresh()
