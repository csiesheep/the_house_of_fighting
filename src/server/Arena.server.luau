--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the ground and the boundary
--
--  A rectangular slab, the road grid painted onto it, spawn
--  pads on the ring road, and a wall around the lot with gaps
--  where the obby walkways leave.
--
--  City.server.luau puts buildings on the blocks; this only
--  lays the ground they stand on.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageConfig = require(ReplicatedStorage:WaitForChild("StageConfig"))
local CityConfig  = require(ReplicatedStorage:WaitForChild("CityConfig"))

local BOUNDS = StageConfig.Bounds
local BASE   = StageConfig.Base
local BOUND  = StageConfig.Boundary
local GRID   = CityConfig.Grid
local ORIGIN = BOUNDS.Origin

local stage = Instance.new("Folder")
stage.Name = "Stage"

local spawnPads: { SpawnLocation } = {}

local function makePart(name: string, size: Vector3, cframe: CFrame,
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
	part.Parent = stage
	return part
end

-- ===========================================================
--  Ground
-- ===========================================================

local function buildGround()
	local width = BOUNDS.HalfX * 2 + BASE.Overhang * 2
	local depth = BOUNDS.HalfZ * 2 + BASE.Overhang * 2

	-- One slab under everything. Roads and pavements are painted on
	-- top of it, so there is never a seam you can fall through.
	makePart("Base", Vector3.new(width, BASE.Depth, depth),
		CFrame.new(ORIGIN - Vector3.new(0, BASE.Inset + BASE.Depth / 2, 0)),
		StageConfig.Palette.Base, Enum.Material.Concrete)

	makePart("Roads", Vector3.new(BOUNDS.HalfX * 2, 1, BOUNDS.HalfZ * 2),
		CFrame.new(ORIGIN - Vector3.new(0, 0.5, 0)),
		StageConfig.Palette.Road, Enum.Material.Asphalt)
end

local function blockCentre(index: number, count: number): number
	local half = (count * GRID.BlockSize + (count + 1) * GRID.RoadWidth) / 2
	return -half + GRID.RoadWidth + (index - 1) * (GRID.BlockSize + GRID.RoadWidth)
		+ GRID.BlockSize / 2
end

-- Each block gets a kerb at the road edge and a walkable sidewalk
-- inside it. The building's own pad is City.server's business, since
-- only it knows whether the block is a tower or a park.
local function buildSidewalks()
	local WALK = CityConfig.Sidewalk
	local size = GRID.BlockSize

	for col = 1, GRID.Cols do
		for row = 1, GRID.Rows do
			local centre = ORIGIN + Vector3.new(
				blockCentre(col, GRID.Cols), 0, blockCentre(row, GRID.Rows))

			-- the kerb: a raised lip the full footprint, which the
			-- sidewalk then sits inside
			makePart("Kerb", Vector3.new(size, 1.6, size),
				CFrame.new(centre + Vector3.new(0, WALK.KerbRise - 0.8, 0)),
				WALK.Kerb, Enum.Material.Concrete)

			-- the walkable surface, inset by the kerb width. Chequered
			-- so it reads as paving slabs rather than one grey sheet.
			local inner = size - WALK.KerbWidth * 2
			makePart("Sidewalk", Vector3.new(inner, 1.6, inner),
				CFrame.new(centre + Vector3.new(0, WALK.WalkRise - 0.8, 0)),
				(col + row) % 2 == 0 and WALK.Walk or WALK.WalkAlt,
				Enum.Material.Concrete)
		end
	end
end

local function buildRoadMarkings()
	local spanX = BOUNDS.HalfX * 2 - 4
	local spanZ = BOUNDS.HalfZ * 2 - 4

	for i = 1, GRID.Cols + 1 do
		local x = -BOUNDS.HalfX + GRID.RoadWidth / 2
			+ (i - 1) * (GRID.BlockSize + GRID.RoadWidth)
		makePart("Lane", Vector3.new(GRID.LaneMark, 1.1, spanZ),
			CFrame.new(ORIGIN + Vector3.new(x, -0.42, 0)),
			StageConfig.Palette.RoadLine, Enum.Material.SmoothPlastic)
	end

	for i = 1, GRID.Rows + 1 do
		local z = -BOUNDS.HalfZ + GRID.RoadWidth / 2
			+ (i - 1) * (GRID.BlockSize + GRID.RoadWidth)
		makePart("Lane", Vector3.new(spanX, 1.1, GRID.LaneMark),
			CFrame.new(ORIGIN + Vector3.new(0, -0.42, z)),
			StageConfig.Palette.RoadLine, Enum.Material.SmoothPlastic)
	end
end

-- ===========================================================
--  Boundary
-- ===========================================================

-- true if this point on the wall falls inside an obby gateway
local function inGate(point: Vector3): boolean
	for _, gate in ipairs(StageConfig.Gates) do
		local delta = point - gate.position
		if math.abs(delta.X) <= BOUND.GateHalfWidth
			and math.abs(delta.Z) <= BOUND.GateHalfWidth then
			return true
		end
	end
	return false
end

local function buildBoundary()
	local panels, gaps = 0, 0

	local function runWall(from: Vector3, to: Vector3)
		local span = to - from
		local length = span.Magnitude
		local direction = span.Unit
		local steps = math.ceil(length / BOUND.SegmentLength)
		local segment = length / steps

		for i = 1, steps do
			local centre = from + direction * (segment * (i - 0.5))

			if inGate(centre) then
				gaps += 1
				continue
			end

			local at = ORIGIN + centre + Vector3.new(0, BOUND.Height / 2, 0)
			local panel = makePart("Boundary",
				Vector3.new(segment + 0.5, BOUND.Height, BOUND.Thickness),
				CFrame.lookAt(at, at + direction) * CFrame.Angles(0, math.rad(90), 0),
				StageConfig.Palette.Boundary, Enum.Material.Glass)
			panel.Transparency = BOUND.Transparency
			panel.Reflectance = 0.1
			panels += 1
		end
	end

	local x, z = BOUNDS.HalfX, BOUNDS.HalfZ
	runWall(Vector3.new(-x, 0, -z), Vector3.new(x, 0, -z))
	runWall(Vector3.new(x, 0, -z), Vector3.new(x, 0, z))
	runWall(Vector3.new(x, 0, z), Vector3.new(-x, 0, z))
	runWall(Vector3.new(-x, 0, z), Vector3.new(-x, 0, -z))

	print(("Boundary: %d panels, %d openings for obby gates"):format(panels, gaps))
end

-- ===========================================================
--  Spawns
-- ===========================================================

local function buildSpawns()
	for i = 1, StageConfig.Spawns.Count do
		local angle = (i - 1) / StageConfig.Spawns.Count * math.pi * 2
		local pad = Instance.new("SpawnLocation")
		pad.Name = "Spawn" .. i
		pad.Anchored = true
		pad.Neutral = true
		pad.Duration = 0                  -- no forcefield; this is a fighting game
		pad.Size = Vector3.new(6, 1, 6)
		pad.Position = ORIGIN + Vector3.new(
			math.cos(angle) * StageConfig.Spawns.Radius,
			0.6,
			math.sin(angle) * StageConfig.Spawns.Radius
		)
		pad.Color = StageConfig.Palette.Spawn
		pad.Material = Enum.Material.Neon
		pad.TopSurface = Enum.SurfaceType.Smooth
		pad.Parent = stage
		spawnPads[i] = pad
	end
end

buildGround()
buildSidewalks()
buildRoadMarkings()
buildBoundary()
buildSpawns()

stage.Parent = workspace   -- parent once, at the end

print(("Arena: %d x %d studs, %d spawns")
	:format(BOUNDS.HalfX * 2, BOUNDS.HalfZ * 2, #spawnPads))

-- ===========================================================
--  Fall recovery
-- ===========================================================

local rng = Random.new()

-- Where each player last had both feet on something solid inside the
-- map. Falling used to drop you on a random spawn pad, which across a
-- map this wide was most of a minute of walking back.
local lastSafe: { [Player]: Vector3 } = {}

task.spawn(function()
	local floorY = ORIGIN.Y - StageConfig.Respawn.FallGrace

	while true do
		task.wait(StageConfig.Respawn.CheckRate)

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not (root and root:IsA("BasePart") and humanoid) then
				continue
			end

			local position = root.Position

			if position.Y < floorY then
				local stats = player:FindFirstChild("leaderstats")
				local falls = stats and stats:FindFirstChild("Falls")
				if falls and falls:IsA("IntValue") then
					falls.Value += 1
				end

				local target = lastSafe[player]
				if not target then
					target = spawnPads[rng:NextInteger(1, #spawnPads)].Position
				end
				character:PivotTo(CFrame.new(target + Vector3.new(0, 5, 0)))
				continue
			end

			-- Only record while standing on something, inside the walls.
			-- Mid-air positions are exactly the ones that would put you
			-- straight back over the hole you just fell through.
			if humanoid.FloorMaterial == Enum.Material.Air then
				continue
			end

			local dx = math.abs(position.X - ORIGIN.X)
			local dz = math.abs(position.Z - ORIGIN.Z)
			if dx <= BOUNDS.HalfX and dz <= BOUNDS.HalfZ then
				lastSafe[player] = position
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSafe[player] = nil
end)
