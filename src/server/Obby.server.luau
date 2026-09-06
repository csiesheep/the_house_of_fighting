--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the obbies
--
--  Five graded courses on walkways reaching out through gates
--  in the boundary wall, from Beginner at 5 coins to
--  Impossible at 50.
--
--  A course is built segment by segment from a weighted bag of
--  obstacle types. A cursor walks outward and upward; each
--  segment builds whatever it likes and hands back where the
--  next one starts. Adding an obstacle means adding one
--  builder, not touching the generator.
--
--  Layouts are seeded per tier, so they are fixed. These are
--  skill tiers -- learning the route is the point, and a
--  course that reshuffled would make Impossible a lottery.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local ObbyConfig  = require(ReplicatedStorage:WaitForChild("ObbyConfig"))
local StageConfig = require(ReplicatedStorage:WaitForChild("StageConfig"))

local COURSE    = ObbyConfig.Course
local RECOVERY  = ObbyConfig.Recovery
local OBSTACLES = ObbyConfig.Obstacles
local ORIGIN    = COURSE.Origin

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "ObbyRemotes"

local rewarded = Instance.new("RemoteEvent")
rewarded.Name = "Rewarded"
rewarded.Parent = remotes

local checkpointHit = Instance.new("RemoteEvent")
checkpointHit.Name = "CheckpointHit"
checkpointHit.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Shared bits
-- ===========================================================

local courses = Instance.new("Folder")
courses.Name = "Obbies"

type Course = {
	tier: any,
	entry: Vector3,
	finish: Part,
	checkpoints: { Vector3 },
}

local built: { Course } = {}

-- everything that needs a heartbeat, in one list and one loop
type Dynamic = { kind: string, part: Part, [string]: any }
local dynamics: { Dynamic } = {}

local lavaParts: { [BasePart]: boolean } = {}

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

local function signOn(part: Part, text: string, colour: Color3, size: number)
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(size, size / 4)
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

-- ===========================================================
--  Segment builders
--
--  Each takes the context and returns the position the next
--  segment should start from. `ctx.heading` already weaves,
--  so a builder only decides distance and what fills it.
-- ===========================================================

type Context = {
	folder: Folder,
	tier: any,
	rng: Random,
	cursor: Vector3,
	heading: Vector3,
	side: Vector3,
	index: number,
}

local function platformColour(ctx: Context): Color3
	return (ctx.index % 2 == 0) and ctx.tier.colour
		or ctx.tier.colour:Lerp(Color3.new(1, 1, 1), 0.45)
end

local function squareAt(ctx: Context, position: Vector3, scale: number?): Part
	local size = ctx.tier.platform * (scale or 1)
	return makePart(ctx.folder, "Step", Vector3.new(size, 1, size),
		CFrame.new(position), platformColour(ctx), Enum.Material.SmoothPlastic)
end

-- the plain gap the whole thing is measured against
local function segJump(ctx: Context): Vector3
	local spacing = ctx.tier.platform + ctx.tier.gap
	local position = ctx.cursor + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)
	squareAt(ctx, position)
	return position
end

-- a narrow plank: no jump at all, just somewhere to fall off
local function segBeam(ctx: Context): Vector3
	local spec = OBSTACLES.Beam
	local spacing = ctx.tier.platform + ctx.tier.gap
	local length = spacing * spec.LengthFactor

	local start = ctx.cursor + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)
	local centre = start + ctx.heading * (length / 2 - ctx.tier.platform / 2)

	local plank = makePart(ctx.folder, "Beam",
		Vector3.new(spec.Width, 1, length),
		CFrame.lookAt(centre, centre + ctx.heading),
		platformColour(ctx), Enum.Material.WoodPlanks)
	plank.TopSurface = Enum.SurfaceType.Smooth

	return start + ctx.heading * (length - ctx.tier.platform)
end

