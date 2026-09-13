--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the lobby
--
--  Everyone spawns here, on joining and on dying. Walk into the
--  portal, or press PLAY, and you are put down on the market
--  block in the city.
--
--  Lobby spawning works by being the only enabled
--  SpawnLocation. Any other one in the workspace -- the city's
--  pads, or a leftover from the Studio Baseplate -- is switched
--  off the moment it appears, so the rule holds whatever order
--  the scripts happen to load in.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("LobbyConfig"))
local StageConfig = require(ReplicatedStorage:WaitForChild("StageConfig"))

local PLACE   = LobbyConfig.Place
local PORTAL  = LobbyConfig.Portal
local PALETTE = LobbyConfig.Palette
local CENTRE  = PLACE.Centre
local FLOOR_Y = CENTRE.Y + PLACE.Size.Y / 2

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "LobbyRemotes"

local playRequest = Instance.new("RemoteEvent")
playRequest.Name = "Play"
playRequest.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Building it
-- ===========================================================

local lobby = Instance.new("Model")
lobby.Name = "Lobby"

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
	part.Parent = lobby
	return part
end

local function onFloor(offset: Vector3, height: number): Vector3
	return Vector3.new(CENTRE.X + offset.X, FLOOR_Y + height, CENTRE.Z + offset.Z)
end

-- floor, chequered in big tiles so it reads as a room, not a slab
do
	local tiles = PLACE.TileCount
	local tile = PLACE.Size.X / tiles
	for i = 1, tiles do
		for j = 1, tiles do
			local x = -PLACE.Size.X / 2 + (i - 0.5) * tile
			local z = -PLACE.Size.Z / 2 + (j - 0.5) * tile
			makePart("Floor", Vector3.new(tile, PLACE.Size.Y, tile),
				CFrame.new(CENTRE + Vector3.new(x, 0, z)),
				(i + j) % 2 == 0 and PALETTE.FloorA or PALETTE.FloorB,
				Enum.Material.Marble)
		end
	end
end

-- glass railing all round, tall enough that nobody walks off by mistake
do
	local h = PLACE.RailHeight
	local half = PLACE.Size.X / 2
	for _, side in ipairs({
		{ Vector3.new(0, 0, -half), Vector3.new(PLACE.Size.X, h, 1) },
		{ Vector3.new(0, 0, half), Vector3.new(PLACE.Size.X, h, 1) },
		{ Vector3.new(-half, 0, 0), Vector3.new(1, h, PLACE.Size.Z) },
		{ Vector3.new(half, 0, 0), Vector3.new(1, h, PLACE.Size.Z) },
	}) do
		local rail = makePart("Railing", side[2], CFrame.new(onFloor(side[1], h / 2)),
			PALETTE.Rail, Enum.Material.Glass)
		rail.Transparency = 0.55

		makePart("RailTop", Vector3.new(side[2].X + 0.4, 0.6, side[2].Z + 0.4),
			CFrame.new(onFloor(side[1], h + 0.3)), PALETTE.Trim, Enum.Material.Metal)
	end
end

-- ---- the portal ---------------------------------------------------------

local portalBase = onFloor(PORTAL.Offset, 0)
local spawnAt = onFloor(LobbyConfig.Spawn.Offset, 0)
local facingSpawn = CFrame.lookAt(portalBase, Vector3.new(spawnAt.X, portalBase.Y, spawnAt.Z))

for _, side in ipairs({ -1, 1 }) do
	makePart("PortalPillar", Vector3.new(3, PORTAL.Height, 3),
		facingSpawn * CFrame.new(side * (PORTAL.Width / 2 + 1.5), PORTAL.Height / 2, 0),
		PALETTE.Pillar, Enum.Material.Metal)
end

makePart("PortalLintel", Vector3.new(PORTAL.Width + 6, 3, 3),
	facingSpawn * CFrame.new(0, PORTAL.Height + 1.5, 0),
	PALETTE.Pillar, Enum.Material.Metal)

local field = makePart("PortalField", Vector3.new(PORTAL.Width, PORTAL.Height, 1.2),
	facingSpawn * CFrame.new(0, PORTAL.Height / 2, 0),
	PALETTE.Portal, Enum.Material.Neon)
field.Transparency = 0.35
field.CanCollide = false

local glow = Instance.new("PointLight")
glow.Color = PALETTE.Portal
glow.Range = 30
glow.Brightness = 2
glow.Parent = field

