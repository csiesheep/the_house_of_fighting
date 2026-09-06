--!strict
-- ===========================================================
--  CityBuild
--
--  Everything that puts parts on a block: towers, trees, cars
--  and street furniture.
--
--  Split out of City.server.luau because that script had grown
--  into layout, geometry, collapse tracking and rebuild
--  scheduling all at once. This half only makes things; the
--  server script decides where and what happens to them.
-- ===========================================================

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CityConfig  = require(ReplicatedStorage:WaitForChild("CityConfig"))
local HouseConfig = require(ReplicatedStorage:WaitForChild("HouseConfig"))

local BRICK  = CityConfig.Brick
local RULES  = CityConfig.TowerRules
local STREET = CityConfig.Street
local TREE   = CityConfig.Tree
local STREET_TREE = CityConfig.StreetTree
local CAR    = CityConfig.Car
local TAG    = HouseConfig.BreakableTag

local CityBuild = {}

-- ===========================================================
--  Parts
-- ===========================================================

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame,
	colour: Color3, material: Enum.Material, health: number?, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	if health then
		part:SetAttribute("Health", health)
		part:SetAttribute("MaxHealth", health)
		CollectionService:AddTag(part, TAG)
	end
	return part
end

CityBuild.makePart = makePart

-- ===========================================================
--  Towers
-- ===========================================================

-- Which bricks on this course are glass, given the style.
local function isWindow(style, course: number, index: number, courses: number): boolean
	local mode = style.windows

	if mode == "bands" then
		return course % (style.bandEvery or 3) == 0 and course > 1

	elseif mode == "grid" then
		return course > 1 and course % 2 == 0 and index % 2 == 1

	elseif mode == "columns" then
		return course > 1 and index % 3 == 2

	elseif mode == "shop" then
		return course <= 2

	end
	return false
end

