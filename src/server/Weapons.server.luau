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

local function stopThrust(player: Player)
	local rig = thrusters[player]
	if not rig then
		return
	end
	thrusters[player] = nil
	if rig.force then rig.force:Destroy() end
	if rig.attachment then rig.attachment:Destroy() end
end

local function startThrust(player: Player)
	local spec = SPECS.Jetpack
	local root = rootOf(player)
	if not root then
		return
	end
	stopThrust(player)

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

local function basicTool(name: string, size: Vector3, colour: Color3, material: Enum.Material,
	tip: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = tip

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = colour
	handle.Material = material
	handle.CanCollide = false
	handle.Parent = tool

	return tool
end

local function buildItem(player: Player, key: string): Tool?
	local spec = SPECS[key]
	if not spec then
		return nil
	end

	if key == "Knife" then
		local tool = basicTool(spec.toolName, Vector3.new(0.35, 3.2, 0.9), spec.colour,
			Enum.Material.Metal, "Stab whoever is in front of you")
		tool.Grip = CFrame.new(0, -1.1, 0)
		tool.Activated:Connect(function()
			stab(player)
		end)
		return tool
	end

	if key == "Dynamite" then
		local tool = basicTool(spec.toolName, Vector3.new(1.2, 3, 1.2), spec.colour,
			Enum.Material.Neon, "Throw it and back off")
		tool.Activated:Connect(function()
			throwDynamite(player)
		end)
		return tool
	end

	if key == "SpeedBoots" then
		local tool = basicTool(spec.toolName, Vector3.new(2.2, 1, 3.2), spec.colour,
			Enum.Material.Fabric, "Hold to run")
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

	if key == "GrappleHook" then
		local tool = basicTool(spec.toolName, Vector3.new(1, 2.4, 2.6), spec.colour,
			Enum.Material.Metal, "Fire at anything in sight")
		tool.Activated:Connect(function()
			grapple(player)
		end)
		return tool
	end

	if key == "Jetpack" then
		local tool = basicTool(spec.toolName, Vector3.new(2.4, 3.2, 1.4), spec.colour,
			Enum.Material.Metal, "Hold to climb")
		tool.Activated:Connect(function()
			startThrust(player)
		end)
		tool.Deactivated:Connect(function()
			stopThrust(player)
		end)
		tool.Unequipped:Connect(function()
			stopThrust(player)
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
		stopThrust(player)
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
	stopThrust(player)
	cooldowns[player] = nil
end)

print("Market gear ready: knife, dynamite, boots, grapple, armour, jetpack")
