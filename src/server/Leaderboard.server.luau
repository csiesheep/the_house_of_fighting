--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- global leaderboards
--
--  Three boards at the edge of the map: most bricks, most
--  coins, most Robux spent. Top ten on the board face, the
--  full hundred behind a prompt.
--
--  Global across every server, which means OrderedDataStore.
--  If the place is not published there is no store to read, so
--  the boards say that plainly instead of standing empty.
-- ===========================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("LeaderboardConfig"))

local PLACE = Config.Placement
local RULES = Config.Rules

-- ===========================================================
--  Stores
-- ===========================================================

local stores: { [string]: OrderedDataStore } = {}
local available = false

do
	local ok = pcall(function()
		for _, category in ipairs(Config.Categories) do
			stores[category.key] = DataStoreService:GetOrderedDataStore(category.store)
		end
	end)

	if ok then
		-- GetOrderedDataStore succeeds even with no access; only a real
		-- call proves anything
		local probe = pcall(function()
			return stores[Config.Categories[1].key]:GetSortedAsync(false, 1):GetCurrentPage()
		end)
		available = probe
	end

	if not available then
		warn("Leaderboards unavailable -- publish the place and enable "
			.. "Studio Access to API Services for global rankings.")
	end
end

-- ===========================================================
--  Remotes
-- ===========================================================

local remotes = Instance.new("Folder")
remotes.Name = "LeaderboardRemotes"

local openBoard = Instance.new("RemoteEvent")
openBoard.Name = "OpenBoard"
openBoard.Parent = remotes

local boardData = Instance.new("RemoteFunction")
boardData.Name = "BoardData"
boardData.Parent = remotes

remotes.Parent = ReplicatedStorage

-- ===========================================================
--  Reading
-- ===========================================================

type Entry = { rank: number, name: string, value: number }

local ranked: { [string]: { Entry } } = {}
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end

	local resolved = "Player " .. userId
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(result) == "string" then
		resolved = result
	end

	nameCache[userId] = resolved
	return resolved
end

local function refreshCategory(category)
	local store = stores[category.key]
	if not store then
		return
	end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, math.min(100, RULES.TopCount))
	end)
	if not ok then
		return
	end

	local entries: { Entry } = {}
	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage then
		return
	end

	for index, row in ipairs(page) do
		if #entries >= RULES.TopCount then
			break
		end
		local userId = tonumber(row.key)
		if userId then
			table.insert(entries, {
				rank = index,
				name = nameFor(userId),
				value = row.value,
			})
		end
	end

	ranked[category.key] = entries
end

-- ===========================================================
--  Writing
-- ===========================================================

local function valueFor(player: Player, category): number?
	if category.stat then
		local stats = player:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild(category.stat)
		return (value and value:IsA("IntValue")) and value.Value or nil
	end
	if category.attribute then
		local value = player:GetAttribute(category.attribute)
		return typeof(value) == "number" and value or nil
	end
	return nil
end

local function publish(player: Player)
	if not available then
		return
	end
	for _, category in ipairs(Config.Categories) do
		local value = valueFor(player, category)
		local store = stores[category.key]
		if store and value and value > 0 then
			pcall(function()
				store:SetAsync(tostring(player.UserId), math.floor(value))
			end)
		end
	end
end

-- ===========================================================
--  The boards
-- ===========================================================

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

local faces: { [string]: { rows: { TextLabel }, note: TextLabel } } = {}