local function buildRoof(folder: Instance, style, centre: Vector3, top: number,
	width: number, depth: number)
	local kind = style.roof

	if kind == "parapet" then
		makePart(folder, "Roof", Vector3.new(width + 2, BRICK.Size.Y, depth + 2),
			CFrame.new(centre + Vector3.new(0, top + 1, 0)),
			style.accent, Enum.Material.Concrete, BRICK.Health)
		-- a raised lip, so the roofline is not a bare edge
		for _, side in ipairs({ Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }) do
			makePart(folder, "Parapet", Vector3.new(width + 2, 2, 1),
				CFrame.new(centre + Vector3.new(0, top + 3, 0) + side * (depth / 2 + 0.5)),
				style.accent, Enum.Material.Concrete, BRICK.Health)
		end
		for _, side in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) }) do
			makePart(folder, "Parapet", Vector3.new(1, 2, depth + 2),
				CFrame.new(centre + Vector3.new(0, top + 3, 0) + side * (width / 2 + 0.5)),
				style.accent, Enum.Material.Concrete, BRICK.Health)
		end

	elseif kind == "antenna" then
		makePart(folder, "Roof", Vector3.new(width + 2, 2, depth + 2),
			CFrame.new(centre + Vector3.new(0, top + 1, 0)),
			style.accent, Enum.Material.Metal, BRICK.Health)
		makePart(folder, "Mast", Vector3.new(0.6, 18, 0.6),
			CFrame.new(centre + Vector3.new(0, top + 11, 0)),
			Color3.fromRGB(180, 186, 196), Enum.Material.Metal, BRICK.Health)
		local light = makePart(folder, "Beacon", Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(centre + Vector3.new(0, top + 20, 0)),
			Color3.fromRGB(255, 96, 88), Enum.Material.Neon, BRICK.Health)
		light.Shape = Enum.PartType.Ball

	elseif kind == "watertower" then
		makePart(folder, "Roof", Vector3.new(width + 2, 2, depth + 2),
			CFrame.new(centre + Vector3.new(0, top + 1, 0)),
			style.accent, Enum.Material.Concrete, BRICK.Health)
		for _, corner in ipairs({
			Vector3.new(-3, 0, -3), Vector3.new(3, 0, -3),
			Vector3.new(-3, 0, 3), Vector3.new(3, 0, 3),
		}) do
			makePart(folder, "Leg", Vector3.new(0.6, 7, 0.6),
				CFrame.new(centre + corner + Vector3.new(0, top + 5.5, 0)),
				Color3.fromRGB(88, 82, 76), Enum.Material.Metal, BRICK.Health)
		end
		local tank = makePart(folder, "Tank", Vector3.new(9, 8, 8),
			CFrame.new(centre + Vector3.new(0, top + 13, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(122, 104, 84), Enum.Material.Wood, BRICK.Health)
		tank.Shape = Enum.PartType.Cylinder

	elseif kind == "stepped" then
		local w, d, y = width, depth, top
		for step = 1, 3 do
			w, d = w * 0.7, d * 0.7
			makePart(folder, "Step", Vector3.new(w + 2, 4, d + 2),
				CFrame.new(centre + Vector3.new(0, y + 2, 0)),
				step % 2 == 0 and style.accent or style.wall,
				Enum.Material.Concrete, BRICK.Health)
			y += 4
		end
		makePart(folder, "Spire", Vector3.new(1.2, 10, 1.2),
			CFrame.new(centre + Vector3.new(0, y + 5, 0)),
			style.accent, Enum.Material.Metal, BRICK.Health)

	elseif kind == "awning" then
		makePart(folder, "Roof", Vector3.new(width + 2, 2, depth + 2),
			CFrame.new(centre + Vector3.new(0, top + 1, 0)),
			style.accent, Enum.Material.Concrete, BRICK.Health)
		-- a striped canopy over the shopfront
		for i = 0, 5 do
			makePart(folder, "Awning", Vector3.new(width / 6, 0.6, 6),
				CFrame.new(centre + Vector3.new(
					-width / 2 + width / 12 + i * (width / 6), 7, -depth / 2 - 2.4))
					* CFrame.Angles(math.rad(-18), 0, 0),
				i % 2 == 0 and style.accent or Color3.fromRGB(238, 232, 220),
				Enum.Material.Fabric, BRICK.Health)
		end
	end
end

-- Returns the folder and the set of ground floor bricks, which is
-- what the collapse watcher counts down.
function CityBuild.tower(parent: Instance, centre: Vector3, style, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = style.name:gsub("%s", "")

	-- coarser panels for the tall ones, so a skyscraper is not a
	-- thousand parts on its own
	local scale = style.brickScale or 1
	local brick = BRICK.Size * scale
	local width = style.widthBricks * brick.X
	local depth = style.depthBricks * brick.X
	local base: { [BasePart]: boolean } = {}
	local baseTotal = 0

	for course = 1, style.courses do
		local y = (course - 0.5) * brick.Y

		local function place(size: Vector3, at: Vector3, index: number)
			local window = isWindow(style, course, index, style.courses)
			local colour = style.wall
			local material = Enum.Material.Concrete
			local transparency = 0

			if window then
				local lit = rng:NextNumber() < RULES.LitChance
				colour = lit and RULES.LitGlass or RULES.Glass
				material = lit and Enum.Material.Neon or Enum.Material.Glass
				transparency = lit and 0 or 0.4
			elseif course % 4 == 1 then
				colour = style.accent      -- a banding course, for texture
			end

			local part = makePart(folder, "Brick", size, CFrame.new(at),
				colour, material, BRICK.Health, transparency)

			if course <= RULES.BaseCourses then
				base[part] = true
				baseTotal += 1
			end
		end

		for side = -1, 1, 2 do
			for col = 1, style.widthBricks do
				place(brick,
					centre + Vector3.new(-width / 2 + (col - 0.5) * brick.X, y, side * depth / 2),
					col)
			end
			for row = 1, style.depthBricks do
				place(Vector3.new(brick.Z, brick.Y, brick.X),
					centre + Vector3.new(side * width / 2, y, -depth / 2 + (row - 0.5) * brick.X),
					row)
			end
		end
	end

	buildRoof(folder, style, centre, style.courses * brick.Y, width, depth)
	folder.Parent = parent

	return folder, base, baseTotal
end

-- ===========================================================
--  Street furniture
-- ===========================================================

function CityBuild.lamp(parent: Instance, base: Vector3, facing: number)
	local spec = STREET.Lamp
	local turn = CFrame.Angles(0, facing, 0)

	makePart(parent, "LampBase", Vector3.new(2, 0.6, 2),
		CFrame.new(base + Vector3.new(0, 0.3, 0)),
		spec.Post, Enum.Material.Metal, STREET.Health)

	makePart(parent, "LampPost", Vector3.new(0.7, spec.PostHeight, 0.7),
		CFrame.new(base + Vector3.new(0, spec.PostHeight / 2, 0)),
		spec.Post, Enum.Material.Metal, STREET.Health)

	local armEnd = CFrame.new(base + Vector3.new(0, spec.PostHeight, 0)) * turn
		* CFrame.new(0, 0, -spec.ArmLength / 2)

	makePart(parent, "LampArm", Vector3.new(0.5, 0.5, spec.ArmLength),
		armEnd, spec.Post, Enum.Material.Metal, STREET.Health)

	local headAt = CFrame.new(base + Vector3.new(0, spec.PostHeight - 0.6, 0)) * turn
		* CFrame.new(0, 0, -spec.ArmLength)

	makePart(parent, "LampShade", Vector3.new(2.6, 0.7, 1.8), headAt,
		spec.Shade, Enum.Material.Metal, STREET.Health)

	-- Neon reads as lit and costs nothing. A PointLight per lamp would
	-- be a hundred dynamic lights across the map, which Roblox's voxel
	-- lighting struggles with long before that -- and in a place that
	-- is permanently daytime, for almost nothing visible.
	makePart(parent, "LampBulb", Vector3.new(2.2, 0.4, 1.4),
		headAt * CFrame.new(0, -0.5, 0),
		spec.Bulb, Enum.Material.Neon, STREET.Health)
end

function CityBuild.planter(parent: Instance, base: Vector3, rng: Random)
	local spec = STREET.Planter

	makePart(parent, "Pot", Vector3.new(5, 3, 5),
		CFrame.new(base + Vector3.new(0, 1.5, 0)),
		spec.Pot, Enum.Material.Slate, STREET.Health)

	makePart(parent, "Soil", Vector3.new(4.2, 0.6, 4.2),
		CFrame.new(base + Vector3.new(0, 3.1, 0)),
		spec.Soil, Enum.Material.Ground, STREET.Health)

	for i = 1, 3 do
		local bush = makePart(parent, "Bloom", Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(base + Vector3.new(
				rng:NextNumber(-1.1, 1.1), 4.2 + rng:NextNumber(0, 0.8),
				rng:NextNumber(-1.1, 1.1))),
			spec.Bush[rng:NextInteger(1, #spec.Bush)], Enum.Material.Grass, STREET.Health)
		bush.Shape = Enum.PartType.Ball
	end
end

function CityBuild.bench(parent: Instance, base: Vector3, facing: number)
	local spec = STREET.Bench
	local turn = CFrame.Angles(0, facing, 0)
	local at = CFrame.new(base) * turn

	makePart(parent, "BenchSeat", Vector3.new(9, 0.5, 2.6),
		at * CFrame.new(0, 2.2, 0), spec.Slats, Enum.Material.WoodPlanks, STREET.Health)
	makePart(parent, "BenchBack", Vector3.new(9, 2.4, 0.5),
		at * CFrame.new(0, 3.4, -1.1), spec.Slats, Enum.Material.WoodPlanks, STREET.Health)

	for _, x in ipairs({ -3.8, 3.8 }) do
		makePart(parent, "BenchLeg", Vector3.new(0.5, 2.2, 2.4),
			at * CFrame.new(x, 1.1, 0), spec.Legs, Enum.Material.Metal, STREET.Health)
	end
end

function CityBuild.bin(parent: Instance, base: Vector3)
	local spec = STREET.Bin

	local body = makePart(parent, "Bin", Vector3.new(3, 4, 3),
		CFrame.new(base + Vector3.new(0, 2, 0)),
		spec.Body, Enum.Material.Metal, STREET.Health)
	body.Shape = Enum.PartType.Cylinder
	body.CFrame = CFrame.new(base + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))

	makePart(parent, "BinLid", Vector3.new(3.4, 0.5, 3.4),
		CFrame.new(base + Vector3.new(0, 4.2, 0)),
		spec.Lid, Enum.Material.Metal, STREET.Health)
end

function CityBuild.trafficLight(parent: Instance, base: Vector3, facing: number)
	local spec = STREET.TrafficLight
	local turn = CFrame.Angles(0, facing, 0)

	makePart(parent, "SignalPost", Vector3.new(0.8, spec.Height, 0.8),
		CFrame.new(base + Vector3.new(0, spec.Height / 2, 0)),
		spec.Post, Enum.Material.Metal, STREET.Health)

	local armAt = CFrame.new(base + Vector3.new(0, spec.Height, 0)) * turn
	makePart(parent, "SignalArm", Vector3.new(0.5, 0.5, spec.ArmLength),
		armAt * CFrame.new(0, 0, -spec.ArmLength / 2),
		spec.Post, Enum.Material.Metal, STREET.Health)

	local headAt = armAt * CFrame.new(0, -1.6, -spec.ArmLength)
	makePart(parent, "SignalBox", Vector3.new(2, 5.4, 1.6), headAt,
		Color3.fromRGB(38, 40, 44), Enum.Material.Metal, STREET.Health)

	local lamps = {
		{ Color3.fromRGB(232, 64, 56), 1.8 },
		{ Color3.fromRGB(240, 196, 64), 0 },
		{ Color3.fromRGB(88, 214, 110), -1.8 },
	}
	for _, lamp in ipairs(lamps) do
		local bulb = makePart(parent, "SignalLamp", Vector3.new(1.2, 1.2, 0.4),
			headAt * CFrame.new(0, lamp[2], -0.9),
			lamp[1], Enum.Material.Neon, STREET.Health)
		bulb.Shape = Enum.PartType.Ball
	end
end

-- ===========================================================
--  Trees and cars
-- ===========================================================

function CityBuild.tree(parent: Instance, base: Vector3, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Tree"

	local lean = CFrame.Angles(
		math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(0, 360)),
		math.rad(rng:NextNumber(-4, 4)))

	local trunk = makePart(model, "Trunk",
		Vector3.new(TREE.TrunkWidth, TREE.TrunkHeight, TREE.TrunkWidth),
		CFrame.new(base + Vector3.new(0, TREE.TrunkHeight / 2, 0)) * lean,
		TREE.Trunk, Enum.Material.Wood)
	CollectionService:AddTag(trunk, "Choppable")

	for layer = 1, TREE.CanopyLayers do
		local spread = 13 - (layer - 1) * 3
		local leaf = makePart(model, "Leaves", Vector3.new(spread, 5, spread),
			CFrame.new(base + Vector3.new(0, TREE.TrunkHeight - 1 + (layer - 1) * 3.4, 0)) * lean,
			TREE.Leaves[rng:NextInteger(1, #TREE.Leaves)], Enum.Material.Grass)
		leaf.CanCollide = false
		CollectionService:AddTag(leaf, "Choppable")
	end

	model.PrimaryPart = trunk
	model.Parent = parent
	return model
end

-- A smaller tree for the pavements, in a soil bed. Same Choppable tag
-- as a park tree, so the axe treats them identically.
function CityBuild.streetTree(parent: Instance, base: Vector3, rng: Random): Model
	local spec = STREET_TREE
	local model = Instance.new("Model")
	model.Name = "StreetTree"

	makePart(model, "Bed", Vector3.new(spec.BedSize, 0.8, spec.BedSize),
		CFrame.new(base + Vector3.new(0, 0.4, 0)),
		spec.Bed, Enum.Material.Ground, STREET.Health)

	local lean = CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0)

	local trunk = makePart(model, "Trunk",
		Vector3.new(spec.TrunkWidth, spec.TrunkHeight, spec.TrunkWidth),
		CFrame.new(base + Vector3.new(0, spec.TrunkHeight / 2, 0)) * lean,
		TREE.Trunk, Enum.Material.Wood)
	CollectionService:AddTag(trunk, "Choppable")

	for layer = 1, spec.CanopyLayers do
		local spread = spec.CanopySpread - (layer - 1) * 2
		local leaf = makePart(model, "Leaves", Vector3.new(spread, 4, spread),
			CFrame.new(base + Vector3.new(0, spec.TrunkHeight - 0.5 + (layer - 1) * 2.6, 0))
				* lean,
			TREE.Leaves[rng:NextInteger(1, #TREE.Leaves)], Enum.Material.Grass)
		leaf.CanCollide = false
		CollectionService:AddTag(leaf, "Choppable")
	end

	model.PrimaryPart = trunk
	model.Parent = parent
	return model
end

function CityBuild.car(parent: Instance, base: Vector3, facing: number, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Car"

	local paint = CAR.Palette[rng:NextInteger(1, #CAR.Palette)]
	local turn = CFrame.Angles(0, facing, 0)

	local body = makePart(model, "Body", CAR.Body,
		CFrame.new(base + Vector3.new(0, 2.6, 0)) * turn,
		paint, Enum.Material.Metal, CAR.BrickHealth)

	makePart(model, "Cabin", CAR.Cabin,
		CFrame.new(base + Vector3.new(0, 5.1, 0)) * turn,
		paint:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Glass,
		CAR.BrickHealth, 0.35)

	for _, offset in ipairs({
		Vector3.new(-3.4, 1.4, 4.4), Vector3.new(3.4, 1.4, 4.4),
		Vector3.new(-3.4, 1.4, -4.4), Vector3.new(3.4, 1.4, -4.4),
	}) do
		local wheel = makePart(model, "Wheel", CAR.Wheel,
			CFrame.new(base) * turn * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(34, 34, 38), Enum.Material.Rubber, CAR.BrickHealth)
		wheel.Shape = Enum.PartType.Cylinder
	end

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

return CityBuild
