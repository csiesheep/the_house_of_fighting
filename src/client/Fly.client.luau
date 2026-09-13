--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- fly
--
--  Ctrl+F on Windows, Cmd+F on a Mac. Only offered to players
--  the server has marked CanFly.
--
--  While flying you move the way the camera points: W flies
--  where you are looking, so looking up and pressing W climbs.
--  Space goes straight up, Left Ctrl straight down. Walls and
--  floors do not stop you.
--
--  Movement is simulated on your own client, which owns your
--  character, so this is smooth for you and replicated to
--  everyone else like normal walking.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local Staff = require(ReplicatedStorage:WaitForChild("Staff"))
local Theme = require(ReplicatedStorage:WaitForChild("Theme"))

local FLY = Staff.Fly
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- -----------------------------------------------------------
--  Indicator
-- -----------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "FlyUi"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local badge = Instance.new("TextLabel")
badge.Size = UDim2.new(0, 300, 0, 30)
badge.Position = UDim2.new(0.5, -150, 0, 14)
badge.BackgroundColor3 = Color3.fromRGB(40, 36, 60)
badge.BackgroundTransparency = 0.1
badge.TextColor3 = Color3.fromRGB(190, 176, 255)
badge.Font = Enum.Font.GothamBold
badge.TextSize = 13
badge.Text = "FLYING   Space up  Ctrl down  Ctrl+F to stop"
badge.Visible = false
badge.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = badge

-- -----------------------------------------------------------
--  State
-- -----------------------------------------------------------

local flying = false
local attachment: Attachment? = nil
local velocity: LinearVelocity? = nil
local facing: AlignOrientation? = nil
local savedCollide: { [BasePart]: boolean } = {}

local function parts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and not root:IsA("BasePart") then
		root = nil
	end
	return character, humanoid, root :: BasePart?
end

local function stop()
	flying = false
	badge.Visible = false

	if velocity then velocity:Destroy() end
	if facing then facing:Destroy() end
	if attachment then attachment:Destroy() end
	velocity, facing, attachment = nil, nil, nil

	local _, humanoid = parts()
	if humanoid then
		humanoid.PlatformStand = false
	end

	-- put collisions back exactly as they were, rather than switching
	-- everything on: the root part and accessories start out off
	for part, collide in pairs(savedCollide) do
		if part.Parent then
			part.CanCollide = collide
		end
	end
	table.clear(savedCollide)
end

local function start()
	local character, humanoid, root = parts()
	if not (character and humanoid and root and humanoid.Health > 0) then
		return
	end
	if humanoid.SeatPart then
		return   -- get out of the car first
	end

	flying = true
	badge.Visible = true

	-- PlatformStand stops the humanoid trying to walk and animate
	-- against the forces below
	humanoid.PlatformStand = true

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			savedCollide[part] = part.CanCollide
		end
	end

	local a = Instance.new("Attachment")
	a.Name = "FlyAttachment"
	a.Parent = root
	attachment = a

	local v = Instance.new("LinearVelocity")
	v.Name = "FlyVelocity"
	v.Attachment0 = a
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.MaxForce = FLY.Force
	v.VectorVelocity = Vector3.zero
	v.Parent = root
	velocity = v

	local o = Instance.new("AlignOrientation")
	o.Name = "FlyFacing"
	o.Attachment0 = a
	o.Mode = Enum.OrientationAlignmentMode.OneAttachment
	o.MaxTorque = FLY.Force
	o.Responsiveness = FLY.Responsiveness
	o.CFrame = root.CFrame
	o.Parent = root
	facing = o
end

-- -----------------------------------------------------------
--  Toggle: Ctrl+F or Cmd+F
-- -----------------------------------------------------------

local function modifierHeld(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftSuper)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightSuper)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
end

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.F or not modifierHeld() then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return   -- typing in chat
	end
	if player:GetAttribute("CanFly") ~= true then
		return
	end

	if flying then
		stop()
	else
		start()
	end
end)

-- -----------------------------------------------------------
--  Flying
-- -----------------------------------------------------------

-- Collisions switched off before physics runs each step. Doing it
-- once is not enough: Roblox turns character collisions back on as
-- the humanoid changes state.
RunService.Stepped:Connect(function()
	if not flying then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if not flying then
		return
	end

	local _, humanoid, root = parts()
	if not (humanoid and root and humanoid.Health > 0 and velocity and facing) then
		stop()
		return
	end
	if humanoid.SeatPart then
		stop()
		return
	end

	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local move = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end

	-- phones: the thumbstick still drives the humanoid's MoveDirection
	if move.Magnitude < 0.01 and humanoid.MoveDirection.Magnitude > 0.01 then
		move = humanoid.MoveDirection
	end

	velocity.VectorVelocity = move.Magnitude > 0.01 and move.Unit * FLY.Speed or Vector3.zero

	-- face where the camera faces, kept upright
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		facing.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end)

player.CharacterAdded:Connect(function()
	-- a new body has none of the old forces; just clear the state
	flying = false
	badge.Visible = false
	velocity, facing, attachment = nil, nil, nil
	table.clear(savedCollide)
end)
