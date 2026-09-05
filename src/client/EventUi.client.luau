--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the spin
--
--  The server picks the winner and sends its index. All the
--  drama is here: names flicker past and slow to a stop on the
--  one that was already chosen. Nothing the animation does can
--  change the outcome, which is why it can be as loose as it
--  likes.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local EventConfig = require(ReplicatedStorage:WaitForChild("EventConfig"))
local Theme       = require(ReplicatedStorage:WaitForChild("Theme"))

local remotes     = ReplicatedStorage:WaitForChild("EventRemotes")
local spinStarted = remotes:WaitForChild("SpinStarted")
local eventEnded  = remotes:WaitForChild("EventEnded")
local nextSpin    = remotes:WaitForChild("NextSpin")

local EFFECTS = EventConfig.Effects
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "EventUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- -----------------------------------------------------------
--  The spin panel
-- -----------------------------------------------------------

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 460, 0, 168)
panel.Position = UDim2.new(0.5, -230, 0.26, 0)
panel.BackgroundColor3 = Theme.Panel
panel.Visible = false
panel.Parent = gui
round(panel, 16)

local heading = Instance.new("TextLabel")
heading.Size = UDim2.new(1, 0, 0, 22)
heading.Position = UDim2.new(0, 0, 0, 14)
heading.BackgroundTransparency = 1
heading.TextColor3 = Theme.Muted
heading.Font = Enum.Font.GothamBold
heading.TextSize = 13
heading.Text = "HOURLY SPIN"
heading.Parent = panel

local reel = Instance.new("TextLabel")
reel.Size = UDim2.new(1, -24, 0, 56)
reel.Position = UDim2.new(0, 12, 0, 42)
reel.BackgroundTransparency = 1
reel.TextColor3 = Theme.Ink
reel.Font = Enum.Font.GothamBlack
reel.TextScaled = true
reel.Text = "..."
reel.Parent = panel

local blurb = Instance.new("TextLabel")
blurb.Size = UDim2.new(1, -32, 0, 34)
blurb.Position = UDim2.new(0, 16, 0, 102)
blurb.BackgroundTransparency = 1
blurb.TextColor3 = Theme.Muted
blurb.Font = Enum.Font.Gotham
blurb.TextSize = 14
blurb.TextWrapped = true
blurb.Text = ""
blurb.Parent = panel

local underline = Instance.new("Frame")
underline.Size = UDim2.new(0, 0, 0, 4)
underline.Position = UDim2.new(0.5, 0, 0, 96)
underline.BorderSizePixel = 0
underline.BackgroundColor3 = Theme.Accent
underline.Parent = panel

-- -----------------------------------------------------------
--  Status pill, under the stats card
-- -----------------------------------------------------------

local pill = Instance.new("TextLabel")
pill.Size = UDim2.new(0, 168, 0, 28)
pill.Position = UDim2.new(0, 14, 0, 114)
pill.BackgroundColor3 = Theme.Panel
pill.BackgroundTransparency = 0.18
pill.TextColor3 = Theme.Muted
pill.Font = Enum.Font.GothamMedium
pill.TextSize = 12
pill.Text = ""
pill.Visible = false
pill.Parent = gui
round(pill, 8)

local activeUntil = 0
local activeIndex = 0
local nextAt = 0

local function clock(seconds: number): string
	seconds = math.max(0, seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()

	if activeUntil > now then
		local effect = EFFECTS[activeIndex]
		pill.Visible = true
		pill.TextColor3 = effect and effect.colour or Theme.Ink
		pill.Text = ("  %s  %s"):format(effect and effect.name or "EVENT", clock(activeUntil - now))
	elseif nextAt > now then
		pill.Visible = true
		pill.TextColor3 = Theme.Muted
		pill.Text = ("  next spin  %s"):format(clock(nextAt - now))
	else
		pill.Visible = false
	end
end)

-- -----------------------------------------------------------
--  The animation
-- -----------------------------------------------------------

local spinning = false

local function runSpin(index: number, endsAt: number)
	if spinning then
		return
	end
	spinning = true

	local winner = EFFECTS[index]
	if not winner then
		spinning = false
		return
	end

	panel.Visible = true
	blurb.Text = ""
	underline.Size = UDim2.new(0, 0, 0, 4)
	underline.BackgroundColor3 = winner.colour

	-- flick through the names, slowing down, landing on the winner.
	-- ending on `index` is arithmetic, not luck: we walk backwards
	-- from it so the last step is always the right one.
	local steps = 26
	local cursor = index - steps
	local delay = 0.03

	for step = 1, steps do
		cursor += 1
		local shown = EFFECTS[((cursor - 1) % #EFFECTS) + 1]
		reel.Text = shown.name
		reel.TextColor3 = shown.colour
		task.wait(delay)
		delay = delay * 1.14      -- decelerate
	end

	reel.Text = winner.name
	reel.TextColor3 = winner.colour
	blurb.Text = winner.blurb

	TweenService:Create(underline, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.new(0, 220, 0, 4),
		Position = UDim2.new(0.5, -110, 0, 96),
	}):Play()

	activeIndex = index
	activeUntil = endsAt

	task.wait(3.5)
	local fade = TweenInfo.new(0.6)
	TweenService:Create(panel, fade, { BackgroundTransparency = 1 }):Play()
	for _, child in ipairs(panel:GetDescendants()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, fade, { TextTransparency = 1 }):Play()
		elseif child:IsA("Frame") then
			TweenService:Create(child, fade, { BackgroundTransparency = 1 }):Play()
		end
	end
	task.wait(0.7)

	panel.Visible = false
	panel.BackgroundTransparency = 0
	for _, child in ipairs(panel:GetDescendants()) do
		if child:IsA("TextLabel") then
			child.TextTransparency = 0
		elseif child:IsA("Frame") then
			child.BackgroundTransparency = 0
		end
	end

	spinning = false
end

spinStarted.OnClientEvent:Connect(function(index: number, endsAt: number)
	-- a late joiner gets the tail of a running event, not the drama
	if endsAt - workspace:GetServerTimeNow() < EventConfig.Timing.DurationSeconds - 8 then
		activeIndex = index
		activeUntil = endsAt
		return
	end
	task.spawn(runSpin, index, endsAt)
end)

eventEnded.OnClientEvent:Connect(function()
	activeUntil = 0
	activeIndex = 0
end)

nextSpin.OnClientEvent:Connect(function(stamp: number)
	nextAt = stamp
end)
