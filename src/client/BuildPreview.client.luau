--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- build preview
--
--  A ghost brick showing where the next one lands, and the
--  click that asks for it.
--
--  The ghost uses the same Building rules the server validates
--  against, so what you see is what you are allowed. It turns
--  red when the server would refuse -- out of reach, outside
--  the walls, or a cell already occupied.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local Building = require(ReplicatedStorage:WaitForChild("Building"))
local remotes    = ReplicatedStorage:WaitForChild("BuildRemotes")
local placeBrick = remotes:WaitForChild("PlaceBrick")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local OK  = Color3.fromRGB(120, 220, 140)
local BAD = Color3.fromRGB(226, 96, 84)

local ghost = Instance.new("Part")
ghost.Name = "BuildGhost"
ghost.Anchored = true
ghost.CanCollide = false
ghost.CanQuery = false
ghost.CanTouch = false
ghost.Transparency = 0.55
ghost.Size = Building.BrickSize
ghost.Material = Enum.Material.Neon
ghost.Color = OK
ghost.Parent = workspace

local outline = Instance.new("SelectionBox")
outline.Adornee = ghost
outline.LineThickness = 0.04
outline.Color3 = OK
outline.Parent = ghost

local equipped = false
local target: Vector3? = nil

local function characterParts(): { Instance }
	local character = player.Character
	return character and { character, ghost } or { ghost }
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (equipped and root and root:IsA("BasePart")) then
		ghost.Transparency = 1
		outline.Visible = false
		target = nil
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterParts()

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * (Building.Reach + 20)
	local result = workspace:Raycast(origin, direction, params)

	if not result then
		ghost.Transparency = 1
		outline.Visible = false
		target = nil
		return
	end

	local position = Building.placementFrom(result)
	ghost.Position = position
	ghost.Transparency = 0.55
	outline.Visible = true
	target = position

	-- mirror the server's rules so the ghost never promises something
	-- that will be refused
	local reachable = (position - root.Position).Magnitude <= Building.Reach
	local allowed = reachable and Building.withinArena(position)

	ghost.Color = allowed and OK or BAD
	outline.Color3 = allowed and OK or BAD
	if not allowed then
		target = nil
	end
end

RunService.RenderStepped:Connect(update)

-- ===========================================================
--  Equipping and clicking
-- ===========================================================

local function watch(character: Model)
	local function refresh()
		local tool = character:FindFirstChild("Trowel")
		equipped = tool ~= nil
	end
	character.ChildAdded:Connect(refresh)
	character.ChildRemoved:Connect(refresh)
	refresh()
end

if player.Character then
	watch(player.Character)
end
player.CharacterAdded:Connect(watch)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not equipped then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if target then
		placeBrick:FireServer(target)
	end
end)
