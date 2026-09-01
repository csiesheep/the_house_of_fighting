--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- coils and carpets
--
--  Hands out whatever gear a player owns. Ownership is read
--  from the Pass_<key> attributes that Shop.server.luau sets,
--  so this script never touches MarketplaceService either.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local TweenService      = game:GetService("TweenService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Breaking   = require(ReplicatedStorage:WaitForChild("Breaking"))

local GEAR = ShopConfig.Gear

-- ===========================================================
--  A coil looks like a coil
-- ===========================================================

local function makeCoilTool(name: string, colour: Color3): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(3.4, 1.6, 1.6)
	handle.Color = colour
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Parent = tool

	tool.Grip = CFrame.Angles(0, math.rad(90), 0)
	return tool
end

-- ===========================================================
--  Speed and Gravity: passive while held
-- ===========================================================

local function wireBodyCoil(tool: Tool, spec)
	local function humanoidOf(): Humanoid?
		local character = tool.Parent
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	tool.Equipped:Connect(function()
		local humanoid = humanoidOf()
		if not humanoid then return end
		if spec.walkSpeed then humanoid.WalkSpeed = spec.walkSpeed end
		if spec.jumpPower then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = spec.jumpPower
		end
	end)

	tool.Unequipped:Connect(function()
		-- tool.Parent is the backpack by now, so find the humanoid
		-- through the player rather than the tool
		local player = Players:GetPlayerFromCharacter(tool.Parent)
			or Players:FindFirstChild(tool:GetAttribute("Owner") :: string or "")
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		humanoid.WalkSpeed = 16
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
	end)
end

-- ===========================================================
--  Fusion Coil: drop it, run
-- ===========================================================

local lastFusion: { [Player]: number } = {}

local function dropFusionCoil(player: Player)
	local spec = GEAR.FusionCoil
	local now = os.clock()
	if lastFusion[player] and now - lastFusion[player] < spec.cooldown then
		return
	end
	lastFusion[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	local coil = Instance.new("Part")
	coil.Name = "LiveFusionCoil"
	coil.Shape = Enum.PartType.Ball
	coil.Size = Vector3.new(4, 4, 4)
	coil.Color = spec.colour
	coil.Material = Enum.Material.Neon
	coil.Anchored = false
	coil.CanCollide = true
	coil.Position = root.Position + root.CFrame.LookVector * 6 + Vector3.new(0, 2, 0)
	coil.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = spec.colour
	light.Range = 18
	light.Brightness = 3
	light.Parent = coil

	-- pulse faster and faster, so the fuse is readable without a UI
	task.spawn(function()
		local elapsed = 0
		while elapsed < spec.fuse and coil.Parent do
			local step = math.max(0.08, 0.5 * (1 - elapsed / spec.fuse))
			coil.Transparency = 0.45
			TweenService:Create(coil, TweenInfo.new(step), { Transparency = 0 }):Play()
			task.wait(step)
			elapsed += step
		end

		if not coil.Parent then
			return
		end

		local centre = coil.Position
		local destroyed = Breaking.explode(centre, spec.radius, spec.knockback, player)

		local flash = Instance.new("Explosion")
		flash.Position = centre
		flash.BlastRadius = spec.radius
		flash.BlastPressure = 0        -- Breaking already moved the debris
		flash.DestroyJointRadiusPercent = 0
		flash.Parent = workspace

		coil:Destroy()
		print(("%s detonated a fusion coil: %d parts"):format(player.Name, destroyed))
	end)

	Debris:AddItem(coil, spec.fuse + 3)
end

-- ===========================================================
--  Rainbow Carpet: lay down a platform
-- ===========================================================

local carpets: { [Player]: { BasePart } } = {}
local lastCarpet: { [Player]: number } = {}

local function layCarpet(player: Player)
	local spec = GEAR.RainbowCarpet
	local now = os.clock()
	if lastCarpet[player] and now - lastCarpet[player] < spec.cooldown then
		return
	end
	lastCarpet[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	local panel = Instance.new("Part")
	panel.Name = "RainbowCarpet"
	panel.Anchored = true
	panel.CanCollide = true
	panel.Size = spec.size
	panel.Position = root.Position - Vector3.new(0, 3.2, 0)
	panel.Material = Enum.Material.Neon
	panel.Transparency = 0.15
	panel.TopSurface = Enum.SurfaceType.Smooth
	panel.Parent = workspace

	-- cycle the hue so it reads as a rainbow rather than a coloured slab
	task.spawn(function()
		local hue = 0
		while panel.Parent do
			hue = (hue + 0.01) % 1
			panel.Color = Color3.fromHSV(hue, 0.85, 1)
			task.wait(0.05)
		end
	end)

	local owned = carpets[player]
	if not owned then
		owned = {}
		carpets[player] = owned
	end
	table.insert(owned, panel)

	while #owned > spec.maxPanels do
		local oldest = table.remove(owned, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	Debris:AddItem(panel, spec.lifetime)
end

-- ===========================================================
--  Handing gear out
-- ===========================================================

local function buildGear(player: Player, key: string): Tool?
	local spec = GEAR[key]
	if not spec then
		return nil
	end

	if key == "SpeedCoil" or key == "GravityCoil" then
		local tool = makeCoilTool(spec.toolName, spec.colour)
		tool:SetAttribute("Owner", player.Name)
		wireBodyCoil(tool, spec)
		return tool
	end

	if key == "FusionCoil" then
		local tool = makeCoilTool(spec.toolName, spec.colour)
		tool.ToolTip = "Drop a live coil"
		tool.Activated:Connect(function()
			dropFusionCoil(player)
		end)
		return tool
	end

	if key == "RainbowCarpet" then
		local tool = Instance.new("Tool")
		tool.Name = spec.toolName
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		tool.ToolTip = "Lay a platform"

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(3, 0.4, 2)
		handle.Color = Color3.fromRGB(255, 96, 160)
		handle.Material = Enum.Material.Neon
		handle.CanCollide = false
		handle.Parent = tool

		tool.Activated:Connect(function()
			layCarpet(player)
		end)
		return tool
	end

	return nil
end

local GEAR_KEYS = { "SpeedCoil", "GravityCoil", "FusionCoil", "RainbowCarpet" }

local function refreshGear(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	for _, key in ipairs(GEAR_KEYS) do
		local spec = GEAR[key]
		local owned = player:GetAttribute("Pass_" .. key) == true

		local existing = backpack:FindFirstChild(spec.toolName)
			or (player.Character and player.Character:FindFirstChild(spec.toolName))

		if owned and not existing then
			local tool = buildGear(player, key)
			if tool then
				tool.Parent = backpack
			end
		elseif not owned and existing then
			existing:Destroy()
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)   -- Backpack is emptied on respawn; wait it out
		refreshGear(player)
	end)

	for _, key in ipairs(GEAR_KEYS) do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
			if player.Character then
				refreshGear(player)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	carpets[player] = nil
	lastFusion[player] = nil
	lastCarpet[player] = nil
end)

print("Gear ready: speed coil, gravity coil, fusion coil, rainbow carpet")
