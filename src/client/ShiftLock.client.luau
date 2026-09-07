--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- shift lock
--
--  A button, because Shift is not a key you have on a phone
--  and this map is big enough that lining a swing up matters.
--
--  It changes two things: the character turns to face the
--  camera, and the camera shifts to your right shoulder. That
--  is what shift lock looks like.
--
--  It deliberately does NOT lock the mouse to the centre.
--  Doing that would make the shop, the market and the
--  leaderboards unclickable, and this game has a lot of
--  buttons. Shift still works natively for anyone who wants
--  the real thing.
-- ===========================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Theme"))
local settings = UserSettings():GetService("UserGameSettings")

local player = Players.LocalPlayer
local SHOULDER = Vector3.new(1.75, 0, 0)

local gui = Instance.new("ScreenGui")
gui.Name = "ShiftLockUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "ShiftLock"
button.Size = UDim2.new(0, 128, 0, 40)
button.Position = UDim2.new(1, -146, 1, -172)
button.BackgroundColor3 = Theme.Control
button.TextColor3 = Theme.Ink
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.Text = "SHIFT LOCK"
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button

local locked = false

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function apply()
	settings.RotationType = locked
		and Enum.RotationType.CameraRelative
		or Enum.RotationType.MovementRelative

	local human = humanoid()
	if human then
		human.CameraOffset = locked and SHOULDER or Vector3.zero
	end

	button.BackgroundColor3 = locked and Theme.Ready or Theme.Control
	button.TextColor3 = locked and Theme.ReadyInk or Theme.Ink
	button.Text = locked and "SHIFT LOCK ON" or "SHIFT LOCK"
end

local function toggle()
	locked = not locked
	apply()
end

button.MouseButton1Click:Connect(toggle)

-- the same key Roblox uses, so muscle memory carries over
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		toggle()
	end
end)

-- a fresh character loses the camera offset, so put it back
player.CharacterAdded:Connect(function()
	task.wait(0.4)
	apply()
end)

apply()
