-- Connected Discord-GitHub

local DebrisModule = {}

--|| Services ||--
local Workspace = game:GetService("Workspace") -- raycasts + finding the World folder
local TweenService = game:GetService("TweenService") -- rise + fade tweens

--|| Config ||--
local DEFAULT_CONFIG = { -- defaults for CreateDebris, anything passed in customConfig overrides these
	Radius = 12, -- how far from the center the chunks land, studs
	DebrisCount = 18, -- how many chunks in the circle
	FadeOutTime = 1.5, -- how long the fade out takes before the chunk gets destroyed
	Lifetime = 4, -- how long a chunk sits there before it starts fading
	SpawnTime = 0.4, -- how long the rise out of the ground takes

	RaycastUp = 50, -- ray starts this far above the chunk position so it still finds ground under ledges / slopes
	RaycastDown = 200 -- how far down the ray goes looking for ground
}

--|| Helpers ||--
local function getVisualsFolder() -- where temp debris goes, keeps it out of the gameplay stuff
	local world = Workspace:FindFirstChild("World")
	if not world then return nil end -- no World folder means no Visuals folder either

	return world:FindFirstChild("Visuals")
end

local function getMap() -- map folder, the raycasts only look at this so debris never copies a player or another chunk
	local world = Workspace:FindFirstChild("World")
	if not world then return nil end

	return world:FindFirstChild("Map")
end

local function createMatchingPartFromSource(sourcePart: BasePart) -- makes a part that looks like the ground it came out of
	local newPart

	if sourcePart:IsA("WedgePart") then -- keep the wedge shape
		newPart = Instance.new("WedgePart")

	elseif sourcePart:IsA("Part") and sourcePart.Shape == Enum.PartType.Ball then -- keep the ball shape
		newPart = Instance.new("Part")
		newPart.Shape = Enum.PartType.Ball

	else
		newPart = Instance.new("Part") -- everything else just gets a block
	end

	newPart.Material = sourcePart.Material -- copy the look so it reads as the same ground
	newPart.Color = sourcePart.Color
	newPart.Reflectance = sourcePart.Reflectance
	newPart.Transparency = 1 -- starts invisible, the rise tween fades it in

	newPart.Anchored = true -- tweened, not simulated
	newPart.CanCollide = false -- purely visual, shouldnt block anyone
	newPart.CanTouch = false -- no Touched events firing off debris
	newPart.CanQuery = false -- raycasts go straight through it, so new chunks dont copy old chunks
	newPart.CastShadow = false -- lots of small parts, shadows are wasted perf

	return newPart
end

local function applyRandomSize(part: BasePart, size: Vector3) -- sets the size, balls get forced uniform
	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
		local diameter = math.max(size.X, size.Y, size.Z) -- ball parts only use one size, so take the biggest axis

		part.Size = Vector3.new(
			diameter,
			diameter,
			diameter
		)

	else
		part.Size = size
	end
end