local portalSign = Instance.new("SurfaceGui")
portalSign.Face = Enum.NormalId.Front
portalSign.CanvasSize = Vector2.new(400, 80)
portalSign.LightInfluence = 0
portalSign.Parent = makePart("PortalSign", Vector3.new(PORTAL.Width + 6, 3, 0.4),
	facingSpawn * CFrame.new(0, PORTAL.Height + 1.5, -1.8),
	PALETTE.Pillar, Enum.Material.SmoothPlastic)

do
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = PALETTE.Portal
	label.Text = "ENTER THE CITY"
	label.Parent = portalSign
end

-- ---- the title wall, behind the portal, facing arrivals -------------------

do
	local wall = makePart("TitleWall", Vector3.new(80, 24, 2),
		facingSpawn * CFrame.new(0, 12, -12), PALETTE.FloorA, Enum.Material.SmoothPlastic)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 240)
	gui.LightInfluence = 0
	gui.Parent = wall

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.62, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = PALETTE.Title
	title.Text = "THE HOUSE OF FIGHTING"
	title.Parent = gui

	local strap = Instance.new("TextLabel")
	strap.Size = UDim2.new(1, 0, 0.26, 0)
	strap.Position = UDim2.new(0, 0, 0.66, 0)
	strap.BackgroundTransparency = 1
	strap.Font = Enum.Font.GothamBold
	strap.TextScaled = true
	strap.TextColor3 = PALETTE.Accent
	strap.Text = "smash it  -  build it  -  drive through it"
	strap.Parent = gui
end

-- ---- how to play ----------------------------------------------------------

do
	local boardAt = onFloor(LobbyConfig.Board.Offset, 9)
	local board = makePart("HowToPlay", Vector3.new(36, 16, 1),
		CFrame.lookAt(boardAt, Vector3.new(CENTRE.X, boardAt.Y, CENTRE.Z)),
		PALETTE.Trim, Enum.Material.SmoothPlastic)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(720, 320)
	gui.LightInfluence = 0
	gui.Parent = board

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, -40, 0, 50)
	heading.Position = UDim2.new(0, 20, 0, 12)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 36
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = PALETTE.Portal
	heading.Text = "HOW TO PLAY"
	heading.Parent = gui

	for i, line in ipairs(LobbyConfig.HowToPlay) do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -40, 0, 32)
		row.Position = UDim2.new(0, 20, 0, 64 + (i - 1) * 34)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 22
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(232, 232, 240)
		row.Text = line
		row.Parent = gui
	end
end

-- ---- the one spawn --------------------------------------------------------

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Size = Vector3.new(14, 1, 14)
spawn.CFrame = CFrame.new(spawnAt + Vector3.new(0, 0.5, 0))
spawn.Color = PALETTE.Portal
spawn.Material = Enum.Material.Neon
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Parent = lobby

lobby.Parent = workspace

-- Every other SpawnLocation is switched off, including ones created
-- after this runs. The city's pads stay as markers to land on; they
-- just stop being where anyone is born.
local function silence(instance: Instance)
	if instance:IsA("SpawnLocation") and instance ~= spawn then
		instance.Enabled = false
	end
end

for _, instance in ipairs(workspace:GetDescendants()) do
	silence(instance)
end
workspace.DescendantAdded:Connect(silence)

-- ===========================================================
--  Going down to the city
-- ===========================================================

local rng = Random.new()
local lastTrip: { [Player]: number } = {}

local function cityLanding(): Vector3
	local spawns = StageConfig.Spawns
	local origin = StageConfig.Bounds.Origin
	local angle = (rng:NextInteger(1, spawns.Count) - 1) / spawns.Count * math.pi * 2
	return origin + Vector3.new(
		math.cos(angle) * spawns.Radius, 4.5, math.sin(angle) * spawns.Radius)
end

local function toCity(player: Player)
	if player:GetAttribute("InLobby") ~= true then
		return
	end
	local now = os.clock()
	if lastTrip[player] and now - lastTrip[player] < PORTAL.Cooldown then
		return
	end
	lastTrip[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root) then
		return
	end

	character:PivotTo(CFrame.new(cityLanding()))
	player:SetAttribute("InLobby", false)
end

field.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if player then
		toCity(player)
	end
end)

playRequest.OnServerEvent:Connect(toCity)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("InLobby", true)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player:SetAttribute("InLobby", true)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("InLobby", true)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastTrip[player] = nil
end)

print(("Lobby ready at height %d, %d parts"):format(CENTRE.Y, #lobby:GetDescendants()))
