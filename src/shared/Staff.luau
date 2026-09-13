--!strict
-- ===========================================================
--  Staff
--
--  Who gets the fly toggle. Matched on user id where known,
--  because usernames can be changed and ids cannot.
--
--  Never matched on display name: anyone can set their display
--  name to anything, so it would hand flying to whoever typed
--  the right word into their profile.
-- ===========================================================

local Staff = {}

Staff.Flyers = {
	{ name = "Jeb_the5th", userId = 8637994222 },
	{ name = "EnderAshy", userId = 4173612045 },
}

-- Staff get flying and everything in both shops for free. Matched on
-- user id only, for the same reason flying is.
function Staff.isStaff(player: Player): boolean
	for _, entry in ipairs(Staff.Flyers) do
		if entry.userId and entry.userId == player.UserId then
			return true
		end
	end
	return false
end

Staff.Fly = {
	Speed      = 80,    -- studs per second
	Force      = 1e6,
	Responsiveness = 60,
}

return Staff
