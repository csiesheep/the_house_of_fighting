--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- market gear
--
--  Builds and hands out whatever a player has bought with
--  coins. Ownership is read from Owns_<key> attributes, which
--  only Market.server.luau sets, so this script never touches
--  coins or prices.
--
--  Same seam as the Robux gear: buy it there, wear it here.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local TweenService      = game:GetService("TweenService")

local MarketConfig = require(ReplicatedStorage:WaitForChild("MarketConfig"))
local Breaking     = require(ReplicatedStorage:WaitForChild("Breaking"))

local SPECS = MarketConfig.Specs
local cooldowns: { [Player]: { [string]: number } } = {}

local function offCooldown(player: Player, key: string, seconds: number): boolean
	local perPlayer = cooldowns[player]
	if not perPlayer then
		perPlayer = {}
		cooldowns[player] = perPlayer
	end
	local now = os.clock()
	if perPlayer[key] and now - perPlayer[key] < seconds then
		return false
	end
	perPlayer[key] = now
	return true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return (root and root:IsA("BasePart")) and root or nil
end

-- ===========================================================
--  Knife
-- ===========================================================

-- Nearest living player in front of you, within range.
local function targetInFront(player: Player, range: number): (Humanoid?, Player?)
	local root = rootOf(player)
	if not root then
		return nil, nil
	end

	local best, bestPlayer, bestDistance = nil, nil, math.huge

	for _, other in ipairs(Players:GetPlayers()) do
		if other == player then
			continue
		end
		local character = other.Character
		local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (otherRoot and otherRoot:IsA("BasePart") and humanoid and humanoid.Health > 0) then
			continue
		end

		local delta = otherRoot.Position - root.Position
		local distance = delta.Magnitude
		if distance > range or distance < 0.1 then
			continue
		end
		-- must be roughly in front, not behind you
		if root.CFrame.LookVector:Dot(delta.Unit) < 0.5 then
			continue
		end
		if distance < bestDistance then
			best, bestPlayer, bestDistance = humanoid, other, distance
		end
	end

	return best, bestPlayer
end

local function stab(player: Player)
	local spec = SPECS.Knife
	if not offCooldown(player, "Knife", spec.cooldown) then
		return
	end

	local humanoid, victim = targetInFront(player, spec.range)
	if humanoid and victim then
		humanoid:TakeDamage(spec.damage)
		print(("%s knifed %s for %d"):format(player.Name, victim.Name, spec.damage))
	end
end

-- ===========================================================
--  Dynamite
-- ===========================================================

