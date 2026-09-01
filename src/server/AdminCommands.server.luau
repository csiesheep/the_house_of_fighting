--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- admin commands
--
--  Gated on the Admin attribute, which only Shop.server.luau
--  ever sets. This script never touches MarketplaceService.
--
--  There is deliberately no /night: the place is meant to stay
--  bright, and a command that darkens it would undo that.
--
--  Every command affects the world or the caller. None of them
--  reach into another player -- a paid item that lets a buyer
--  freeze or kick strangers stops being a toy and becomes a
--  griefing tool. Easy to add if you decide you want it.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local ShopConfig  = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))
local Breaking    = require(ReplicatedStorage:WaitForChild("Breaking"))

local ADMIN = ShopConfig.Admin

local function tell(player: Player, message: string)
	-- keeps feedback in the caller's own output rather than broadcasting
	print(("[admin] %s: %s"):format(player.Name, message))
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return (root and root:IsA("BasePart")) and root or nil
end

local commands: { [string]: (Player, { string }) -> () } = {}

commands["help"] = function(player)
	local names = {}
	for name in pairs(commands) do
		table.insert(names, "/" .. name)
	end
	table.sort(names)
	tell(player, table.concat(names, "  "))
end

commands["nuke"] = function(player)
	local root = rootOf(player)
	local from = root and root.Position or HouseConfig.House.Origin
	local count = Breaking.flatten(from, 120)
	tell(player, ("flattened %d bricks"):format(count))
end

commands["rebuild"] = function(player)
	local signal = ServerStorage:FindFirstChild("RebuildHouse")
	if signal and signal:IsA("BindableEvent") then
		signal:Fire()
		tell(player, "house rebuilt")
	else
		tell(player, "rebuild signal missing")
	end
end

commands["speed"] = function(player, args)
	local humanoid = humanoidOf(player)
	if not humanoid then return end
	local value = math.clamp(tonumber(args[1]) or 16, ADMIN.MinSpeed, ADMIN.MaxSpeed)
	humanoid.WalkSpeed = value
	tell(player, "walkspeed " .. value)
end

commands["jump"] = function(player, args)
	local humanoid = humanoidOf(player)
	if not humanoid then return end
	local value = math.clamp(tonumber(args[1]) or 50, ADMIN.MinJump, ADMIN.MaxJump)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = value
	tell(player, "jumppower " .. value)
end

commands["heal"] = function(player)
	local humanoid = humanoidOf(player)
	if not humanoid then return end
	humanoid.Health = humanoid.MaxHealth
	tell(player, "healed")
end

commands["reset"] = function(player)
	local humanoid = humanoidOf(player)
	if not humanoid then return end
	humanoid.WalkSpeed = 16
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50
	tell(player, "speed and jump back to default")
end

-- ===========================================================

local function handle(player: Player, message: string)
	if player:GetAttribute("Admin") ~= true then
		return
	end
	if string.sub(message, 1, 1) ~= "/" then
		return
	end

	local parts = string.split(string.lower(string.sub(message, 2)), " ")
	local name = table.remove(parts, 1)
	if not name then
		return
	end

	local command = commands[name]
	if command then
		local ok, err = pcall(command, player, parts)
		if not ok then
			warn(("admin command /%s failed: %s"):format(name, tostring(err)))
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		handle(player, message)
	end)
end)

print("Admin commands loaded (gated on the Admin attribute)")
