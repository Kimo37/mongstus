-- Main Game Script (ServerScript in ServerScriptService)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

-- Create RemoteEvents for client-server communication
local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "RemoteEvents"
remoteEvents.Parent = ReplicatedStorage

local updateFatherPosition = Instance.new("RemoteEvent")
updateFatherPosition.Name = "UpdateFatherPosition"
updateFatherPosition.Parent = remoteEvents

local gameOverEvent = Instance.new("RemoteEvent")
gameOverEvent.Name = "GameOver"
gameOverEvent.Parent = remoteEvents

-- Game variables
local father = workspace:WaitForChild("Father") -- Your father NPC model
local fatherHumanoid = father:WaitForChild("Humanoid")
local fatherRootPart = father:WaitForChild("HumanoidRootPart")

-- Define waypoints around the house (you'll need to adjust these positions)
local waypoints = {
	Vector3.new(-124.497, 5.295, -13.348),    -- Living room
	Vector3.new(-162.4, 5.095, -17.444),      -- Kitchen
	Vector3.new(-103.4, 5.095, -29.444),      -- Hallway
	Vector3.new(-67.9, 5.095, -28.944),       -- Bathroom
	Vector3.new(-102.9, 5.095, -11.944),      -- Another room
	Vector3.new(-84.9, 5.095, -30.944)        -- Near kid's room (danger zone!)
}

-- Game state
local gameActive = true
local fatherCurrentWaypoint = 1
local fatherMoving = false
local movementDebounce = false
local activeConnections = {} -- Track active connections to clean them up properly

-- Function to clean up all active connections
local function cleanupConnections()
	for i, connection in ipairs(activeConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	activeConnections = {} -- Clear the table
end

-- Function to schedule next movement
local function scheduleNextMovement()
	if movementDebounce then return end
	movementDebounce = true
	
	print("Scheduling next movement...")
	spawn(function()
		local waitTime = math.random(3, 8)
		print("Waiting", waitTime, "seconds before next move")
		wait(waitTime)
		movementDebounce = false
		
		if gameActive and not fatherMoving then
			print("Triggering chooseFatherNextMove from schedule")
			chooseFatherNextMove()
		else
			print("Cannot move - gameActive:", gameActive, "fatherMoving:", fatherMoving)
		end
	end)
end

-- Function to move father to a waypoint using pathfinding
local function moveFatherTo(targetPosition)
	if not gameActive or fatherMoving then 
		print("Movement blocked - gameActive:", gameActive, "fatherMoving:", fatherMoving)
		return 
	end

	-- Clean up any old connections first
	cleanupConnections()
	
	fatherMoving = true
	print("=== STARTING MOVEMENT ===")
	print("Moving father to:", targetPosition)
	print("Father current position:", fatherRootPart.Position)

	-- Create a path using PathfindingService
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
		Costs = {
			Water = 20,
			DangerousArea = math.huge
		}
	})

	local success, errorMessage = pcall(function()
		path:ComputeAsync(fatherRootPart.Position, targetPosition)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local pathWaypoints = path:GetWaypoints()
		print("Pathfinding successful! Found", #pathWaypoints, "waypoints")
		
		-- Update all players about father's movement
		updateFatherPosition:FireAllClients(targetPosition)
		
		-- Move through each waypoint
		local waypointIndex = 1
		local function moveToNextWaypoint()
			if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
				local waypoint = pathWaypoints[waypointIndex]
				print("Moving to waypoint", waypointIndex, "of", #pathWaypoints)
				
				-- Handle jumping if needed
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					print("Jumping at waypoint", waypointIndex)
					fatherHumanoid.Jump = true
				end
				
				fatherHumanoid:MoveTo(waypoint.Position)
				
				local connection = fatherHumanoid.MoveToFinished:Connect(function(reached)
					print("Waypoint", waypointIndex, "finished. Reached:", reached)
					
					waypointIndex = waypointIndex + 1
					
					if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
						print("Moving to next waypoint:", waypointIndex)
						moveToNextWaypoint()
					else
						-- Movement complete
						print("=== MOVEMENT COMPLETE ===")
						fatherMoving = false
						cleanupConnections()
						
						-- Schedule next movement
						scheduleNextMovement()
					end
				end)
				
				-- Store connection for cleanup
				table.insert(activeConnections, connection)
				
				-- Timeout for each waypoint
				local timeoutCoroutine = spawn(function()
					wait(8) -- 8 second timeout per waypoint
					if fatherMoving and waypointIndex == waypointIndex then
						print("Waypoint", waypointIndex, "timed out, skipping")
						waypointIndex = waypointIndex + 1
						if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
							moveToNextWaypoint()
						else
							print("=== MOVEMENT TIMED OUT ===")
							fatherMoving = false
							cleanupConnections()
							scheduleNextMovement()
						end
					end
				end)
			else
				print("Cannot continue waypoint movement")
				fatherMoving = false
				cleanupConnections()
				scheduleNextMovement()
			end
		end
		
		-- Start moving through waypoints
		moveToNextWaypoint()
		
	else
		-- Pathfinding failed, use simple MoveTo as fallback
		print("=== PATHFINDING FAILED ===")
		print("Error:", errorMessage)
		print("Using simple MoveTo fallback")
		
		fatherHumanoid:MoveTo(targetPosition)
		updateFatherPosition:FireAllClients(targetPosition)
		
		local connection = fatherHumanoid.MoveToFinished:Connect(function(reached)
			print("Simple movement finished. Reached:", reached)
			fatherMoving = false
			cleanupConnections()
			scheduleNextMovement()
		end)
		
		-- Store connection for cleanup
		table.insert(activeConnections, connection)

		-- Backup timeout for simple movement
		spawn(function()
			wait(15) -- 15 second timeout
			if fatherMoving then
				print("Simple movement timed out")
				fatherMoving = false
				cleanupConnections()
				scheduleNextMovement()
			end
		end)
	end
end

-- Function to choose father's next movement
function chooseFatherNextMove()
	if not gameActive or fatherMoving then 
		print("Cannot choose next move - gameActive:", gameActive, "fatherMoving:", fatherMoving)
		return 
	end

	print("=== CHOOSING FATHER'S NEXT MOVE ===")
	print("Current waypoint:", fatherCurrentWaypoint)

	-- Random chance to move or stay put
	local moveChance = math.random()
	print("Move chance:", moveChance)
	
	if moveChance < 0.8 then -- 80% chance to move
		local nextWaypoint = math.random(1, #waypoints)
		-- Don't move to the same spot
		local attempts = 0
		while nextWaypoint == fatherCurrentWaypoint and attempts < 10 do
			nextWaypoint = math.random(1, #waypoints)
			attempts = attempts + 1
		end

		print("Father moving from waypoint", fatherCurrentWaypoint, "to", nextWaypoint)
		print("Target position:", waypoints[nextWaypoint])
		fatherCurrentWaypoint = nextWaypoint
		moveFatherTo(waypoints[nextWaypoint])
	else
		-- Stay put for a while, then try again
		print("Father staying put for a while")
		spawn(function()
			local waitTime = math.random(3, 6)
			print("Staying put for", waitTime, "seconds")
			wait(waitTime)
			if gameActive then
				print("Finished staying put, choosing next move")
				chooseFatherNextMove()
			end
		end)
	end
end

-- Function to check if father is near kid's room
local function checkProximityToKidsRoom()
	local kidsRoomPosition = Vector3.new(-75.4, 5.095, -48.444) -- Your kid's room position
	local distance = (fatherRootPart.Position - kidsRoomPosition).Magnitude

	if distance < 15 then -- If father is within 15 studs of kid's room
		-- Trigger warning for all players
		updateFatherPosition:FireAllClients(fatherRootPart.Position, true) -- true = danger zone
	end
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Send initial father position to new player
		updateFatherPosition:FireClient(player, fatherRootPart.Position)
	end)
end)

-- Main game loop
RunService.Heartbeat:Connect(function()
	if gameActive then
		checkProximityToKidsRoom()
	end
end)

-- Debug command to manually trigger movement (remove this later)
game.Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if player.Name == game.CreatorId or player.Name == "YourUsernameHere" then -- Replace with your username
			if message:lower() == "/movedad" then
				print("Manual movement triggered by", player.Name)
				chooseFatherNextMove()
			elseif message:lower() == "/status" then
				print("=== FATHER STATUS ===")
				print("gameActive:", gameActive)
				print("fatherMoving:", fatherMoving)
				print("movementDebounce:", movementDebounce)
				print("fatherCurrentWaypoint:", fatherCurrentWaypoint)
				print("Father position:", fatherRootPart.Position)
				print("Active connections:", #activeConnections)
			elseif message:lower() == "/cleanup" then
				print("Manual cleanup triggered")
				cleanupConnections()
			end
		end
	end)
end)

-- Start the father's AI after a delay
spawn(function()
	local initialDelay = math.random(5, 10)
	print("=== INITIALIZING FATHER AI ===")
	print("Waiting", initialDelay, "seconds before starting...")
	wait(initialDelay)
	print("Starting father AI...")
	chooseFatherNextMove()
end)

print("Horror game initialized with clean connection management!")