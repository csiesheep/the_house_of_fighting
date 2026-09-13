--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- driving
--
--  Runs only while you are in a car's DriveSeat. The server
--  gave you network ownership of the car, so the values set
--  here are the ones the physics actually simulates, and
--  everyone else sees the result replicated.
--
--  Input comes from the VehicleSeat itself, which already maps
--  WASD, arrow keys, gamepads and the phone thumbstick into
--  ThrottleFloat and SteerFloat. Nothing here reads a key.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local CityConfig = require(ReplicatedStorage:WaitForChild("CityConfig"))
local Theme      = require(ReplicatedStorage:WaitForChild("Theme"))

local DRIVE = CityConfig.Driving
local player = Players.LocalPlayer

-- -----------------------------------------------------------
--  Hint
-- -----------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "DrivingUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 340, 0, 34)
hint.Position = UDim2.new(0.5, -170, 1, -96)
hint.BackgroundColor3 = Theme.Panel
hint.BackgroundTransparency = 0.15
hint.TextColor3 = Theme.Ink
hint.Font = Enum.Font.GothamBold
hint.TextSize = 14
hint.Visible = false
hint.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hint

-- Shown when you try a car without the licence. The purchase prompt
-- comes from the server; this says why it appeared, or that the pass
-- is not on sale yet if it has not been created.
local notice = Instance.new("TextLabel")
notice.Size = UDim2.new(0, 360, 0, 40)
notice.Position = UDim2.new(0.5, -180, 0.62, 0)
notice.BackgroundColor3 = Theme.Accent
notice.TextColor3 = Theme.AccentInk
notice.Font = Enum.Font.GothamBold
notice.TextSize = 15
notice.Visible = false
notice.Parent = gui

local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 10)
noticeCorner.Parent = notice

local noticeToken = 0
local remotes = ReplicatedStorage:WaitForChild("VehicleRemotes")
local needLicence = remotes:WaitForChild("NeedLicence")

needLicence.OnClientEvent:Connect(function(price: number)
	noticeToken += 1
	local mine = noticeToken
	notice.Text = ("You need a Driver's Licence  (R$ %d)  -- see the SHOP"):format(price)
	notice.Visible = true
	task.delay(3, function()
		if noticeToken == mine then
			notice.Visible = false
		end
	end)
end)

-- -----------------------------------------------------------
--  E gets you out
--
--  The same key that got you in. Space still works too, since
--  that is Roblox's own way out of any seat.
--
--  Deliberately not gated on the "processed" flag: when another
--  car is parked beside you its Drive prompt claims E, and you
--  would be stuck in the seat until you drove away from it.
--  A focused chat box is the one case that should swallow it.
-- -----------------------------------------------------------

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriveSeat" then
		humanoid.Jump = true
	end
end)

-- -----------------------------------------------------------
--  The loop
-- -----------------------------------------------------------

local speed = 0
local currentSeat: VehicleSeat? = nil

local function approach(value: number, target: number, step: number): number
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

RunService.Heartbeat:Connect(function(delta)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart

	if not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriveSeat") then
		currentSeat = nil
		speed = 0
		hint.Visible = false
		return
	end

	local model = seat.Parent
	local body = model and model:IsA("Model") and model.PrimaryPart
	local linear = body and body:FindFirstChild("DriveVelocity")
	local angular = body and body:FindFirstChild("DriveTurn")
	if not (body and linear and linear:IsA("LinearVelocity")
		and angular and angular:IsA("AngularVelocity")) then
		return
	end

	local forward = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		return
	end
	forward = forward.Unit

	-- climbing into a car that is already rolling picks up where it is
	-- rather than slamming to zero
	if seat ~= currentSeat then
		currentSeat = seat
		speed = forward:Dot(body.AssemblyLinearVelocity)
	end

	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat

	local target = throttle >= 0 and throttle * DRIVE.MaxSpeed or throttle * DRIVE.ReverseSpeed

	-- speeding up is slower than stopping, which is what makes letting
	-- go of W feel like braking rather than coasting forever
	local speedingUp = math.abs(target) > math.abs(speed) and (target * speed >= 0)
	local rate = speedingUp and DRIVE.Accel or DRIVE.Brake
	speed = approach(speed, target, rate * delta)

	linear.VectorVelocity = forward * speed

	-- no steering from standstill, and reversing steers the way a
	-- real car does rather than mirrored
	local grip = math.clamp(math.abs(speed) / DRIVE.TurnFullAt, 0, 1)
	local direction = speed >= 0 and 1 or -1
	angular.AngularVelocity = Vector3.new(0, -steer * DRIVE.TurnRate * grip * direction, 0)

	hint.Visible = true
	hint.Text = ("%d mph   W/S drive  A/D steer  E to get out")
		:format(math.floor(math.abs(speed) * 0.6))
end)
