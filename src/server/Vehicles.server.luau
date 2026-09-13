--!strict
-- ===========================================================
--  THE HOUSE OF FIGHTING -- getting in cars
--
--  Every car the city builds is tagged Drivable. Walk up, press
--  E, and it stops being scenery: its parts are welded into one
--  physics assembly, a seat goes in, and you are put in it.
--
--  The server owns getting in and out. Driving itself happens
--  on the driver's client (Driving.client.luau), because the
--  driver is handed network ownership of the car -- steering a
--  car through a round trip to the server feels like steering
--  it through mud.
--
--  Traffic cars can be taken too. Taking one sets Taken on the
--  model, and the traffic loop stops moving anything with that
--  attribute. Neither script knows how the other works.
-- ===========================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CityConfig = require(ReplicatedStorage:WaitForChild("CityConfig"))

local DRIVE = CityConfig.Driving
local CAR   = CityConfig.Car

-- ===========================================================
--  Turning a model into a vehicle
-- ===========================================================

type Rig = {
	seat: VehicleSeat,
	body: BasePart,
	linear: LinearVelocity,
	angular: AngularVelocity,
}

local rigs: { [Model]: Rig } = {}
local lastRunOver: { [Humanoid]: number } = {}

local function rigFor(model: Model): Rig?
	local existing = rigs[model]
	if existing and existing.seat.Parent then
		return existing
	end

	local body = model.PrimaryPart
	if not (body and body.Parent) then
		return nil
	end

	-- Weld everything to the body while it is all still anchored and
	-- in place, then release it. Unanchoring first would let the
	-- pieces start falling before the welds existed.
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= body then
			if part.Name == "Wheel" or part.Name == "Cabin" then
				part.CanCollide = false   -- the chassis below does the colliding
			end
			part.Massless = true

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = body
		end
	end

	-- A hidden box level with the road. Without it the car rests on
	-- its wheels, which reach slightly below the tarmac, and it would
	-- sit tilted or jitter against the ground.
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(CAR.Body.X - 0.4, 1, CAR.Body.Z - 1)
	chassis.CFrame = body.CFrame * CFrame.new(0, -2.05, 0)
	chassis.Transparency = 1
	chassis.CanCollide = true
	chassis.Massless = true
	-- low friction, so the car is steered by its velocity constraint
	-- rather than dragged about by the road
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 100, 1)
	chassis.Parent = model

	local chassisWeld = Instance.new("WeldConstraint")
	chassisWeld.Part0 = body
	chassisWeld.Part1 = chassis
	chassisWeld.Parent = body

	-- set low, so you sit down inside the car instead of on its roof
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.Size = Vector3.new(2.4, 0.4, 2.4)
	seat.CFrame = body.CFrame * CFrame.new(0, 0.5, 1.2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0      -- we drive it ourselves; no hinge motors here
	seat.Torque = 0
	seat.Parent = model

	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = body
	seatWeld.Part1 = seat
	seatWeld.Parent = body

	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = body

	-- Horizontal force only: gravity stays free, so the car settles
	-- onto the road and drops off edges instead of hovering.
	local linear = Instance.new("LinearVelocity")
	linear.Name = "DriveVelocity"
	linear.Attachment0 = attachment
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	linear.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linear.MaxAxesForce = Vector3.new(DRIVE.Force, 0, DRIVE.Force)
	linear.VectorVelocity = Vector3.zero
	linear.Parent = body

	-- Yaw is what steering sets; pitch and roll are held at zero, which
	-- is also what keeps the car from flipping on a kerb.
	local angular = Instance.new("AngularVelocity")
	angular.Name = "DriveTurn"
	angular.Attachment0 = attachment
	angular.RelativeTo = Enum.ActuatorRelativeTo.World
	angular.MaxTorque = DRIVE.Torque
	angular.AngularVelocity = Vector3.zero
	angular.Parent = body

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	local rig: Rig = { seat = seat, body = body, linear = linear, angular = angular }
	rigs[model] = rig

	local prompt = body:FindFirstChild("DrivePrompt")

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)

		if driver then
			model:SetAttribute("DriverId", driver.UserId)
			pcall(function()
				body:SetNetworkOwner(driver)
			end)
		else
			model:SetAttribute("DriverId", nil)
			-- Ownership back to the server, whose copies of the
			-- constraints were never changed from zero: the car
			-- brakes to a stop on its own.
			linear.VectorVelocity = Vector3.zero
			angular.AngularVelocity = Vector3.zero
			pcall(function()
				body:SetNetworkOwner(nil)
			end)
		end

		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = driver == nil
		end
	end)

	-- Running people over. The driver is excluded by name, since a
	-- seated character overlaps its own car.
	body.Touched:Connect(function(hit)
		local driverId = model:GetAttribute("DriverId")
		if not driverId then
			return
		end
		if body.AssemblyLinearVelocity.Magnitude < DRIVE.RunOverSpeed then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local victim = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (victim and humanoid and humanoid.Health > 0) or victim.UserId == driverId then
			return
		end

		local now = os.clock()
		if lastRunOver[humanoid] and now - lastRunOver[humanoid] < DRIVE.RunOverCooldown then
			return
		end
		lastRunOver[humanoid] = now
		humanoid:TakeDamage(DRIVE.RunOverDamage)
	end)

	return rig
end

-- ===========================================================
--  Getting in
-- ===========================================================

local function enter(player: Player, model: Model)
	if model:GetAttribute("DriverId") then
		return   -- somebody is already in it
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) or humanoid.SeatPart then
		return
	end

	-- claim it before rigging, so the traffic loop stops moving it in
	-- the same frame rather than dragging it out from under the weld
	model:SetAttribute("Taken", true)

	local rig = rigFor(model)
	if not rig then
		return
	end
	rig.seat:Sit(humanoid)
end

local function attachPrompt(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local body = model.PrimaryPart
	if not body or body:FindFirstChild("DrivePrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Car"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = DRIVE.PromptHold
	prompt.MaxActivationDistance = DRIVE.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	prompt.Triggered:Connect(function(player)
		enter(player, model)
	end)
end

CollectionService:GetInstanceAddedSignal("Drivable"):Connect(attachPrompt)
for _, model in ipairs(CollectionService:GetTagged("Drivable")) do
	attachPrompt(model)
end

CollectionService:GetInstanceRemovedSignal("Drivable"):Connect(function(model)
	if model:IsA("Model") then
		rigs[model] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		lastRunOver[humanoid] = nil
	end
end)

print("Vehicles ready: press E at any car to drive it, E again to get out")
