--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- obby toast
--
--  A coin reward with no feedback reads as a bug, so clearing
--  a course says which one and what it paid.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local remotes  = ReplicatedStorage:WaitForChild("ObbyRemotes")
local rewarded = remotes:WaitForChild("Rewarded")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local toast = Instance.new("TextLabel")
toast.Size = UDim2.new(0, 340, 0, 62)
toast.Position = UDim2.new(0.5, -170, 0.42, 0)
toast.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
toast.TextColor3 = Color3.fromRGB(38, 30, 10)
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 22
toast.Text = ""
toast.Visible = false
toast.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = toast

rewarded.OnClientEvent:Connect(function(tierName: string, amount: number)
	toast.Text = ("%s CLEARED  +%d COINS"):format(tierName, amount)
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0

	task.wait(2.5)
	local fade = TweenInfo.new(0.7)
	TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	task.wait(0.8)
	toast.Visible = false
end)
