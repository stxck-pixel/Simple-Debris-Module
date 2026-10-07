-- Connected Discord-GitHub
local DebrisModule = {}

-- Service
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Config
local DEFAULT_CONFIG = {
	Radius = 12, -- the radius of the debris
	DebrisCount = 18, -- how many parts in the debris
	FadeOutTime = 1.5, -- fade out tween so the debris disappears smoothly
	Lifetime = 4, -- how much the debris stays before its destroyed/cleared
	SpawnTime = 0.4, -- tween that rises up the debris from the ground/wall

	RaycastUp = 50,
	RaycastDown = 200
} -- < we are using a config so the module is more flexible

-- get the visual folder so temporary debris is kept separate from gameplay objects
local function getVisualsFolder()
	local world = Workspace:FindFirstChild("World") -- Look for the World folder that contains the hierarchy
	if not world then return nil end -- stop if the World folder doesnt exist, since the Visuals folder cant be accessed without it

	return world:FindFirstChild("Visuals") -- return the Visuals folder where temporary debris effects are stored
end

-- get map folder / so the debris only creates matching parts from the folder map
local function getMap()
	local world = Workspace:FindFirstChild("World") -- look for the world map inside the workspace
	if not world then return nil end -- if world was not found then cancel

	return world:FindFirstChild("Map") -- return to map folder where the Map for the game is stored into
end

-- matches the parts from the map to the debris parts (color, material, etc)
local function createMatchingPartFromSource(sourcePart: BasePart)
	local newPart

	if sourcePart:IsA("WedgePart") then -- if source part is a wedge part then
		newPart = Instance.new("WedgePart") -- create wedge part
		
	elseif sourcePart:IsA("Part") and sourcePart.Shape == Enum.PartType.Ball then -- or if the source part is a ball
		newPart = Instance.new("Part") -- create part
		newPart.Shape = Enum.PartType.Ball  -- set shape of part to ball

	else
		newPart = Instance.new("Part") -- if source part is normal part then create normal part
	end

	newPart.Material = sourcePart.Material
	newPart.Color = sourcePart.Color
	newPart.Reflectance = sourcePart.Reflectance
	newPart.Transparency = 1

	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CanTouch = false
	newPart.CanQuery = false
	newPart.CastShadow = false

	return newPart
end


local function applyRandomSize(part: BasePart, size: Vector3)

	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then -- if part is a normal part and the part shape is ball then
		local diameter = math.max(size.X, size.Y, size.Z) -- diameter = part's X,Y,Z size

		part.Size = Vector3.new(
			diameter,
			diameter,
			diameter
		)  -- create new size for part

	else
		part.Size = size
	end
end


local function createDebrisChunk(origin, angleDeg, config, baseCFrame)

	local visuals = getVisualsFolder()
	if not visuals then return end

	local map = getMap()
	if not map then return end

	-- gets the folders from above
	
	local angle = math.rad(angleDeg) -- convert degrees into radians

	local radiusJitter = math.random(-3, 3) -- sets a random distance using math.random between the parts

	local arcInwardTilt = math.rad(-math.random(20, 40)) -- randomly chooses a random angle between -20 & -40

	local distance = config.Radius + radiusJitter -- final distance 

	local offset = Vector3.new(   --calculates the offset around a circle
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)

	local basePosition = baseCFrame and baseCFrame.Position or origin  -- decides the center position

	local finalOffsetPosition = basePosition + offset -- final position

	local rayOrigin = finalOffsetPosition + Vector3.new(0, config.RaycastUp, 0)
	local rayDirection = Vector3.new(0, -config.RaycastDown, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist  -- whitelist raycast so that only the objects from the folder "Map" are read
	params.FilterDescendantsInstances = { map }

	local result = Workspace:Raycast(rayOrigin, rayDirection, params) -- shoots the raycast

	if not result or not result.Instance then -- if it misses stop the function 
		return
	end

	local hitPos = result.Position
	local sourcePart = result.Instance

	local debris = createMatchingPartFromSource(sourcePart)

	applyRandomSize(debris, Vector3.new(  --uses the applyrandomsize function from above, so the parts have different dimensions
		math.random(3, 6),
		math.random(1, 2),
		math.random(2, 5)
		))

	local directionToOrigin = (origin - hitPos) -- the final direction to center

	if directionToOrigin.Magnitude <= 0 then -- if it spawned exatcly in the center, it will stop the function
		return
	end

	directionToOrigin = directionToOrigin.Unit -- turns it into a unit vector

	local lookCFrame = CFrame.new(hitPos, hitPos + directionToOrigin) -- face toward the center using cframe

	local arcRotation = CFrame.Angles(arcInwardTilt, 0, 0) -- creates an inward tilt

	debris.CFrame = lookCFrame * arcRotation -- combines the lookCframe and the ArcRotation

	debris.Position = debris.Position - Vector3.new(0, debris.Size.Y + 1, 0) -- this moves the structure undeground

	debris.Parent = visuals 

	local riseTween = TweenService:Create(  -- rise animation, changes the transparency 1 > 0, and the position from underground to ground level, creating a smooth rising animation
		debris,
		TweenInfo.new(
			config.SpawnTime,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		),
		{
			Transparency = 0,
			Position = debris.Position + Vector3.new(0, debris.Size.Y + 1, 0)
		}
	)

	riseTween:Play() -- plays the rise anim

	task.delay(config.Lifetime, function()  -- the function waits however long the Lifetime specifies

		if not debris or not debris.Parent then
			return
		end   -- verifies if the debris still exists

		local fade = TweenService:Create(  -- fade out animation, changes the transparency 0 > 1, duration of the fade out is specified by the FadeOutTime config
			debris,
			TweenInfo.new(config.FadeOutTime),
			{
				Transparency = 1
			}
		)

		fade:Play() -- plays the fade out anim 

		task.delay(config.FadeOutTime, function()

			if debris and debris.Parent then
				debris:Destroy()
			end

		end)
	end)
end


function DebrisModule:CreateDebris(originPosition, customConfig, baseCFrame)

	local config = table.clone(DEFAULT_CONFIG)

	if customConfig then 
		for k, v in pairs(customConfig) do
			config[k] = v
		end
	end    
	

	for i = 1, config.DebrisCount do -- this loop runs for every debris created using the config.DebrisCount

		local angle =
			(360 / config.DebrisCount) * i
			+ math.random(-10, 10)

		createDebrisChunk(
			originPosition,
			angle,
			config,
			baseCFrame 
		)
	end
end

return DebrisModule
