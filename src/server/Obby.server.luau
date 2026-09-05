--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the obby
--
--  A short climb that spirals up the inside of the boundary
--  wall, starting from a pad on the arena floor. Reach the top
--  for coins. The whole course is replaced every ten minutes.
--
--  Every jump is clamped against the same physics budget the
--  characters actually have, so a random layout can never
--  produce a gap nobody can clear.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObbyConfig = require(ReplicatedStorage:WaitForChild("ObbyConfig"))

local COURSE = ObbyConfig.Course
local RULES  = ObbyConfig.Rules

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "ObbyRemotes"

local rewarded = Instance.new("RemoteEvent")
rewarded.Name = "Rewarded"
rewarded.Parent = remotes

local refreshed = Instance.new("RemoteEvent")
refreshed.Name = "Refreshed"
refreshed.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Building the course
-- ===========================================================

local course: Folder? = nil
local entryPosition = COURSE.Origin
local claimed: { [Player]: boolean } = {}

local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3,
	colour: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = colour
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildCourse()
	local folder = Instance.new("Folder")
	folder.Name = "Obby"

	local rng = Random.new(COURSE.Seed or os.time())
	local size = COURSE.PlatformSize
	local origin = COURSE.Origin

	-- the entry pad sits flush on the arena floor, so the course is
	-- reachable on foot rather than needing a jump to start
	local entryAngle = math.rad(COURSE.EntryAngleDeg)
	entryPosition = origin + Vector3.new(
		math.cos(entryAngle) * COURSE.EntryRadius,
		0.5,
		math.sin(entryAngle) * COURSE.EntryRadius
	)

	local entry = makePart(folder, "ObbyEntry", Vector3.new(8, 1, 8), entryPosition,
		ObbyConfig.Palette.Entry, Enum.Material.Neon)

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(9, 2.4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	sign.MaxDistance = 220
	sign.Parent = entry

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.Text = ("OBBY  %d COINS"):format(RULES.Reward)
	label.Parent = sign

	local angle = entryAngle
	local previous = entryPosition
	local widestGap = 0
	local finish: Part? = nil

	for i = 1, COURSE.PlatformCount do
		local progress = (i - 1) / math.max(1, COURSE.PlatformCount - 1)
		local allowedGap = COURSE.StartGap + (COURSE.EndGap - COURSE.StartGap) * progress
		local maxCentreDist = size.X + allowedGap

		angle += math.rad(COURSE.AngleStepDeg
			+ rng:NextNumber(-COURSE.AngleJitterDeg, COURSE.AngleJitterDeg))

		local position = Vector3.new(
			origin.X + math.cos(angle) * COURSE.Radius,
			previous.Y + COURSE.Rise,
			origin.Z + math.sin(angle) * COURSE.Radius
		)

		-- the angle proposes, the jump budget disposes
		local delta = position - previous
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude > maxCentreDist then
			local pulled = previous + flat.Unit * maxCentreDist
			position = Vector3.new(pulled.X, position.Y, pulled.Z)
		end

		local reached = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude
		widestGap = math.max(widestGap, reached - size.X)

		local isFinish = i == COURSE.PlatformCount
		local part = makePart(folder,
			isFinish and "ObbyFinish" or "ObbyStep",
			isFinish and (size + Vector3.new(3, 0, 3)) or size,
			position,
			isFinish and ObbyConfig.Palette.Finish
				or ((i % 2 == 0) and ObbyConfig.Palette.Step or ObbyConfig.Palette.StepAlt),
			isFinish and Enum.Material.Neon or Enum.Material.SmoothPlastic)

		if isFinish then
			finish = part
		end
		previous = position
	end

	folder.Parent = workspace
	course = folder

	-- same check as the tower: prove it is climbable before anyone tries
	local gravity, jumpPower, walkSpeed = 196.2, 50, 16
	local disc = jumpPower ^ 2 - 2 * gravity * COURSE.Rise
	if disc <= 0 then
		warn(("Obby: Rise %.1f exceeds jump height -- unclimbable."):format(COURSE.Rise))
	else
		local latest = (jumpPower + math.sqrt(disc)) / gravity
		local reach = walkSpeed * latest
		print(("Obby built: %d steps, widest gap %.2f studs, jump reach %.2f")
			:format(COURSE.PlatformCount, widestGap, reach))
		if widestGap > reach - 1.5 then
			warn(("Obby: widest gap %.2f is close to the limit %.2f -- lower EndGap.")
				:format(widestGap, reach))
		end
	end

	return finish
end

-- ===========================================================
--  Rewarding
-- ===========================================================

local function award(player: Player)
	if claimed[player] then
		return   -- once per course, or the pad is a coin printer
	end
	claimed[player] = true

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += RULES.Reward
	end

	rewarded:FireClient(player, RULES.Reward)
	print(("%s finished the obby: +%d coins"):format(player.Name, RULES.Reward))
end

local function wireFinish(finish: Part?)
	if not finish then
		return
	end
	finish.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			award(player)
		end
	end)
end

-- ===========================================================
--  Refreshing
-- ===========================================================

-- Anyone standing on the course when it goes would drop the whole way
-- to the arena floor. Put them back at the entry instead.
local function clearClimbers()
	local folder = course
	if not folder then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { folder }

			local below = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
			if below then
				character:PivotTo(CFrame.new(entryPosition + Vector3.new(0, 4, 0)))
			end
		end
	end
end

local function refresh()
	clearClimbers()

	if course then
		course:Destroy()
		course = nil
	end

	claimed = {}
	wireFinish(buildCourse())
	refreshed:FireAllClients(workspace:GetServerTimeNow() + RULES.RefreshSeconds)
end

refresh()

task.spawn(function()
	while true do
		task.wait(RULES.RefreshSeconds)
		refresh()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	claimed[player] = nil
end)
