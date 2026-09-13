--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- fly
--
--  Ctrl+F on Windows, Cmd+F on a Mac, the FLY button, or typing
--  /fly in chat. Only offered to players the server has marked
--  CanFly.
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
local TextChatService   = game:GetService("TextChatService")

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
badge.Text = "FLYING   Space up  Ctrl down  /fly to stop"
badge.Visible = false
badge.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = badge

-- -----------------------------------------------------------
--  Buttons
--
--  FLY sits above the other right-hand buttons and only exists
--  for players allowed to fly. UP and DOWN appear while flying,
--  because a phone has no Space or Ctrl and its thumbstick only
--  moves you sideways.
-- -----------------------------------------------------------

local function makeButton(name: string, text: string, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(88, 72, 168)
	button.TextColor3 = Color3.fromRGB(246, 244, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = text
	button.Visible = false
	button.Parent = gui

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 10)
	round.Parent = button
	return button
end

local flyButton = makeButton("FlyButton", "FLY",
	UDim2.new(1, -146, 1, -280), UDim2.new(0, 128, 0, 40))
local upButton = makeButton("FlyUp", "UP",
	UDim2.new(1, -212, 1, -280), UDim2.new(0, 58, 0, 40))
local downButton = makeButton("FlyDown", "DOWN",
	UDim2.new(1, -212, 1, -234), UDim2.new(0, 58, 0, 40))

local upHeld, downHeld = false, false

for _, pair in ipairs({ { upButton, true }, { downButton, false } }) do
	local button, isUp = pair[1], pair[2]
	button.MouseButton1Down:Connect(function()
		if isUp then upHeld = true else downHeld = true end
	end)
	button.MouseButton1Up:Connect(function()
		if isUp then upHeld = false else downHeld = false end
	end)
	-- a finger sliding off the button never sends the Up event
	button.MouseLeave:Connect(function()
		if isUp then upHeld = false else downHeld = false end
	end)
end

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

local function showState()
	local allowed = player:GetAttribute("CanFly") == true
	flyButton.Visible = allowed
	flyButton.Text = flying and "STOP FLYING" or "FLY"
	flyButton.BackgroundColor3 = flying and Color3.fromRGB(196, 84, 110)
		or Color3.fromRGB(88, 72, 168)
	upButton.Visible = allowed and flying
	downButton.Visible = allowed and flying
	if not flying then
		upHeld, downHeld = false, false
	end
end

local function stop()
	flying = false
	badge.Visible = false
	showState()

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
	showState()

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

local function toggle()
	if player:GetAttribute("CanFly") ~= true then
		return
	end
	if flying then
		stop()
	else
		start()
	end
end

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.F or not modifierHeld() then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return   -- typing in chat
	end
	toggle()
end)

flyButton.MouseButton1Click:Connect(function()
	toggle()
end)

player:GetAttributeChangedSignal("CanFly"):Connect(showState)
showState()

-- -----------------------------------------------------------
--  /fly in chat
--
--  Registered both ways, because a place can be on either chat
--  system: a TextChatCommand for the current TextChatService,
--  and Player.Chatted for legacy chat. The command form also
--  keeps "/fly" out of everyone else's chat window.
--
--  If a message ever reaches both, a short debounce stops the
--  second one switching flying straight back off.
-- -----------------------------------------------------------

local lastChatToggle = 0

local function chatToggle()
	local now = os.clock()
	if now - lastChatToggle < 0.4 then
		return
	end
	lastChatToggle = now
	toggle()
end

task.spawn(function()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	local commands = TextChatService:WaitForChild("TextChatCommands", 10)
	if not commands then
		return
	end

	local command = Instance.new("TextChatCommand")
	command.Name = "FlyCommand"
	command.PrimaryAlias = "/fly"
	command.Triggered:Connect(function()
		chatToggle()
	end)
	command.Parent = commands
end)

player.Chatted:Connect(function(message)
	local text = string.lower((string.gsub(message, "^%s+", ""):gsub("%s+$", "")))
	if text == "/fly" then
		chatToggle()
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
	if upHeld then move += Vector3.yAxis end
	if downHeld then move -= Vector3.yAxis end

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
	showState()
end)
