--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- the full leaderboard
--
--  The boards show the top ten. This is the whole hundred,
--  opened by the prompt at whichever board you walked up to.
-- ===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LeaderboardConfig"))
local Theme  = require(ReplicatedStorage:WaitForChild("Theme"))

local remotes   = ReplicatedStorage:WaitForChild("LeaderboardRemotes")
local openBoard = remotes:WaitForChild("OpenBoard")
local boardData = remotes:WaitForChild("BoardData")

local player = Players.LocalPlayer

local byKey: { [string]: any } = {}
for _, category in ipairs(Config.Categories) do
	byKey[category.key] = category
end

local gui = Instance.new("ScreenGui")
gui.Name = "LeaderboardUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 420, 0, 520)
panel.Position = UDim2.new(0.5, -210, 0.5, -260)
panel.BackgroundColor3 = Theme.Panel
panel.Visible = false
panel.Parent = gui
round(panel, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 30)
title.Position = UDim2.new(0, 18, 0, 14)
title.BackgroundTransparency = 1
title.TextColor3 = Theme.Ink
title.Font = Enum.Font.GothamBlack
title.TextSize = 21
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "LEADERBOARD"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -70, 0, 18)
subtitle.Position = UDim2.new(0, 18, 0, 43)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = Theme.Muted
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = ""
subtitle.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.Position = UDim2.new(1, -48, 0, 16)
closeButton.BackgroundColor3 = Theme.Control
closeButton.TextColor3 = Theme.Ink
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "X"
closeButton.Parent = panel
round(closeButton, 8)

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -28, 1, -92)
list.Position = UDim2.new(0, 14, 0, 78)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function comma(value: number): string
	local text = tostring(math.floor(value))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clear()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function addRow(entry, category, index: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 30)
	row.BackgroundColor3 = Theme.Row
	-- your own line stands out from the rest
	row.BackgroundTransparency = (entry.name == player.Name) and 0 or 0.45
	row.LayoutOrder = index
	row.Parent = list
	round(row, 6)

	local rank = Instance.new("TextLabel")
	rank.Size = UDim2.new(0, 44, 1, 0)
	rank.Position = UDim2.new(0, 8, 0, 0)
	rank.BackgroundTransparency = 1
	rank.TextColor3 = Theme.Muted
	rank.Font = Enum.Font.GothamBold
	rank.TextSize = 14
	rank.TextXAlignment = Enum.TextXAlignment.Left
	rank.Text = "#" .. entry.rank
	rank.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -180, 1, 0)
	name.Position = UDim2.new(0, 54, 0, 0)
	name.BackgroundTransparency = 1
	name.TextColor3 = Theme.Ink
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = entry.name
	name.Parent = row

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(0, 118, 1, 0)
	value.Position = UDim2.new(1, -126, 0, 0)
	value.BackgroundTransparency = 1
	value.TextColor3 = category.colour
	value.Font = Enum.Font.GothamBold
	value.TextSize = 14
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = comma(entry.value) .. category.suffix
	value.Parent = row
end

openBoard.OnClientEvent:Connect(function(key: string)
	local category = byKey[key]
	if not category then
		return
	end

	title.Text = category.title
	subtitle.Text = "loading..."
	clear()
	panel.Visible = true

	task.spawn(function()
		local ok, entries = pcall(function()
			return boardData:InvokeServer(key)
		end)

		if not (ok and type(entries) == "table") then
			subtitle.Text = "could not load"
			return
		end

		if #entries == 0 then
			subtitle.Text = "no scores recorded yet"
			return
		end

		subtitle.Text = ("top %d across every server"):format(#entries)
		for index, entry in ipairs(entries) do
			addRow(entry, category, index)
		end
	end)
end)
