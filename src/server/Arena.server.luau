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

local function buildBoundary()
	local segments = BOUND.Segments
	local segmentWidth = 2 * math.pi * BOUND.Radius / segments + 1

	for i = 1, segments do
		local angle = (i - 1) / segments * math.pi * 2

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

task.spawn(function()
	local floorY = ARENA.Origin.Y - StageConfig.Respawn.FallGrace

	while true do
		task.wait(StageConfig.Respawn.CheckRate)

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and root.Position.Y < floorY then
				local stats = player:FindFirstChild("leaderstats")
				if stats and stats:FindFirstChild("Falls") then
					stats.Falls.Value += 1
				end
				local pad = spawnPads[rng:NextInteger(1, #spawnPads)]
				character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local falls = Instance.new("IntValue")
	falls.Name = "Falls"
	falls.Parent = stats
end)
