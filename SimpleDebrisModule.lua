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
}

-- get visual folder / so we stay clean we will put the debris inside a visual folder
local function getVisualsFolder()
	local world = Workspace:FindFirstChild("World")
	if not world then return nil end

	return world:FindFirstChild("Visuals")
end

-- get map folder / so the debris only creates matching parts from the folder map
local function getMap()
	local world = Workspace:FindFirstChild("World")
	if not world then return nil end

	return world:FindFirstChild("Map")
end

-- matches the parts from the map to the debris parts (color, material, etc)
local function createMatchingPartFromSource(sourcePart: BasePart)
	local newPart

	if sourcePart:IsA("WedgePart") then
		newPart = Instance.new("WedgePart")

	elseif sourcePart:IsA("Part") and sourcePart.Shape == Enum.PartType.Ball then
		newPart = Instance.new("Part")
		newPart.Shape = Enum.PartType.Ball

	else
		newPart = Instance.new("Part")
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

-- applies a random size to the parts from debris (used for both ground n wall debris)
local function applyRandomSize(part: BasePart, size: Vector3)

	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
		local diameter = math.max(size.X, size.Y, size.Z)

		part.Size = Vector3.new(
			diameter,
			diameter,
			diameter
		)

	else
		part.Size = size
	end
end