local function buildBoard(category, index: number, total: number, parent: Instance)
	-- a row along the west edge road, all three facing into the map
	local offset = (index - (total + 1) / 2) * PLACE.Spacing
	local position = PLACE.Origin + Vector3.new(
		PLACE.LineX,
		PLACE.BoardSize.Y / 2 + 3,
		offset
	)

	-- lookAt points the part's LookVector at the target, and a part's
	-- Front face is that same -Z direction, so the display faces inward
	local facing = CFrame.lookAt(position, position + Vector3.new(1, 0, 0))

	local board = makePart(parent, category.key .. "Board", PLACE.BoardSize, facing,
		Color3.fromRGB(28, 26, 32), Enum.Material.SmoothPlastic)

	makePart(parent, category.key .. "Stand", PLACE.StandSize,
		CFrame.new(position - Vector3.new(0, PLACE.BoardSize.Y / 2 + 1.5, 0))
			* (facing - facing.Position),
		Color3.fromRGB(64, 60, 70), Enum.Material.Metal)

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(520, 360)
	surface.LightInfluence = 0
	surface.Parent = board

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 46)
	header.BackgroundColor3 = category.colour
	header.TextColor3 = Color3.fromRGB(22, 20, 26)
	header.Font = Enum.Font.GothamBlack
	header.TextSize = 26
	header.Text = category.title
	header.Parent = surface

	local rows: { TextLabel } = {}
	for i = 1, RULES.FaceCount do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -24, 0, 28)
		row.Position = UDim2.new(0, 12, 0, 52 + (i - 1) * 29)
		row.BackgroundTransparency = 1
		row.TextColor3 = Color3.fromRGB(226, 222, 230)
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 19
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.Parent = surface
		rows[i] = row
	end

	local note = Instance.new("TextLabel")
	note.Size = UDim2.new(1, -24, 0, 24)
	note.Position = UDim2.new(0, 12, 1, -30)
	note.BackgroundTransparency = 1
	note.TextColor3 = Color3.fromRGB(150, 146, 158)
	note.Font = Enum.Font.Gotham
	note.TextSize = 16
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.Text = "loading..."
	note.Parent = surface

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Full top " .. RULES.TopCount
	prompt.ObjectText = category.title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PLACE.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = board

	prompt.Triggered:Connect(function(player)
		openBoard:FireClient(player, category.key)
	end)

	faces[category.key] = { rows = rows, note = note }
end

local boards = Instance.new("Folder")
boards.Name = "Leaderboards"
for index, category in ipairs(Config.Categories) do
	buildBoard(category, index, #Config.Categories, boards)
end
boards.Parent = workspace

-- ===========================================================
--  Painting the faces
-- ===========================================================

local function comma(value: number): string
	local text = tostring(math.floor(value))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function paint(category)
	local face = faces[category.key]
	if not face then
		return
	end

	if not available then
		for _, row in ipairs(face.rows) do
			row.Text = ""
		end
		face.note.Text = "publish the place to rank globally"
		return
	end

	local entries = ranked[category.key] or {}
	for i, row in ipairs(face.rows) do
		local entry = entries[i]
		if entry then
			row.Text = ("%d.  %s%s"):format(entry.rank, entry.name,
				("   %s%s"):format(comma(entry.value), category.suffix))
		else
			row.Text = ""
		end
	end

	if #entries == 0 then
		face.note.Text = "no scores yet"
	else
		face.note.Text = ("top %d of %d  -  press E for the full list")
			:format(math.min(#entries, RULES.FaceCount), #entries)
	end
end

boardData.OnServerInvoke = function(_player, key)
	if type(key) ~= "string" then
		return {}
	end
	return ranked[key] or {}
end

task.spawn(function()
	while true do
		if available then
			for _, category in ipairs(Config.Categories) do
				refreshCategory(category)
			end
		end
		for _, category in ipairs(Config.Categories) do
			paint(category)
		end
		task.wait(RULES.RefreshEvery)
	end
end)

task.spawn(function()
	while true do
		task.wait(RULES.PublishEvery)
		for _, player in ipairs(Players:GetPlayers()) do
			publish(player)
		end
	end
end)

Players.PlayerRemoving:Connect(publish)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		publish(player)
	end
end)

print(("Leaderboards: %d boards, top %d, %s")
	:format(#Config.Categories, RULES.TopCount,
		available and "global ranking live" or "no store, showing a notice"))
