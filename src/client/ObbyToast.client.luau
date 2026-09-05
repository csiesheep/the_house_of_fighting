--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- obby toast
--
--  A coin reward with no feedback reads as a bug, so finishing
--  the obby says so. Also shows how long the current course
--  has left, counted down locally from one server timestamp.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local Theme   = require(ReplicatedStorage:WaitForChild("Theme"))
local remotes = ReplicatedStorage:WaitForChild("ObbyRemotes")
local rewarded  = remotes:WaitForChild("Rewarded")
local refreshed = remotes:WaitForChild("Refreshed")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- -----------------------------------------------------------
--  Reward toast
-- -----------------------------------------------------------

local toast = Instance.new("TextLabel")
toast.Size = UDim2.new(0, 300, 0, 62)
toast.Position = UDim2.new(0.5, -150, 0.42, 0)
toast.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
toast.TextColor3 = Color3.fromRGB(38, 30, 10)
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 24
toast.Text = ""
toast.Visible = false
toast.Parent = gui
round(toast, 14)

rewarded.OnClientEvent:Connect(function(amount: number)
	toast.Text = ("OBBY CLEARED  +%d COINS"):format(amount)
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0

	task.wait(2.5)
	local fade = TweenInfo.new(0.7)
	TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	task.wait(0.8)
	toast.Visible = false
end)

-- -----------------------------------------------------------
--  Course timer
-- -----------------------------------------------------------

local timer = Instance.new("TextLabel")
timer.Size = UDim2.new(0, 190, 0, 30)
timer.Position = UDim2.new(0, 16, 1, -46)
timer.BackgroundColor3 = Theme.Panel
timer.BackgroundTransparency = Theme.PanelTransparency
timer.TextColor3 = Theme.Muted
timer.Font = Enum.Font.GothamMedium
timer.TextSize = 13
timer.Text = "new obby in --:--"
timer.Visible = false
timer.Parent = gui
round(timer, 8)

local nextAt = 0

refreshed.OnClientEvent:Connect(function(stamp: number)
	nextAt = stamp
	timer.Visible = true
end)

RunService.Heartbeat:Connect(function()
	if nextAt <= 0 then
		return
	end
	local remaining = math.max(0, nextAt - workspace:GetServerTimeNow())
	timer.Text = ("new obby in %d:%02d")
		:format(math.floor(remaining / 60), math.floor(remaining % 60))
end)
