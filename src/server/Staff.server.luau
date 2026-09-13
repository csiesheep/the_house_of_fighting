--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- staff permissions
--
--  Decides who may fly and says so with a CanFly attribute.
--  The client only offers the toggle when that attribute is
--  set, and only the server ever sets it.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Staff = require(ReplicatedStorage:WaitForChild("Staff"))

local allowedIds: { [number]: boolean } = {}
local allowedNames: { [string]: boolean } = {}

for _, entry in ipairs(Staff.Flyers) do
	if entry.userId then
		allowedIds[entry.userId] = true
	end
	if entry.name then
		allowedNames[string.lower(entry.name)] = true
	end
end

-- Resolve any name without an id, so a typo shows up in Output rather
-- than as a friend pressing Ctrl+F and wondering why nothing happens.
task.spawn(function()
	for _, entry in ipairs(Staff.Flyers) do
		if not entry.userId and entry.name then
			local ok, id = pcall(function()
				return Players:GetUserIdFromNameAsync(entry.name)
			end)
			if ok and type(id) == "number" then
				allowedIds[id] = true
				print(("Staff: %s resolved to user id %d"):format(entry.name, id))
			else
				warn(("Staff: no Roblox account called %q -- check the username in Staff.luau")
					:format(entry.name))
			end
		end
	end
end)

local function grant(player: Player)
	local allowed = allowedIds[player.UserId] == true
		or allowedNames[string.lower(player.Name)] == true
	player:SetAttribute("CanFly", allowed)
	if allowed then
		print(("Staff: %s can fly (Ctrl+F / Cmd+F)"):format(player.Name))
	end
end

Players.PlayerAdded:Connect(grant)
for _, player in ipairs(Players:GetPlayers()) do
	grant(player)
end
