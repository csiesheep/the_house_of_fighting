--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the ground and the boundary
--
--  A solid base slab, a decorative tiled disc on top of it,
--  spawn pads, and a wall around the whole thing.
--
--  The wall is not tagged Breakable. It is the one structure
--  in the place the hammer cannot touch.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageConfig = require(ReplicatedStorage:WaitForChild("StageConfig"))
local ARENA = StageConfig.Arena
local BASE  = StageConfig.Base
local BOUND = StageConfig.Boundary

local stage = Instance.new("Folder")
stage.Name = "Stage"

local spawnPads: { SpawnLocation } = {}
local tileCount = 0

-- ===========================================================
--  Floor
-- ===========================================================

-- One solid disc under everything. The tiles above are a jagged
-- circle; this is what stops you falling between them.
local function buildBase()
	local slab = Instance.new("Part")
	slab.Name = "Base"
	slab.Anchored = true
	slab.Shape = Enum.PartType.Cylinder
	slab.Size = Vector3.new(BASE.Depth, BASE.Radius * 2, BASE.Radius * 2)
	-- a cylinder's flat faces point along X, so stand it on end
	slab.CFrame = CFrame.new(ARENA.Origin - Vector3.new(0, BASE.Inset + BASE.Depth / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	slab.Color = StageConfig.Palette.Base
	slab.Material = Enum.Material.Slate
	slab.TopSurface = Enum.SurfaceType.Smooth
	slab.Parent = stage
end

local function buildTiles()
	local size = ARENA.TileSize
	local reach = math.ceil(ARENA.Radius / size)

	for gx = -reach, reach do
		for gz = -reach, reach do
			local cx, cz = gx * size, gz * size
			local distance = math.sqrt(cx * cx + cz * cz)
			if distance > ARENA.Radius then
				continue
			end

			local tile = Instance.new("Part")
			tile.Name = "Tile"
			tile.Anchored = true
			tile.Size = Vector3.new(size, ARENA.TileHeight, size)
			tile.Position = ARENA.Origin + Vector3.new(cx, -ARENA.TileHeight / 2, cz)
			tile.TopSurface = Enum.SurfaceType.Smooth
			tile.BottomSurface = Enum.SurfaceType.Smooth
			tile.Material = Enum.Material.Slate

			if distance > ARENA.Radius - size then
				tile.Color = StageConfig.Palette.Edge
			elseif (gx + gz) % 2 == 0 then
				tile.Color = StageConfig.Palette.TileA
			else
				tile.Color = StageConfig.Palette.TileB
			end

			tile.Parent = stage
			tileCount += 1
		end
	end
end

-- ===========================================================
--  Boundary wall
-- ===========================================================

-- true if this angle falls inside one of the obby gates
local function inGate(degrees: number): boolean
	for _, gate in ipairs(StageConfig.Gates.Angles) do
		local delta = math.abs((degrees - gate + 180) % 360 - 180)
		if delta <= StageConfig.Gates.HalfWidthDeg then
			return true
		end
	end
	return false
end

local function buildBoundary()
	local segments = BOUND.Segments
	local segmentWidth = 2 * math.pi * BOUND.Radius / segments + 1
	local gaps = 0

	for i = 1, segments do
		local angle = (i - 1) / segments * math.pi * 2

		-- leave a doorway where an obby walkway passes through
		if inGate(math.deg(angle)) then
			gaps += 1
			continue
		end

		local panel = Instance.new("Part")
		panel.Name = "Boundary"
		panel.Anchored = true
		panel.CanCollide = true
		panel.Size = Vector3.new(segmentWidth, BOUND.Height, BOUND.Thickness)
		panel.CFrame = CFrame.new(ARENA.Origin + Vector3.new(
			math.cos(angle) * BOUND.Radius,
			BOUND.Height / 2,
			math.sin(angle) * BOUND.Radius
		)) * CFrame.Angles(0, -angle, 0)
		panel.Color = StageConfig.Palette.Boundary
		panel.Material = Enum.Material.Glass
		panel.Transparency = BOUND.Transparency
		panel.Reflectance = 0.1
		panel.TopSurface = Enum.SurfaceType.Smooth
		panel.BottomSurface = Enum.SurfaceType.Smooth
		panel.Parent = stage
	end

	print(("Boundary: %d panels, %d left open as obby gates")
		:format(segments - gaps, gaps))
end

-- ===========================================================
--  Spawns
-- ===========================================================

local function buildSpawns()
	for i = 1, ARENA.SpawnCount do
		local angle = (i - 1) / ARENA.SpawnCount * math.pi * 2
		local pad = Instance.new("SpawnLocation")
		pad.Name = "Spawn" .. i
		pad.Anchored = true
		pad.Neutral = true
		pad.Duration = 0                  -- no forcefield; this is a fighting game
		pad.Size = Vector3.new(6, 1, 6)
		pad.Position = ARENA.Origin + Vector3.new(
			math.cos(angle) * ARENA.SpawnRadius,
			0.5,
			math.sin(angle) * ARENA.SpawnRadius
		)
		pad.Color = StageConfig.Palette.Spawn
		pad.Material = Enum.Material.Neon
		pad.TopSurface = Enum.SurfaceType.Smooth
		pad.Parent = stage
		spawnPads[i] = pad
	end
end

buildBase()
buildTiles()
buildBoundary()
buildSpawns()

stage.Parent = workspace   -- parent once, at the end

print(("Arena: %d tiles, %d spawns, floor radius %d, wall radius %d x %d high")
	:format(tileCount, #spawnPads, ARENA.Radius, BOUND.Radius, BOUND.Height))

-- ===========================================================
--  Fall recovery
-- ===========================================================

local rng = Random.new()

-- Where each player last had both feet on something solid inside the
-- arena. Falling used to drop you on a random spawn pad, which on a
-- map this wide could be most of a minute of walking back for a
-- mistake that took a second.
local lastSafe: { [Player]: Vector3 } = {}

task.spawn(function()
	local floorY = ARENA.Origin.Y - StageConfig.Respawn.FallGrace
	local edge = ARENA.Radius + 6

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

				-- back to where you fell from, not to a spawn pad
				local target = lastSafe[player]
				if not target then
					target = spawnPads[rng:NextInteger(1, #spawnPads)].Position
				end
				character:PivotTo(CFrame.new(target + Vector3.new(0, 5, 0)))
				continue
			end

			-- Only record while standing on something, inside the arena.
			-- Mid-air positions are exactly the ones that would put you
			-- straight back over the hole you just fell through.
			if humanoid.FloorMaterial == Enum.Material.Air then
				continue
			end

			local radius = Vector3.new(position.X - ARENA.Origin.X, 0,
				position.Z - ARENA.Origin.Z).Magnitude
			if radius <= edge then
				lastSafe[player] = position
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSafe[player] = nil
end)

-- leaderstats is created by Score.server.luau, which owns it. Two
-- scripts creating a folder of the same name can produce two folders
-- and a player list that shows neither.