-- creates the debris chunks/parts (used for both ground n wall debris)
local function createDebrisChunk(origin, angleDeg, config, baseCFrame)

	local visuals = getVisualsFolder()
	if not visuals then return end

	local map = getMap()
	if not map then return end

	-- gets the folders from above
	
	local angle = math.rad(angleDeg)

	local radiusJitter = math.random(-3, 3)

	local arcInwardTilt = math.rad(-math.random(20, 40))

	local distance = config.Radius + radiusJitter

	local offset = Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)

	local basePosition = baseCFrame and baseCFrame.Position or origin

	local finalOffsetPosition = basePosition + offset

	local rayOrigin = finalOffsetPosition + Vector3.new(0, config.RaycastUp, 0)
	local rayDirection = Vector3.new(0, -config.RaycastDown, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = { map }

	local result = Workspace:Raycast(rayOrigin, rayDirection, params)

	if not result or not result.Instance then
		return
	end

	local hitPos = result.Position
	local sourcePart = result.Instance

	local debris = createMatchingPartFromSource(sourcePart)

	applyRandomSize(debris, Vector3.new(
		math.random(3, 6),
		math.random(1, 2),
		math.random(2, 5)
		))

	local directionToOrigin = (origin - hitPos)

	if directionToOrigin.Magnitude <= 0 then
		return
	end

	directionToOrigin = directionToOrigin.Unit

	local lookCFrame = CFrame.new(hitPos, hitPos + directionToOrigin)

	local arcRotation = CFrame.Angles(arcInwardTilt, 0, 0)

	debris.CFrame = lookCFrame * arcRotation

	debris.Position = debris.Position - Vector3.new(0, debris.Size.Y + 1, 0)

	debris.Parent = visuals

	local riseTween = TweenService:Create(
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

	riseTween:Play()

	task.delay(config.Lifetime, function()

		if not debris or not debris.Parent then
			return
		end

		local fade = TweenService:Create(
			debris,
			TweenInfo.new(config.FadeOutTime),
			{
				Transparency = 1
			}
		)

		fade:Play()

		task.delay(config.FadeOutTime, function()

			if debris and debris.Parent then
				debris:Destroy()
			end

		end)
	end)
end


-- creates the ACTUAL debris impact
function DebrisModule:CreateDebris(originPosition, customConfig, baseCFrame)

	local config = table.clone(DEFAULT_CONFIG)

	if customConfig then
		for k, v in pairs(customConfig) do
			config[k] = v
		end
	end

	for i = 1, config.DebrisCount do

		local angle =
			(360 / config.DebrisCount) * i
			+ math.random(-10, 10)

		createDebrisChunk(
			originPosition,
			angle,
			config,
			baseCFrame -- < uses the function from above B)
		)
	end
end

-- the same debris impact but for walls , not much to explain just the same function as the other one but for walls
function DebrisModule:CreateWallDebris(originPosition, normalVector, customConfig)

	local config = table.clone(DEFAULT_CONFIG)

	if customConfig then
		for k, v in pairs(customConfig) do
			config[k] = v
		end
	end

	local visuals = getVisualsFolder()
	if not visuals then return end

	local map = getMap()
	if not map then return end

	-- again getting the folders !!

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = { map }

	local upVector = Vector3.yAxis

	if math.abs(normalVector:Dot(upVector)) > 0.9 then
		upVector = Vector3.xAxis
	end

	local right = normalVector:Cross(upVector)

	if right.Magnitude <= 0 then
		return
	end

	right = right.Unit

	local up = right:Cross(normalVector)

	if up.Magnitude <= 0 then
		return
	end

	up = up.Unit

	for i = 1, config.DebrisCount do

		local angle = math.rad(
			(360 / config.DebrisCount) * i
				+ math.random(-10, 10)
		)

		local radiusJitter = math.random(-3, 3)
		local distance = config.Radius + radiusJitter

		local tilt = math.rad(-math.random(20, 40))

		local offset =
			right * math.cos(angle) * distance
			+ up * math.sin(angle) * distance

		local startPos = originPosition + offset

		local rayOrigin = startPos + normalVector * config.RaycastUp
		local rayDirection = -normalVector * config.RaycastDown

		local result = Workspace:Raycast(rayOrigin, rayDirection, params)

		if not result or not result.Instance then
			continue
		end

		local hitPos = result.Position
		local sourcePart = result.Instance

		local debris = createMatchingPartFromSource(sourcePart)

		applyRandomSize(debris, Vector3.new(
			math.random(3, 6),
			math.random(1, 2),
			math.random(2, 5)
			))

		local forward = (originPosition - hitPos)

		if forward.Magnitude <= 0 then
			debris:Destroy()
			continue
		end

		forward = forward.Unit

		local rightAxis = normalVector:Cross(forward)

		if rightAxis.Magnitude <= 0 then
			debris:Destroy()
			continue
		end

		rightAxis = rightAxis.Unit

		local upAxis = forward:Cross(rightAxis)

		if upAxis.Magnitude <= 0 then
			debris:Destroy()
			continue
		end

		upAxis = upAxis.Unit

		local baseCF = CFrame.fromMatrix(
			hitPos,
			rightAxis,
			upAxis
		)

		local arcRot = CFrame.Angles(tilt, 0, 0)

		debris.CFrame = baseCF * arcRot

		debris.Position =
			debris.Position
		- normalVector * (debris.Size.Z + 1)

		debris.Parent = visuals

		local rise = TweenService:Create(
			debris,
			TweenInfo.new(
				config.SpawnTime,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				Transparency = 0,
				Position =
					debris.Position
					+ normalVector * (debris.Size.Z + 1)
			}
		)

		rise:Play()

		task.delay(config.Lifetime, function()

			if not debris or not debris.Parent then
				return
			end

			local fade = TweenService:Create(
				debris,
				TweenInfo.new(config.FadeOutTime),
				{
					Transparency = 1
				}
			)

			fade:Play()

			task.delay(config.FadeOutTime, function()

				if debris and debris.Parent then
					debris:Destroy()
				end

			end)
		end)
	end
end

-- a more situatonal debris impact (mostly used for slamdowns)
function DebrisModule:CreateDoubleCircle(originPosition, customConfig, baseCFrame)


	-- custom config for this one
	local config = {

		InnerRadius = 6, -- radius for the inner circle debris
		OuterRadius = 10, -- radius for the outer circle debris

		InnerCount = 8, -- how many parts the inner circle has
		OuterCount = 12, -- how many parts the outer circle has

		Thickness = 0.45, -- thickness of the parts
		Height = 0.35, -- height of the parts

		SpawnDepth = 1.2, -- depth for the debris
		SpawnTime = 0.2, -- rising tween for the spawn

		FadeOutTime = 1, -- fade out tween to look smooth
		Lifetime = 2.5, -- how much it stays till its cleared/destroyed

		RaycastUp = 0,
		RaycastDown = 10,

		InnerScaleJitter = 0.04,
		OuterScaleJitter = 0.04,
		RotationJitter = 2,
	}

	if customConfig then
		for k, v in pairs(customConfig) do
			config[k] = v
		end
	end

	local visuals = getVisualsFolder()
	if not visuals then
		return
	end

	local map = getMap()
	if not map then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = { map }

	local ringCF = baseCFrame or CFrame.new(originPosition)
	local center = ringCF.Position

	local function getGroundData(worldPos: Vector3)

		local rayOrigin =
			worldPos + Vector3.new(0, config.RaycastUp, 0)

		local rayDir =
			Vector3.new(0, -config.RaycastDown, 0)

		local result = Workspace:Raycast(
			rayOrigin,
			rayDir,
			params
		)

		if not result or not result.Instance then
			return nil
		end

		return {
			Position = result.Position,
			Normal = result.Normal,
			SourcePart = result.Instance,
		}
	end


	-- creates the actual ring debris impact
	local function createPolygonRing(radius: number, count: number, scaleJitter: number)

		local points = table.create(count)

		for i = 1, count do

			local angle = ((i - 1) / count) * math.pi * 2

			local localOffset = Vector3.new(
				math.cos(angle) * radius,
				0,
				math.sin(angle) * radius
			)

			local worldOffset =
				ringCF:VectorToWorldSpace(localOffset)

			local samplePos = center + worldOffset

			local groundData = getGroundData(samplePos)

			if not groundData then
				return
			end

			points[i] = groundData
		end

		for i = 1, count do

			local current = points[i]
			local nextPoint = points[(i % count) + 1]

			local a = current.Position
			local b = nextPoint.Position

			local segmentVector = b - a
			local segmentLength = segmentVector.Magnitude

			if segmentLength <= 0.01 then
				continue
			end

			local midpoint = (a + b) * 0.5

			local forward = segmentVector.Unit

			local up = (current.Normal + nextPoint.Normal)

			if up.Magnitude <= 0.01 then
				up = Vector3.yAxis
			else
				up = up.Unit
			end

			local right = up:Cross(forward)

			if right.Magnitude <= 0.01 then
				right = Vector3.xAxis
			else
				right = right.Unit
			end

			up = forward:Cross(right).Unit

			local lengthScale =
				1 + ((math.random() * 2 - 1) * scaleJitter)

			local heightScale =
				1 + ((math.random() * 2 - 1) * scaleJitter)

			local thicknessScale =
				1 + ((math.random() * 2 - 1) * scaleJitter)

			local part =
				createMatchingPartFromSource(current.SourcePart)

			applyRandomSize(part, Vector3.new(
				config.Thickness * thicknessScale,
				config.Height * heightScale,
				math.max(0.2, segmentLength * lengthScale)
				))

			local baseCF = CFrame.lookAt(
				midpoint,
				midpoint + forward,
				up
			)

			local inwardTilt =
				math.rad(math.random(20, 40))

			local rollJitter =
				math.rad(
					math.random(
						-config.RotationJitter * 100,
						config.RotationJitter * 100
					) / 100
				)

			part.CFrame =
				baseCF * CFrame.Angles(
					0,
					0,
					inwardTilt + rollJitter
				)

			part.Position -=
				up * (config.SpawnDepth + part.Size.Y * 0.5)

			part.Parent = visuals

			local riseTween = TweenService:Create(
				part,
				TweenInfo.new(
					config.SpawnTime,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.Out
				),
				{
					Transparency = 0,
					Position =
						part.Position
						+ up * (config.SpawnDepth + part.Size.Y * 0.5)
				}
			)

			riseTween:Play()

			task.delay(config.Lifetime, function()

				if not part or not part.Parent then
					return
				end

				local fadeTween = TweenService:Create(
					part,
					TweenInfo.new(config.FadeOutTime),
					{
						Transparency = 1
					}
				)

				fadeTween:Play()

				task.delay(config.FadeOutTime, function()

					if part and part.Parent then
						part:Destroy()
					end

				end)
			end)
		end
	end

	createPolygonRing( -- inner circle
		config.InnerRadius,
		config.InnerCount,
		config.InnerScaleJitter
	)

	createPolygonRing( -- outer circle
		config.OuterRadius,
		config.OuterCount,
		config.OuterScaleJitter
	)
end
-- whole thing for this module is to have a nice impactful debris around used for: explosion, slamming enemies into the ground, shockwaves

return DebrisModule
