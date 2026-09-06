--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the obbies
--
--  Five graded courses on walkways reaching out through gates
--  in the boundary wall, from Beginner at 5 coins to
--  Impossible at 50.
--
--  Layouts are fixed rather than random. These are difficulty
--  tiers, so learning the route is the point -- a course that
--  reshuffled would make Impossible a lottery rather than a
--  skill.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObbyConfig  = require(ReplicatedStorage:WaitForChild("ObbyConfig"))
local StageConfig = require(ReplicatedStorage:WaitForChild("StageConfig"))

local COURSE   = ObbyConfig.Course
local RECOVERY = ObbyConfig.Recovery
local ORIGIN   = COURSE.Origin

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "ObbyRemotes"

local rewarded = Instance.new("RemoteEvent")
rewarded.Name = "Rewarded"
rewarded.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Building one course
-- ===========================================================

local courses = Instance.new("Folder")
courses.Name = "Obbies"

type Built = { tier: any, entry: Vector3, finish: Part }
local built: { Built } = {}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame,
	colour: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function signOn(part: Part, text: string, colour: Color3)
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(12, 3)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	sign.MaxDistance = 320
	sign.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = sign
end

local function buildCourse(tier): Built?
	local angleDeg = StageConfig.Gates.Angles[tier.gate]
	if not angleDeg then
		warn(("Obby %s has no gate %d"):format(tier.name, tier.gate))
		return nil
	end

	local angle = math.rad(angleDeg)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local side = Vector3.new(-math.sin(angle), 0, math.cos(angle))

	local folder = Instance.new("Folder")
	folder.Name = tier.key

	-- walkway from the arena floor, through the gate, to the start
	local bridgeLength = COURSE.StartRadius - COURSE.BridgeFrom
	local bridgeCentre = ORIGIN + out * (COURSE.BridgeFrom + bridgeLength / 2)
	makePart(folder, "Bridge",
		Vector3.new(COURSE.BridgeWidth, 1, bridgeLength),
		CFrame.lookAt(bridgeCentre, bridgeCentre + out),
		ObbyConfig.Palette.Bridge, Enum.Material.SmoothPlastic)

	local entryPosition = ORIGIN + out * COURSE.StartRadius
	local entry = makePart(folder, "Entry",
		Vector3.new(14, 1, 14),
		CFrame.new(entryPosition),
		tier.colour, Enum.Material.Neon)
	signOn(entry, ("%s  %d COINS"):format(tier.name, tier.reward), tier.colour)

	-- Each step is placed exactly platform+gap away from the last, so
	-- the gap is the number in the config rather than whatever the
	-- geometry happened to produce.
	local spacing = tier.platform + tier.gap
	local previous = entryPosition
	local finish: Part? = nil

	for i = 1, tier.steps do
		local swingNow  = math.sin(i * 0.9) * COURSE.LateralSwing
		local swingLast = math.sin((i - 1) * 0.9) * COURSE.LateralSwing

		local heading = (out + side * ((swingNow - swingLast) / spacing)).Unit
		local position = previous + heading * spacing + Vector3.new(0, tier.rise, 0)

		local isFinish = i == tier.steps
		local size = isFinish
			and Vector3.new(tier.platform + 4, 1, tier.platform + 4)
			or Vector3.new(tier.platform, 1, tier.platform)

		local part = makePart(folder,
			isFinish and "Finish" or "Step",
			size, CFrame.new(position),
			isFinish and ObbyConfig.Palette.Finish
				or ((i % 2 == 0) and tier.colour or tier.colour:Lerp(Color3.new(1, 1, 1), 0.45)),
			isFinish and Enum.Material.Neon or Enum.Material.SmoothPlastic)

		if isFinish then
			signOn(part, ("+%d COINS"):format(tier.reward), ObbyConfig.Palette.Finish)
			finish = part
		end
		previous = position
	end

	folder.Parent = courses
	if not finish then
		return nil
	end

	return { tier = tier, entry = entryPosition, finish = finish }
end

for _, tier in ipairs(ObbyConfig.Tiers) do
	local course = buildCourse(tier)
	if course then
		table.insert(built, course)
	end
end

courses.Parent = workspace

do
	local names = {}
	for _, course in ipairs(built) do
		table.insert(names, ("%s(%d)"):format(course.tier.name, course.tier.reward))
	end
	print(("Obbies built: %s"):format(table.concat(names, " ")))
end

-- ===========================================================
--  Rewarding
-- ===========================================================

local lastClaim: { [Player]: { [string]: number } } = {}

local function award(player: Player, tier)
	local perPlayer = lastClaim[player]
	if not perPlayer then
		perPlayer = {}
		lastClaim[player] = perPlayer
	end

	local now = os.clock()
	if perPlayer[tier.key] and now - perPlayer[tier.key] < COURSE.ClaimCooldown then
		return   -- otherwise the finish pad is a coin printer
	end
	perPlayer[tier.key] = now

	local multiplier = workspace:GetAttribute("CoinMultiplier")
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		multiplier = 1
	end
	local payout = math.floor(tier.reward * multiplier)

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += payout
	end

	rewarded:FireClient(player, tier.name, payout)
	print(("%s cleared %s: +%d coins"):format(player.Name, tier.name, payout))
end

for _, course in ipairs(built) do
	course.finish.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			award(player, course.tier)
		end
	end)
end

-- ===========================================================
--  Catching fallers
--
--  Out here there is no floor below, and the arena's own check
--  would drop you all the way back to the spawn ring. Catch
--  them higher up and put them at the entry of whichever
--  course they fell off.
-- ===========================================================

local function nearestEntry(position: Vector3): Vector3?
	local best, bestDistance = nil, math.huge
	for _, course in ipairs(built) do
		local flat = Vector3.new(
			position.X - course.entry.X, 0, position.Z - course.entry.Z
		).Magnitude
		if flat < bestDistance then
			best, bestDistance = course.entry, flat
		end
	end
	return best
end

task.spawn(function()
	local floorY = ORIGIN.Y - RECOVERY.DropBelow

	while true do
		task.wait(RECOVERY.CheckRate)

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end

			local position = root.Position
			if position.Y >= floorY then
				continue
			end

			local radius = Vector3.new(position.X - ORIGIN.X, 0, position.Z - ORIGIN.Z).Magnitude
			if radius < RECOVERY.BeyondRadius then
				continue   -- inside the walls; the arena handles that
			end

			local entry = nearestEntry(position)
			if entry then
				character:PivotTo(CFrame.new(entry + Vector3.new(0, 4, 0)))
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastClaim[player] = nil
end)
