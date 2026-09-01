--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- switch button
--
--  The server sends one timestamp when the neighbourhood is
--  built. The countdown runs locally against
--  workspace:GetServerTimeNow(), so there is no per-second
--  network chatter and every client agrees on the deadline.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local remotes       = ReplicatedStorage:WaitForChild("HouseRemotes")
local switchState   = remotes:WaitForChild("SwitchState")
local requestSwitch = remotes:WaitForChild("RequestSwitch")

local player = Players.LocalPlayer

local Theme = require(ReplicatedStorage:WaitForChild("Theme"))

local MUTED  = Theme.Muted
local PANEL  = Theme.Panel
local READY  = Theme.Ready

local gui = Instance.new("ScreenGui")
gui.Name = "HouseSwitchUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "SwitchButton"
button.Size = UDim2.new(0, 210, 0, 46)
button.Position = UDim2.new(0.5, -105, 0, 88)
button.BackgroundColor3 = PANEL
button.BackgroundTransparency = Theme.PanelTransparency
button.TextColor3 = MUTED
button.Font = Enum.Font.GothamBold
button.TextSize = 15
button.Text = "NEW HOUSES IN 5:00"
button.AutoButtonColor = false
button.Visible = false
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = button

local caption = Instance.new("TextLabel")
caption.Size = UDim2.new(1, 0, 0, 16)
caption.Position = UDim2.new(0, 0, 1, 2)
caption.BackgroundTransparency = 1
caption.TextColor3 = MUTED
caption.Font = Enum.Font.Gotham
caption.TextSize = 12
caption.Text = ""
caption.Parent = button

local readyAt = 0
local isReady = false

local function setReady(ready: boolean)
	if ready == isReady then
		return
	end
	isReady = ready

	if ready then
		button.Text = "SWITCH HOUSES"
		button.BackgroundColor3 = READY
		button.BackgroundTransparency = 0
		button.TextColor3 = Theme.ReadyInk
		button.AutoButtonColor = true
		-- a single pulse, so it is noticed without nagging
		button.Size = UDim2.new(0, 210, 0, 46)
		TweenService:Create(button, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, 236, 0, 52),
			Position = UDim2.new(0.5, -118, 0, 85),
		}):Play()
	else
		button.BackgroundColor3 = PANEL
		button.BackgroundTransparency = Theme.PanelTransparency
		button.TextColor3 = MUTED
		button.AutoButtonColor = false
		button.Size = UDim2.new(0, 210, 0, 46)
		button.Position = UDim2.new(0.5, -105, 0, 88)
	end
end

switchState.OnClientEvent:Connect(function(stamp: number, names: { string }?)
	readyAt = stamp
	setReady(false)
	button.Visible = true
	if names and #names > 0 then
		caption.Text = table.concat(names, "  ·  ")
	end
end)

RunService.Heartbeat:Connect(function()
	if readyAt <= 0 then
		return
	end

	local remaining = readyAt - workspace:GetServerTimeNow()
	if remaining <= 0 then
		setReady(true)
		return
	end

	setReady(false)
	local minutes = math.floor(remaining / 60)
	local seconds = math.floor(remaining % 60)
	button.Text = ("NEW HOUSES IN %d:%02d"):format(minutes, seconds)
end)

button.MouseButton1Click:Connect(function()
	if not isReady then
		return
	end
	setReady(false)
	requestSwitch:FireServer()
end)