local function throwDynamite(player: Player)
	local spec = SPECS.Dynamite
	if not offCooldown(player, "Dynamite", spec.cooldown) then
		return
	end

	local root = rootOf(player)
	if not root then
		return
	end

	local stick = Instance.new("Part")
	stick.Name = "Dynamite"
	stick.Size = Vector3.new(1.2, 3, 1.2)
	stick.Color = spec.colour
	stick.Material = Enum.Material.Neon
	stick.CanCollide = true
	stick.CFrame = CFrame.new(root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
	stick.Parent = workspace
	stick.AssemblyLinearVelocity = root.CFrame.LookVector * 70 + Vector3.new(0, 32, 0)

	local light = Instance.new("PointLight")
	light.Color = spec.colour
	light.Range = 14
	light.Parent = stick

	task.delay(spec.fuse, function()
		if not stick.Parent then
			return
		end
		local centre = stick.Position

		Breaking.explode(centre, spec.radius, spec.knockback, player)

		-- catch anyone standing in it
		for _, other in ipairs(Players:GetPlayers()) do
			local character = other.Character
			local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if otherRoot and otherRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local distance = (otherRoot.Position - centre).Magnitude
				if distance <= spec.radius then
					-- full damage at the centre, tapering to nothing at the edge
					local falloff = 1 - distance / spec.radius
					humanoid:TakeDamage(spec.damage * falloff)
				end
			end
		end

		local flash = Instance.new("Explosion")
		flash.Position = centre
		flash.BlastRadius = spec.radius
		flash.BlastPressure = 0        -- Breaking already moved the debris
		flash.DestroyJointRadiusPercent = 0
		flash.Parent = workspace

		stick:Destroy()
	end)

	Debris:AddItem(stick, spec.fuse + 2)
end

-- ===========================================================
--  Grapple Hook
-- ===========================================================

local function grapple(player: Player)
	local spec = SPECS.GrappleHook
	if not offCooldown(player, "GrappleHook", spec.cooldown) then
		return
	end

	local character = player.Character
	local root = rootOf(player)
	if not (character and root) then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local result = workspace:Raycast(origin, root.CFrame.LookVector * spec.range, params)
	if not result then
		return
	end

	-- a visible line, so it reads as a grapple rather than teleporting
	local rope = Instance.new("Part")
	rope.Anchored = true
	rope.CanCollide = false
	rope.CanQuery = false
	rope.Material = Enum.Material.Neon
	rope.Color = spec.colour
	local span = (result.Position - origin)
	rope.Size = Vector3.new(0.2, 0.2, span.Magnitude)
	rope.CFrame = CFrame.lookAt(origin + span / 2, result.Position)
	rope.Parent = workspace
	TweenService:Create(rope, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	Debris:AddItem(rope, 0.4)

	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local pull = Instance.new("LinearVelocity")
	pull.Attachment0 = attachment
	pull.MaxForce = math.huge
	pull.VectorVelocity = span.Unit * spec.speed
	pull.RelativeTo = Enum.ActuatorRelativeTo.World
	pull.Parent = root

	-- long enough to travel, short enough not to fling you past
	local flight = math.clamp(span.Magnitude / spec.speed, 0.15, 1.2)
	task.delay(flight, function()
		pull:Destroy()
		attachment:Destroy()
	end)
end

-- ===========================================================
--  Jetpack: hold to climb
-- ===========================================================

local thrusters: { [Player]: { attachment: Attachment, force: LinearVelocity } } = {}

local function setFlames(tool: Tool?, on: boolean)
	if not tool then
		return
	end
	for _, piece in ipairs(tool:GetChildren()) do
		if piece:IsA("BasePart") and piece.Name == "Flame" then
			piece.Transparency = on and 0.2 or 1
		end
	end
end

local function stopThrust(player: Player, tool: Tool?)
	setFlames(tool, false)

	local rig = thrusters[player]
	if not rig then
		return
	end
	thrusters[player] = nil
	if rig.force then rig.force:Destroy() end
	if rig.attachment then rig.attachment:Destroy() end
end

local function startThrust(player: Player, tool: Tool?)
	local spec = SPECS.Jetpack
	local root = rootOf(player)
	if not root then
		return
	end
	stopThrust(player, tool)
	setFlames(tool, true)

	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	-- Line mode constrains only the vertical axis, so you still walk and
	-- steer normally in the air instead of being locked to one velocity.
	local force = Instance.new("LinearVelocity")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	force.LineDirection = Vector3.yAxis
	force.LineVelocity = spec.rise
	force.MaxAxesForce = Vector3.new(0, math.huge, 0)
	force.Parent = root

	thrusters[player] = { attachment = attachment, force = force }
end

-- ===========================================================
--  Tools
-- ===========================================================

-- ===========================================================
--  Skins
--
--  Every item is a small welded model rather than one coloured
--  block, so you can tell what you are holding at a glance and
--  so other players can tell what is about to hit them.
-- ===========================================================

local function newTool(name: string, tip: string, handleSize: Vector3,
	colour: Color3, material: Enum.Material): (Tool, Part)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = tip

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = handleSize
	handle.Color = colour
	handle.Material = material
	handle.CanCollide = false
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	return tool, handle
end

-- A welded extra piece, positioned relative to the handle.
local function addPiece(tool: Tool, handle: Part, name: string, size: Vector3,
	offset: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = colour
	piece.Material = material
	piece.CanCollide = false
	piece.Massless = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		piece.Shape = shape
	end
	piece.CFrame = handle.CFrame * offset
	piece.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = handle

	return piece
end

local STEEL   = Color3.fromRGB(198, 204, 214)
local DARK    = Color3.fromRGB(46, 44, 50)
local LEATHER = Color3.fromRGB(72, 52, 40)

local function buildItem(player: Player, key: string): Tool?
	local spec = SPECS[key]
	if not spec then
		return nil
	end

	-- ---- Knife: grip, guard, tapered blade -------------------------
	if key == "Knife" then
		local tool, handle = newTool(spec.toolName, "Stab whoever is in front of you",
			Vector3.new(0.32, 1.5, 0.5), LEATHER, Enum.Material.Fabric)

		addPiece(tool, handle, "Pommel", Vector3.new(0.5, 0.25, 0.6),
			CFrame.new(0, -0.85, 0), DARK, Enum.Material.Metal)
		addPiece(tool, handle, "Guard", Vector3.new(1.1, 0.22, 0.7),
			CFrame.new(0, 0.8, 0), DARK, Enum.Material.Metal)
		addPiece(tool, handle, "Blade", Vector3.new(0.16, 2.4, 0.62),
			CFrame.new(0, 2.05, 0), STEEL, Enum.Material.Metal)
		addPiece(tool, handle, "Point", Vector3.new(0.14, 0.5, 0.3),
			CFrame.new(0, 3.4, 0.12), STEEL, Enum.Material.Metal)

		tool.Grip = CFrame.new(0, 0, 0)
		tool.Activated:Connect(function()
			stab(player)
		end)
		return tool
	end

	-- ---- Dynamite: bundled sticks, tape, a lit fuse ----------------
	if key == "Dynamite" then
		local tool, handle = newTool(spec.toolName, "Throw it and back off",
			Vector3.new(0.8, 2.4, 0.8), spec.colour, Enum.Material.Slate)

		addPiece(tool, handle, "Stick", Vector3.new(0.8, 2.4, 0.8),
			CFrame.new(0.75, -0.15, 0.1), spec.colour, Enum.Material.Slate)
		addPiece(tool, handle, "Stick", Vector3.new(0.8, 2.4, 0.8),
			CFrame.new(0.38, 0.1, -0.65), spec.colour, Enum.Material.Slate)
		addPiece(tool, handle, "Tape", Vector3.new(2.1, 0.45, 1.9),
			CFrame.new(0.38, 0.35, -0.2), Color3.fromRGB(44, 40, 38), Enum.Material.Fabric)
		addPiece(tool, handle, "Fuse", Vector3.new(0.14, 0.9, 0.14),
			CFrame.new(0, 1.55, 0), Color3.fromRGB(180, 168, 140), Enum.Material.Fabric)

		local spark = addPiece(tool, handle, "Spark", Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(0, 2.05, 0), Color3.fromRGB(255, 214, 120),
			Enum.Material.Neon, Enum.PartType.Ball)

		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 190, 90)
		glow.Range = 8
		glow.Brightness = 2
		glow.Parent = spark

		tool.Grip = CFrame.new(0, -0.4, 0)
		tool.Activated:Connect(function()
			throwDynamite(player)
		end)
		return tool
	end

	-- ---- Speed Boots: boot, rubber sole, winged heel ---------------
	if key == "SpeedBoots" then
		local tool, handle = newTool(spec.toolName, "Hold to run",
			Vector3.new(1.5, 1.6, 2.6), LEATHER, Enum.Material.Fabric)

		addPiece(tool, handle, "Sole", Vector3.new(1.7, 0.4, 3),
			CFrame.new(0, -0.9, 0.1), DARK, Enum.Material.Rubber)
		addPiece(tool, handle, "Cuff", Vector3.new(1.7, 0.5, 2.2),
			CFrame.new(0, 0.9, -0.2), spec.colour, Enum.Material.Fabric)
		for _, side in ipairs({ -1, 1 }) do
			addPiece(tool, handle, "Wing", Vector3.new(0.2, 1.1, 1.6),
				CFrame.new(side * 0.85, 0.55, -1) * CFrame.Angles(0, 0, math.rad(side * 22)),
				spec.colour, Enum.Material.Neon)
		end

		tool.Grip = CFrame.new(0, -0.6, 0)
		tool.Equipped:Connect(function()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = spec.walkSpeed
			end
		end)
		tool.Unequipped:Connect(function()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 16
			end
		end)
		return tool
	end

	-- ---- Grapple Hook: launcher body, barrel, claw -----------------
	if key == "GrappleHook" then
		local tool, handle = newTool(spec.toolName, "Fire at anything in sight",
			Vector3.new(0.8, 1.8, 1.2), DARK, Enum.Material.Metal)

		addPiece(tool, handle, "Body", Vector3.new(1, 1, 2.6),
			CFrame.new(0, 1.1, -0.4), Color3.fromRGB(70, 74, 84), Enum.Material.Metal)
		addPiece(tool, handle, "Barrel", Vector3.new(0.55, 0.55, 2.2),
			CFrame.new(0, 1.1, -2), STEEL, Enum.Material.Metal)
		addPiece(tool, handle, "Drum", Vector3.new(1.5, 1.5, 0.7),
			CFrame.new(0, 1.1, 0.7) * CFrame.Angles(0, math.rad(90), 0),
			spec.colour, Enum.Material.Neon, Enum.PartType.Cylinder)
		for _, side in ipairs({ -1, 1 }) do
			addPiece(tool, handle, "Claw", Vector3.new(0.18, 0.9, 0.5),
				CFrame.new(side * 0.35, 1.1, -3.1)
					* CFrame.Angles(math.rad(20), 0, math.rad(side * 25)),
				STEEL, Enum.Material.Metal)
		end

		tool.Grip = CFrame.new(0, -0.5, 0)
		tool.Activated:Connect(function()
			grapple(player)
		end)
		return tool
	end

	-- ---- Jetpack: twin tanks, nozzles, flame while thrusting -------
	if key == "Jetpack" then
		local tool, handle = newTool(spec.toolName, "Hold to climb",
			Vector3.new(2.6, 2.8, 0.6), Color3.fromRGB(88, 92, 104), Enum.Material.Metal)

		for _, side in ipairs({ -1, 1 }) do
			addPiece(tool, handle, "Tank", Vector3.new(2.4, 1.1, 1.1),
				CFrame.new(side * 0.85, 0.2, 0.9) * CFrame.Angles(0, 0, math.rad(90)),
				spec.colour, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPiece(tool, handle, "Nozzle", Vector3.new(0.7, 0.7, 0.7),
				CFrame.new(side * 0.85, -1.5, 0.9), DARK, Enum.Material.Metal)

			local flame = addPiece(tool, handle, "Flame", Vector3.new(0.6, 1.8, 0.6),
				CFrame.new(side * 0.85, -2.6, 0.9), Color3.fromRGB(255, 168, 60),
				Enum.Material.Neon)
			flame.Transparency = 1
		end

		addPiece(tool, handle, "Strap", Vector3.new(2.9, 0.4, 0.4),
			CFrame.new(0, 0.9, -0.2), DARK, Enum.Material.Fabric)

		tool.Grip = CFrame.new(0, 0, 0.9)
		tool.Activated:Connect(function()
			startThrust(player, tool)
		end)
		tool.Deactivated:Connect(function()
			stopThrust(player, tool)
		end)
		tool.Unequipped:Connect(function()
			stopThrust(player, tool)
		end)
		return tool
	end

	return nil
end

-- ===========================================================
--  Handing it all out
-- ===========================================================

local KEYS = { "Knife", "Dynamite", "SpeedBoots", "GrappleHook", "Jetpack" }

local function applyArmour(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if player:GetAttribute("Owns_BodyArmour") == true then
		humanoid.MaxHealth = SPECS.BodyArmour.maxHealth
		humanoid.Health = humanoid.MaxHealth
	end
end

local function refresh(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	for _, key in ipairs(KEYS) do
		local spec = SPECS[key]
		local owned = player:GetAttribute("Owns_" .. key) == true
		local existing = backpack:FindFirstChild(spec.toolName)
			or (player.Character and player.Character:FindFirstChild(spec.toolName))

		if owned and not existing then
			local tool = buildItem(player, key)
			if tool then
				tool.Parent = backpack
			end
		elseif not owned and existing then
			existing:Destroy()
		end
	end

	applyArmour(player)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		stopThrust(player, nil)
		task.wait(0.4)   -- after hammer, gear and trowel have settled
		refresh(player)
	end)

	for _, key in ipairs(KEYS) do
		player:GetAttributeChangedSignal("Owns_" .. key):Connect(function()
			if player.Character then
				refresh(player)
			end
		end)
	end

	player:GetAttributeChangedSignal("Owns_BodyArmour"):Connect(function()
		applyArmour(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	stopThrust(player, nil)
	cooldowns[player] = nil
end)

print("Market gear ready: knife, dynamite, boots, grapple, armour, jetpack")
