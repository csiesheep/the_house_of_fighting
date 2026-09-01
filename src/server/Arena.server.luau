--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- server
--
--  PLACEHOLDER STAGE. This builds a tiled circular arena with
--  spawn points and ring-out recovery, so the project is
--  playable end to end while the real design is decided.
--  Expect to throw most of this away.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageConfig = require(ReplicatedStorage:WaitForChild("StageConfig"))
local ARENA = StageConfig.Arena

-- ===========================================================
--  1. Build the arena
-- ===========================================================

local stage = Instance.new("Folder")
stage.Name = "Stage"

local spawnPads: { SpawnLocation } = {}
local tileCount = 0

local function buildFloor()
	local size = ARENA.TileSize
	local reach = math.ceil(ARENA.Radius / size)

	for gx = -reach, reach do
		for gz = -reach, reach do
			local cx = gx * size
			local cz = gz * size
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

			-- a red band on the outermost ring, so the edge reads clearly
			-- from the middle of a fight
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

local function buildWalls()
	if ARENA.WallHeight <= 0 then
		return
	end

	-- a ring of thin panels approximating a circle
	local segments = 48
	for i = 1, segments do
		local angle = (i - 1) / segments * math.pi * 2
		local panel = Instance.new("Part")
		panel.Name = "Wall"
		panel.Anchored = true
		panel.Size = Vector3.new(2 * math.pi * ARENA.Radius / segments + 1, ARENA.WallHeight, 1)
		panel.CFrame = CFrame.new(
			ARENA.Origin + Vector3.new(
				math.cos(angle) * ARENA.Radius,
				ARENA.WallHeight / 2,
				math.sin(angle) * ARENA.Radius
			)
		) * CFrame.Angles(0, -angle, 0)
		panel.Color = StageConfig.Palette.TileA
		panel.Material = Enum.Material.Concrete
		panel.Parent = stage
	end
end

buildFloor()
buildSpawns()
buildWalls()

stage.Parent = workspace   -- parent once, at the end: far faster than per-part

print(("House of Fighting: %d floor tiles, %d spawns, radius %d studs")
	:format(tileCount, #spawnPads, ARENA.Radius))

-- ===========================================================
--  2. Ring-out recovery
--
--  Falling off should cost you the exchange, not thirty seconds
--  of respawn animation. Anyone below the floor gets put back on
--  a spawn pad immediately.
-- ===========================================================

local rng = Random.new()

local function returnToPad(character: Model)
	local pad = spawnPads[rng:NextInteger(1, #spawnPads)]
	character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
end

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
				returnToPad(character :: Model)
			end
		end
	end
end)

-- ===========================================================
--  3. Joining
-- ===========================================================

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local falls = Instance.new("IntValue")
	falls.Name = "Falls"
	falls.Parent = stats
end)