-- the same jump as always, with a pool underneath that ends your run
local function segLava(ctx: Context): Vector3
	local spec = OBSTACLES.Lava
	local spacing = ctx.tier.platform + ctx.tier.gap
	local position = ctx.cursor + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)

	local midpoint = (ctx.cursor + position) / 2
	local pool = makePart(ctx.folder, "Lava",
		Vector3.new(ctx.tier.platform + spec.Overhang, 1.2, spacing + spec.Overhang),
		CFrame.lookAt(midpoint - Vector3.new(0, spec.Drop, 0),
			midpoint - Vector3.new(0, spec.Drop, 0) + ctx.heading),
		spec.Colour, Enum.Material.Neon)
	pool.CanCollide = false
	lavaParts[pool] = true

	local glow = Instance.new("PointLight")
	glow.Color = spec.Colour
	glow.Range = 22
	glow.Brightness = 2
	glow.Parent = pool

	squareAt(ctx, position)
	return position
end

-- a platform sliding side to side. Unanchored and driven by an
-- AlignPosition, because an anchored part moved by CFrame slides out
-- from under whoever is standing on it instead of carrying them.
local function segMover(ctx: Context): Vector3
	local spec = OBSTACLES.Mover
	local spacing = ctx.tier.platform + ctx.tier.gap
	local centre = ctx.cursor + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)

	local size = ctx.tier.platform + 1
	local pad = makePart(ctx.folder, "Mover", Vector3.new(size, 1, size),
		CFrame.new(centre), ctx.tier.colour:Lerp(Color3.new(1, 1, 1), 0.2),
		Enum.Material.Metal)
	pad.Anchored = false
	pad.CanCollide = true

	local attachment = Instance.new("Attachment")
	attachment.Parent = pad

	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Position = centre
	align.MaxForce = 1e7
	align.Responsiveness = spec.Responsiveness
	align.Parent = pad

	local hold = Instance.new("AlignOrientation")
	hold.Mode = Enum.OrientationAlignmentMode.OneAttachment
	hold.Attachment0 = attachment
	hold.CFrame = CFrame.new()
	hold.MaxTorque = 1e7
	hold.Responsiveness = spec.Responsiveness
	hold.Parent = pad

	table.insert(dynamics, {
		kind = "mover", part = pad, align = align,
		centre = centre, axis = ctx.side,
		travel = spec.Travel, period = spec.Period,
		phase = ctx.rng:NextNumber(0, math.pi * 2),
	})

	-- land beyond it rather than riding to the end
	local landing = centre + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)
	squareAt(ctx, landing)
	return landing
end

-- a wide platform with a bar sweeping across it
local function segSpinner(ctx: Context): Vector3
	local spec = OBSTACLES.Spinner
	local spacing = ctx.tier.platform + ctx.tier.gap
	local position = ctx.cursor + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)

	squareAt(ctx, position, 1.8)

	local bar = makePart(ctx.folder, "Spinner",
		Vector3.new(spec.Length, spec.Thickness, spec.Thickness),
		CFrame.new(position + Vector3.new(0, spec.Height, 0)),
		spec.Colour, Enum.Material.Neon)

	table.insert(dynamics, {
		kind = "spinner", part = bar,
		centre = position + Vector3.new(0, spec.Height, 0),
		speed = spec.Speed,
		phase = ctx.rng:NextNumber(0, math.pi * 2),
	})

	return position
end

-- platforms that blink out from under you, offset so they alternate
local function segFader(ctx: Context): Vector3
	local spec = OBSTACLES.Fader
	local spacing = ctx.tier.platform + ctx.tier.gap
	local position = ctx.cursor

	for i = 1, spec.Count do
		position = position + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)
		local pad = squareAt(ctx, position)
		pad.Name = "Fader"

		table.insert(dynamics, {
			kind = "fader", part = pad,
			onTime = spec.OnTime, offTime = spec.OffTime,
			phase = (i - 1) * spec.Stagger,
		})
	end

	return position
end

