--!strict
-- ===========================================================
--  Building
--
--  Shared rules for placing bricks. The client uses these to
--  show you where a brick will land; the server uses the exact
--  same ones to decide whether to allow it.
--
--  That is the point of putting them here: the preview cannot
--  drift from what is permitted, and the server never has to
--  trust the position the client asked for.
-- ===========================================================

local Building = {}

Building.BrickSize = Vector3.new(4, 2, 4)
Building.Health    = 2       -- same as house brick: your wall is no tougher
Building.Reach     = 40      -- studs you can place from
Building.MaxPerPlayer = 250

-- Grid is anchored to the arena floor, so a placed brick sits flush
-- with the ground and stacks in the same 2 stud courses the houses use.
Building.Origin = Vector3.new(0, 24, 0)

-- keeps building inside the walls
Building.MaxRadius = 60

Building.Tag = "Breakable"
Building.FolderName = "PlayerBuilds"

-- Snap a world position to the nearest legal brick centre.
function Building.snap(position: Vector3): Vector3
	local size = Building.BrickSize
	local origin = Building.Origin
	local rel = position - origin

	return origin + Vector3.new(
		math.round(rel.X / size.X) * size.X,
		math.floor(rel.Y / size.Y) * size.Y + size.Y / 2,
		math.round(rel.Z / size.Z) * size.Z
	)
end

function Building.isAligned(position: Vector3): boolean
	return (position - Building.snap(position)).Magnitude < 0.05
end

-- Where a brick goes given what you are looking at: one cell out from
-- the face you hit, so bricks stack on top and butt against sides.
function Building.placementFrom(result: RaycastResult): Vector3
	local nudge = math.min(Building.BrickSize.X, Building.BrickSize.Y, Building.BrickSize.Z) * 0.5
	return Building.snap(result.Position + result.Normal * nudge)
end

-- A colour per builder, so you can see who put what up.
function Building.colourFor(userId: number): Color3
	local hue = (userId % 360) / 360
	return Color3.fromHSV(hue, 0.45, 0.85)
end

function Building.withinArena(position: Vector3): boolean
	local flat = Vector3.new(
		position.X - Building.Origin.X,
		0,
		position.Z - Building.Origin.Z
	)
	return flat.Magnitude <= Building.MaxRadius
		and position.Y >= Building.Origin.Y
		and position.Y <= Building.Origin.Y + 120
end

return Building