--|| Debris ||--
local function createDebrisChunk(origin, angleDeg, config, baseCFrame) -- one chunk at angleDeg around the circle
	local visuals = getVisualsFolder()
	if not visuals then return end

	local map = getMap()
	if not map then return end

	local angle = math.rad(angleDeg) -- cos/sin want radians

	local radiusJitter = math.random(-3, 3) -- small random push in/out so the circle isnt perfect

	local arcInwardTilt = math.rad(-math.random(20, 40)) -- negative so the chunk leans in toward the center

	local distance = config.Radius + radiusJitter

	local offset = Vector3.new( -- point on the circle at this angle
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)

	local basePosition = baseCFrame and baseCFrame.Position or origin -- baseCFrame wins if one was passed

	local finalOffsetPosition = basePosition + offset

	local rayOrigin = finalOffsetPosition + Vector3.new(0, config.RaycastUp, 0) -- start above so we land on top of the ground, not inside it
	local rayDirection = Vector3.new(0, -config.RaycastDown, 0) -- straight down

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist -- only hit stuff in Map
	params.FilterDescendantsInstances = { map }

	local result = Workspace:Raycast(rayOrigin, rayDirection, params)

	if not result or not result.Instance then -- no ground here (off the edge of the map), skip this chunk
		return
	end

	local hitPos = result.Position
	local sourcePart = result.Instance -- the ground part we hit, debris copies its look

	local debris = createMatchingPartFromSource(sourcePart)

	applyRandomSize(debris, Vector3.new( -- random size so the chunks dont all look the same
		math.random(3, 6),
		math.random(1, 2),
		math.random(2, 5)
		))

	local directionToOrigin = (origin - hitPos) -- chunk to center

	if directionToOrigin.Magnitude <= 0 then -- landed exactly on the center, .Unit would be NaN
		return
	end

	directionToOrigin = directionToOrigin.Unit

	local lookCFrame = CFrame.new(hitPos, hitPos + directionToOrigin) -- chunk faces the center

	local arcRotation = CFrame.Angles(arcInwardTilt, 0, 0) -- tilt around its own X so the front dips toward the center

	debris.CFrame = lookCFrame * arcRotation -- face first, then tilt in local space

	debris.Position = debris.Position - Vector3.new(0, debris.Size.Y + 1, 0) -- sink it fully under the ground so the tween can raise it out

	debris.Parent = visuals

	local riseTween = TweenService:Create( -- fades in while rising back up to ground level
		debris,
		TweenInfo.new(
			config.SpawnTime,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out -- fast at the start, slows into place
		),
		{
			Transparency = 0,
			Position = debris.Position + Vector3.new(0, debris.Size.Y + 1, 0) -- exact opposite of the sink above
		}
	)

	riseTween:Play()

	task.delay(config.Lifetime, function() -- sit there for Lifetime, then fade
		if not debris or not debris.Parent then -- already got cleared by something else
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

		task.delay(config.FadeOutTime, function() -- destroy once the fade is done, the tween dies with the part
			if debris and debris.Parent then
				debris:Destroy()
			end
		end)
	end)
end

function DebrisModule:CreateDebris(originPosition, customConfig, baseCFrame) -- circle of chunks around originPosition
	local config = table.clone(DEFAULT_CONFIG) -- clone so overrides dont leak into the defaults for the next call

	if customConfig then
		for k, v in pairs(customConfig) do -- copy every override on top
			config[k] = v
		end
	end

	for i = 1, config.DebrisCount do
		local angle =
			(360 / config.DebrisCount) * i -- spread evenly around the circle
			+ math.random(-10, 10) -- plus a bit of jitter so the gaps arent identical

		createDebrisChunk(
			originPosition,
			angle,
			config,
			baseCFrame
		)
	end
end