-- two walls with staggered ledges: zigzag up between them
local function segWallJump(ctx: Context): Vector3
	local spec = OBSTACLES.WallJump
	local spacing = ctx.tier.platform + ctx.tier.gap
	local base = ctx.cursor + ctx.heading * spacing + Vector3.new(0, ctx.tier.rise, 0)

	squareAt(ctx, base)

	local half = spec.Separation / 2
	local climb = spec.Rungs * spec.RungRise

	for _, sign in ipairs({ -1, 1 }) do
		local wallCentre = base + ctx.side * (sign * half)
			+ Vector3.new(0, spec.WallHeight / 2, 0)
		makePart(ctx.folder, "Wall",
			Vector3.new(spec.WallThickness, spec.WallHeight, ctx.tier.platform + 6),
			CFrame.lookAt(wallCentre, wallCentre + ctx.heading),
			ctx.tier.colour:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Concrete)
	end

	-- ledges alternate sides, each one a hop above the last
	for rung = 1, spec.Rungs do
		local sign = (rung % 2 == 0) and 1 or -1
		local ledgeCentre = base
			+ ctx.side * (sign * (half - spec.LedgeSize.X / 2 - 0.2))
			+ Vector3.new(0, rung * spec.RungRise, 0)

		makePart(ctx.folder, "Ledge", spec.LedgeSize,
			CFrame.lookAt(ledgeCentre, ledgeCentre + ctx.heading),
			ObbyConfig.Palette.Checkpoint, Enum.Material.Neon)
	end

	local top = base + Vector3.new(0, climb + spec.RungRise, 0) + ctx.heading * spacing
	squareAt(ctx, top)
	return top
end

local BUILDERS: { [string]: (Context) -> Vector3 } = {
	jump = segJump,
	beam = segBeam,
	lava = segLava,
	mover = segMover,
	spinner = segSpinner,
	fader = segFader,
	walljump = segWallJump,
}

-- ===========================================================
--  Assembling a course
-- ===========================================================

local function buildCourse(tier): Course?
	local gate = StageConfig.Gates[tier.gate]
	if not gate then
		warn(("Obby %s has no gate %d"):format(tier.name, tier.gate))
		return nil
	end

	-- the map is a rectangle now, so a gate is a point on an edge and
	-- the direction the course runs, not an angle around a circle
	local out = gate.out.Unit
	local side = Vector3.new(-out.Z, 0, out.X)

	local folder = Instance.new("Folder")
	folder.Name = tier.key

	-- walkway from the map edge, through the gate, out to the start
	local mouth = ORIGIN + gate.position
	local bridgeLength = COURSE.BridgeLength
	local bridgeCentre = mouth + out * (bridgeLength / 2 - COURSE.BridgeInset)
	makePart(folder, "Bridge",
		Vector3.new(COURSE.BridgeWidth, 1, bridgeLength),
		CFrame.lookAt(bridgeCentre, bridgeCentre + out),
		ObbyConfig.Palette.Bridge, Enum.Material.SmoothPlastic)

	local entryPosition = mouth + out * (bridgeLength - COURSE.BridgeInset)
	local entry = makePart(folder, "Entry", Vector3.new(14, 1, 14),
		CFrame.new(entryPosition), tier.colour, Enum.Material.Neon)
	signOn(entry, ("%s  %d COINS"):format(tier.name, tier.reward), tier.colour, 12)

	local rng = Random.new(tier.seed)
	local checkpoints: { Vector3 } = { entryPosition }
	local spacing = tier.platform + tier.gap

	local ctx: Context = {
		folder = folder, tier = tier, rng = rng,
		cursor = entryPosition, heading = out, side = side, index = 0,
	}

	local used: { [string]: number } = {}

	for i = 1, tier.segments do
		ctx.index = i

		-- weave the path so it is not a straight line out
		local swingNow  = math.sin(i * 0.8) * COURSE.LateralSwing
		local swingLast = math.sin((i - 1) * 0.8) * COURSE.LateralSwing
		ctx.heading = (out + side * ((swingNow - swingLast) / spacing)).Unit

		-- first and last segments are always plain, so a course never
		-- opens or closes on something you cannot see coming
		local kind = "jump"
		if i > 1 and i < tier.segments then
			kind = tier.types[rng:NextInteger(1, #tier.types)]
		end

		local builder = BUILDERS[kind] or segJump
		ctx.cursor = builder(ctx)
		used[kind] = (used[kind] or 0) + 1

		if i % tier.checkpointEvery == 0 and i < tier.segments then
			local pad = makePart(folder, "Checkpoint",
				Vector3.new(tier.platform + 3, 1, tier.platform + 3),
				CFrame.new(ctx.cursor + Vector3.new(0, 1, 0)),
				ObbyConfig.Palette.Checkpoint, Enum.Material.Neon)
			pad.CanCollide = false
			table.insert(checkpoints, ctx.cursor)

			local slot = #checkpoints
			pad.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				local hitPlayer = character and Players:GetPlayerFromCharacter(character)
				if hitPlayer then
					checkpointHit:FireClient(hitPlayer, tier.name, slot)
					hitPlayer:SetAttribute("Obby_" .. tier.key, slot)
				end
			end)
		end
	end

	local finish = makePart(folder, "Finish",
		Vector3.new(tier.platform + 6, 1, tier.platform + 6),
		CFrame.new(ctx.cursor), ObbyConfig.Palette.Finish, Enum.Material.Neon)
	signOn(finish, ("+%d COINS"):format(tier.reward), ObbyConfig.Palette.Finish, 10)

	folder.Parent = courses

	local summary = {}
	for kind, count in pairs(used) do
		table.insert(summary, ("%s x%d"):format(kind, count))
	end
	table.sort(summary)
	print(("  %s: %s"):format(tier.name, table.concat(summary, ", ")))

	return {
		tier = tier,
		entry = entryPosition,
		finish = finish,
		checkpoints = checkpoints,
	}
end

print("Obbies building:")
for _, tier in ipairs(ObbyConfig.Tiers) do
	local course = buildCourse(tier)
	if course then
		table.insert(built, course)
	end
end
courses.Parent = workspace

-- ===========================================================
--  Driving the moving parts
-- ===========================================================

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for _, item in ipairs(dynamics) do
		if not item.part.Parent then
			continue
		end

		if item.kind == "mover" then
			local sweep = math.sin(now * (math.pi * 2 / item.period) + item.phase)
			item.align.Position = item.centre + item.axis * (sweep * item.travel / 2)

		elseif item.kind == "spinner" then
			item.part.CFrame = CFrame.new(item.centre)
				* CFrame.Angles(0, now * item.speed + item.phase, 0)

		elseif item.kind == "fader" then
			local cycle = item.onTime + item.offTime
			local at = (now + item.phase) % cycle
			local solid = at < item.onTime
			-- fade out over the last half second, so it is a warning
			-- rather than the floor simply vanishing
			local warning = solid and math.max(0, (at - (item.onTime - 0.5)) / 0.5) or 1
			item.part.Transparency = solid and (warning * 0.7) or 0.9
			item.part.CanCollide = solid
		end
	end
end)

