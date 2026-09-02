--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- building
--
--  Gives everyone a trowel and lets them put bricks up.
--
--  The client sends a position; this decides whether it is
--  allowed. Every rule is rechecked here -- reach, alignment,
--  arena bounds, whether the cell is free, and how much you
--  have already built -- because a client can ask for
--  anything.
--
--  Placed bricks are tagged Breakable like everything else, so
--  what you build is exactly as smashable as what you found.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Building = require(ReplicatedStorage:WaitForChild("Building"))

local builds = Instance.new("Folder")
builds.Name = Building.FolderName
builds.Parent = workspace

local remotes = Instance.new("Folder")
remotes.Name = "BuildRemotes"

local placeBrick = Instance.new("RemoteEvent")
placeBrick.Name = "PlaceBrick"
placeBrick.Parent = remotes

remotes.Parent = ReplicatedStorage

local placedBy: { [Player]: number } = {}

-- ===========================================================
--  Placing
-- ===========================================================

local function cellIsFree(position: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}

	-- slightly under size, so bricks can sit flush against each other
	-- without reporting themselves as blocked
	local probe = Building.BrickSize * 0.85
	local hits = workspace:GetPartBoundsInBox(CFrame.new(position), probe, params)

	for _, part in ipairs(hits) do
		if part.CanCollide then
			return false   -- a wall, another brick, or someone standing there
		end
	end
	return true
end

local function place(player: Player, requested: Vector3)
	if typeof(requested) ~= "Vector3" then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	-- snap it ourselves rather than trusting the number we were sent
	local position = Building.snap(requested)

	if (position - root.Position).Magnitude > Building.Reach then
		return
	end
	if not Building.withinArena(position) then
		return
	end
	if (placedBy[player] or 0) >= Building.MaxPerPlayer then
		return
	end
	if not cellIsFree(position) then
		return
	end

	local brick = Instance.new("Part")
	brick.Name = "BuiltBrick"
	brick.Anchored = true
	brick.Size = Building.BrickSize
	brick.Position = position
	brick.Color = Building.colourFor(player.UserId)
	brick.Material = Enum.Material.Brick
	brick.TopSurface = Enum.SurfaceType.Smooth
	brick.BottomSurface = Enum.SurfaceType.Smooth
	brick:SetAttribute("Health", Building.Health)
	brick:SetAttribute("MaxHealth", Building.Health)
	brick:SetAttribute("Builder", player.UserId)
	brick.Parent = builds

	CollectionService:AddTag(brick, Building.Tag)

	placedBy[player] = (placedBy[player] or 0) + 1

	local stats = player:FindFirstChild("leaderstats")
	local built = stats and stats:FindFirstChild("Built")
	if built and built:IsA("IntValue") then
		built.Value += 1
	end

	-- freeing the cell again when it is smashed keeps the cap honest:
	-- your budget is bricks standing, not bricks ever placed
	brick.Destroying:Connect(function()
		placedBy[player] = math.max(0, (placedBy[player] or 1) - 1)
	end)
end

placeBrick.OnServerEvent:Connect(function(player, requested)
	local ok, err = pcall(place, player, requested)
	if not ok then
		warn("place failed: " .. tostring(err))
	end
end)

-- ===========================================================
--  The trowel
-- ===========================================================

local function buildTrowel(player: Player): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Trowel"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Place bricks"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 2.6, 0.6)
	handle.Color = Color3.fromRGB(118, 82, 52)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(1.8, 0.2, 2.6)
	blade.Color = Building.colourFor(player.UserId)
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = handle.CFrame * CFrame.new(0, -1.5, 0)
	blade.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.Parent = handle

	tool.Grip = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(90), 0, 0)
	return tool
end

local function giveTrowel(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			local existing = container:FindFirstChild("Trowel")
			if existing then
				existing:Destroy()
			end
		end
	end

	buildTrowel(player).Parent = backpack
end

Players.PlayerAdded:Connect(function(player)
	placedBy[player] = 0

	player.CharacterAdded:Connect(function()
		task.wait(0.35)   -- after the hammer and gear have settled
		giveTrowel(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	placedBy[player] = nil
end)

print(("Building ready: %d x %d x %d bricks, %d per player")
	:format(Building.BrickSize.X, Building.BrickSize.Y, Building.BrickSize.Z,
		Building.MaxPerPlayer))