function DebrisModule:CreateDoubleCircle(originPosition, customConfig, baseCFrame) -- two clean rings of segments that follow the ground
	local config = { -- own defaults, this one is a thin crack ring not big chunks
		InnerRadius = 6, -- inner ring distance from the center, studs
		OuterRadius = 10, -- outer ring distance from the center, studs

		InnerCount = 8, -- inner ring segments
		OuterCount = 12, -- outer ring segments, more cuz its bigger

		Thickness = 0.45, -- segment width
		Height = 0.35, -- segment height

		SpawnDepth = 1.2, -- how far under the surface a segment starts before rising
		SpawnTime = 0.2,
		FadeOutTime = 1,
		Lifetime = 2.5,

		RaycastUp = 0, -- ray starts right at the ring point
		RaycastDown = 10, -- short ray, ring is meant for flat-ish ground near the origin

		InnerScaleJitter = 0.04, -- +-4% random length / height / thickness on inner segments
		OuterScaleJitter = 0.04, -- same for outer
		RotationJitter = 2, -- +-2 degrees of random roll per segment
	}

	if customConfig then
		for k, v in pairs(customConfig) do -- overrides on top. fresh table every call so no clone needed
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

	local params = RaycastParams.new() -- made once, shared by every ray in both rings
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = { map } -- only hit the map

	local ringCF = baseCFrame or CFrame.new(originPosition) -- baseCFrame lets the ring be rotated / placed on a wall
	local center = ringCF.Position

	local function getGroundData(worldPos: Vector3) -- ray down from a point, returns where it hit + the surface normal + the part
		local rayOrigin = worldPos + vector.create(0, config.RaycastUp, 0)
		local rayDir = vector.create(0, -config.RaycastDown, 0)

		local result = Workspace:Raycast(rayOrigin, rayDir, params)
		if not result or not result.Instance then
			return nil
		end

		return {
			Position = result.Position,
			Normal = result.Normal, -- used to tilt the segment so it lies flat on slopes
			SourcePart = result.Instance, -- used to copy the look
		}
	end

	local function createPolygonRing(radius: number, count: number, scaleJitter: number) -- ring of count segments, each one bridging two neighbouring ground points
		local points = table.create(count) -- preallocated, we know the size

		for i = 1, count do -- first pass: find the ground under every corner of the polygon
			local angle = ((i - 1) / count) * math.pi * 2 -- i - 1 so the first point sits at angle 0
			local localOffset = vector.create(
				math.cos(angle) * radius,
				0,
				math.sin(angle) * radius
			)

			local worldOffset = ringCF:VectorToWorldSpace(localOffset) -- rotate the offset by ringCF so the ring follows its orientation
			local samplePos = center + worldOffset
			local groundData = getGroundData(samplePos)

			if not groundData then -- one corner missed, the polygon would have a hole, so skip the whole ring
				return
			end

			points[i] = groundData
		end

		for i = 1, count do -- second pass: one segment from each point to the next
			local current = points[i]
			local nextPoint = points[(i % count) + 1] -- % wraps the last point back to the first so the ring closes

			local a = current.Position
			local b = nextPoint.Position

			local segmentVector = b - a
			local segmentLength = segmentVector.Magnitude
			if segmentLength <= 0.01 then -- both points on top of each other, .Unit would be NaN
				continue
			end

			local midpoint = (a + b) * 0.5 -- segment sits centred between the two points
			local forward = segmentVector.Unit -- along the segment

			local up = (current.Normal + nextPoint.Normal) -- average of both normals so the segment matches the slope under it
			if up.Magnitude <= 0.01 then -- normals cancelled out, fall back to world up
				up = Vector3.yAxis
			else
				up = up.Unit
			end

			local right = up:Cross(forward) -- sideways axis
			if right.Magnitude <= 0.01 then -- up and forward are parallel, cross is zero
				right = Vector3.xAxis
			else
				right = right.Unit
			end

			up = forward:Cross(right).Unit -- rebuild up so all three axes are exactly perpendicular

			local lengthScale = 1 + ((math.random() * 2 - 1) * scaleJitter) -- random() * 2 - 1 gives -1 to 1, times jitter
			local heightScale = 1 + ((math.random() * 2 - 1) * scaleJitter)
			local thicknessScale = 1 + ((math.random() * 2 - 1) * scaleJitter)

			local part = createMatchingPartFromSource(current.SourcePart)

			applyRandomSize(part, vector.create(
				config.Thickness * thicknessScale,
				config.Height * heightScale,
				math.max(0.2, segmentLength * lengthScale) -- Z is the length cuz lookAt points Z down the segment. floor so it never goes tiny
				))

			local baseCF = CFrame.lookAt(midpoint, midpoint + forward, up) -- at the midpoint, facing along the segment, upright on the surface

			local inwardTilt = math.rad(math.random(20, 40)) -- roll so the segment leans like a cracked edge
			local rollJitter = math.rad(math.random(-config.RotationJitter * 100, config.RotationJitter * 100) / 100) -- * 100 then / 100 cuz math.random only does integers, this gets decimals

			part.CFrame = baseCF * CFrame.Angles(0, 0, inwardTilt + rollJitter) -- roll around its own length

			part.Position -= up * (config.SpawnDepth + part.Size.Y * 0.5) -- push it under the surface along the normal, not world down, so it works on slopes
			part.Parent = visuals

			local riseTween = TweenService:Create( -- fade in + rise back out along the normal
				part,
				TweenInfo.new(config.SpawnTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{
					Transparency = 0,
					Position = part.Position + up * (config.SpawnDepth + part.Size.Y * 0.5) -- exact opposite of the sink above
				}
			)
			riseTween:Play()

			task.delay(config.Lifetime, function() -- sit for Lifetime, then fade
				if not part or not part.Parent then
					return
				end

				local fadeTween = TweenService:Create(
					part,
					TweenInfo.new(config.FadeOutTime),
					{ Transparency = 1 }
				)
				fadeTween:Play()

				task.delay(config.FadeOutTime, function() -- gone once the fade finishes
					if part and part.Parent then
						part:Destroy()
					end
				end)
			end)
		end
	end

	createPolygonRing(config.InnerRadius, config.InnerCount, config.InnerScaleJitter)
	createPolygonRing(config.OuterRadius, config.OuterCount, config.OuterScaleJitter)
end

return DebrisModule