-- ===========================================================
--  Checkpoints, lava and falling
-- ===========================================================

local function checkpointOf(player: Player, course: Course): Vector3
	local slot = player:GetAttribute("Obby_" .. course.tier.key)
	if typeof(slot) == "number" then
		local point = course.checkpoints[slot]
		if point then
			return point
		end
	end
	return course.entry
end

local function nearestCourse(position: Vector3): Course?
	local best, bestDistance = nil, math.huge
	for _, course in ipairs(built) do
		local flat = Vector3.new(
			position.X - course.entry.X, 0, position.Z - course.entry.Z
		).Magnitude
		if flat < bestDistance then
			best, bestDistance = course, flat
		end
	end
	return best
end

local function sendBack(player: Player, position: Vector3)
	local character = player.Character
	if not character then
		return
	end
	local course = nearestCourse(position)
	if not course then
		return
	end
	character:PivotTo(CFrame.new(checkpointOf(player, course) + Vector3.new(0, 5, 0)))
end

for pool in pairs(lavaParts) do
	pool.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			sendBack(player, root.Position)
		end
	end)
end

-- Out here there is no floor below, and the arena's own check would
-- drop you all the way back to the spawn ring on the far side of the
-- map. Catch them higher and return them to their checkpoint.
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

			local dx = math.abs(position.X - ORIGIN.X)
			local dz = math.abs(position.Z - ORIGIN.Z)
			if dx < RECOVERY.BeyondX and dz < RECOVERY.BeyondZ then
				continue   -- inside the walls; the arena handles that
			end

			sendBack(player, position)
		end
	end
end)

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

	-- back to the start, so the next run is a fresh one
	player:SetAttribute("Obby_" .. tier.key, 1)

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

Players.PlayerRemoving:Connect(function(player)
	lastClaim[player] = nil
end)
