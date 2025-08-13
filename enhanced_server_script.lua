-- Enhanced Horror Game Server Script
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

local jumpscareEvent = Instance.new("RemoteEvent")
jumpscareEvent.Name = "Jumpscare"
jumpscareEvent.Parent = remoteEvents

-- Game variables
local father = workspace:WaitForChild("Father")
local fatherHumanoid = father:WaitForChild("Humanoid")
local fatherRootPart = father:WaitForChild("HumanoidRootPart")

-- Define waypoints around the house
local waypoints = {
	Vector3.new(-124.497, 5.295, -13.348),    -- 1: Living room
	Vector3.new(-162.4, 5.095, -17.444),      -- 2: Kitchen
	Vector3.new(-103.4, 5.095, -29.444),      -- 3: Hallway
	Vector3.new(-67.9, 5.095, -28.944),       -- 4: Bathroom
	Vector3.new(-102.9, 5.095, -11.944),      -- 5: Another room
	Vector3.new(-84.9, 5.095, -30.944),       -- 6: Near kid's room (danger zone!)
	Vector3.new(-75.4, 5.095, -48.444)        -- 7: INSIDE kid's room (NEW!)
}

-- Patrol patterns - Dad follows these routes before checking your room
local patrolPatterns = {
	{1, 2, 3, 4, 5},        -- Pattern 1: Full house tour
	{1, 3, 5, 2},           -- Pattern 2: Quick check
	{2, 4, 1, 3},           -- Pattern 3: Kitchen focus
	{5, 3, 1, 4}            -- Pattern 4: Mixed route
}

-- Game state
local gameActive = true
local fatherMoving = false
local movementDebounce = false
local activeConnections = {}

-- Patrol system state
local currentPatrol = 1
local currentPatrolStep = 1
local patrolsCompleted = 0
local isCheckingRoom = false
local roomCheckStartTime = 0

-- Function to clean up all active connections
local function cleanupConnections()
	for i, connection in ipairs(activeConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	activeConnections = {}
end

-- Function to check if players are in bed
local function getPlayersInBed()
	local playersInBed = {}
	local playersAwake = {}
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerPos = player.Character.HumanoidRootPart.Position
			local bedPosition = Vector3.new(-75.4, 5.095, -48.444) -- Adjust to your bed position
			local distanceToBed = (playerPos - bedPosition).Magnitude
			
			-- Check if player is close to bed and laying down (rotated)
			local rotation = player.Character.HumanoidRootPart.Rotation
			local isLayingDown = math.abs(rotation.Z) > 45 -- Check if rotated (in bed)
			
			if distanceToBed < 8 and isLayingDown then
				table.insert(playersInBed, player)
			else
				table.insert(playersAwake, player)
			end
		end
	end
	
	return playersInBed, playersAwake
end

-- Function to trigger jumpscare for specific players
local function triggerJumpscare(players)
	for _, player in pairs(players) do
		jumpscareEvent:FireClient(player)
		print("Jumpscare triggered for", player.Name)
	end
end

-- Function to perform room check
local function performRoomCheck()
	print("=== PERFORMING ROOM CHECK ===")
	isCheckingRoom = true
	roomCheckStartTime = tick()
	
	-- Move to room entrance first (waypoint 6)
	local function moveToRoomEntrance()
		print("Moving to room entrance...")
		updateFatherPosition:FireAllClients(waypoints[6], true) -- Send danger warning
		
		cleanupConnections()
		fatherMoving = true
		
		-- Simple move to entrance
		fatherHumanoid:MoveTo(waypoints[6])
		
		local connection = fatherHumanoid.MoveToFinished:Connect(function(reached)
			print("Reached room entrance. Waiting 3 seconds...")
			connection:Disconnect()
			
			-- Wait 3 seconds at entrance (build tension)
			spawn(function()
				wait(3)
				
				-- Now enter the room
				print("Entering room...")
				fatherHumanoid:MoveTo(waypoints[7]) -- Move inside room
				
				local enterConnection = fatherHumanoid.MoveToFinished:Connect(function(reachedRoom)
					print("Father entered room!")
					enterConnection:Disconnect()
					
					-- Check if players are sleeping
					spawn(function()
						wait(2) -- Give players a moment to react
						
						local playersInBed, playersAwake = getPlayersInBed()
						
						if #playersAwake > 0 then
							-- CAUGHT! Trigger jumpscare
							print("Players caught awake:", #playersAwake)
							triggerJumpscare(playersAwake)
						else
							print("All players safe in bed")
						end
						
						-- Leave room after check
						wait(3)
						print("Father leaving room...")
						fatherHumanoid:MoveTo(waypoints[6]) -- Exit to entrance
						
						local exitConnection = fatherHumanoid.MoveToFinished:Connect(function()
							exitConnection:Disconnect()
							print("Father left room")
							
							-- Reset and continue patrol
							isCheckingRoom = false
							fatherMoving = false
							patrolsCompleted = patrolsCompleted + 1
							currentPatrol = (patrolsCompleted % #patrolPatterns) + 1
							currentPatrolStep = 1
							
							-- Send all clear
							updateFatherPosition:FireAllClients(waypoints[6], false)
							
							-- Schedule next patrol
							scheduleNextMovement()
						end)
						
						table.insert(activeConnections, exitConnection)
					end)
				end)
				
				table.insert(activeConnections, enterConnection)
			end)
		end)
		
		table.insert(activeConnections, connection)
	end
	
	moveToRoomEntrance()
end

-- Function to schedule next movement
local function scheduleNextMovement()
	if movementDebounce then return end
	movementDebounce = true
	
	print("Scheduling next movement...")
	spawn(function()
		local waitTime = math.random(4, 8)
		print("Waiting", waitTime, "seconds before next move")
		wait(waitTime)
		movementDebounce = false
		
		if gameActive and not fatherMoving then
			chooseFatherNextMove()
		end
	end)
end

-- Function to move father to a waypoint
local function moveFatherTo(targetPosition, isRoomCheck)
	if not gameActive or fatherMoving then 
		print("Movement blocked")
		return 
	end

	cleanupConnections()
	fatherMoving = true
	
	print("=== MOVING TO:", targetPosition, "===")

	-- Create path
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4
	})

	local success, errorMessage = pcall(function()
		path:ComputeAsync(fatherRootPart.Position, targetPosition)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local pathWaypoints = path:GetWaypoints()
		print("Pathfinding successful! Found", #pathWaypoints, "waypoints")
		
		-- Update players about movement
		updateFatherPosition:FireAllClients(targetPosition, isRoomCheck or false)
		
		-- Move through waypoints
		local waypointIndex = 1
		local function moveToNextWaypoint()
			if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
				local waypoint = pathWaypoints[waypointIndex]
				
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					fatherHumanoid.Jump = true
				end
				
				fatherHumanoid:MoveTo(waypoint.Position)
				
				local connection = fatherHumanoid.MoveToFinished:Connect(function(reached)
					waypointIndex = waypointIndex + 1
					
					if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
						moveToNextWaypoint()
					else
						-- Movement complete
						print("=== MOVEMENT COMPLETE ===")
						fatherMoving = false
						cleanupConnections()
						
						if not isCheckingRoom then
							scheduleNextMovement()
						end
					end
				end)
				
				table.insert(activeConnections, connection)
			end
		end
		
		moveToNextWaypoint()
	else
		-- Fallback
		print("Pathfinding failed, using simple MoveTo")
		fatherHumanoid:MoveTo(targetPosition)
		updateFatherPosition:FireAllClients(targetPosition, isRoomCheck or false)
		
		local connection = fatherHumanoid.MoveToFinished:Connect(function(reached)
			fatherMoving = false
			cleanupConnections()
			if not isCheckingRoom then
				scheduleNextMovement()
			end
		end)
		
		table.insert(activeConnections, connection)
	end
end

-- Enhanced movement selection
function chooseFatherNextMove()
	if not gameActive or fatherMoving then 
		print("Cannot choose next move")
		return 
	end

	print("=== CHOOSING FATHER'S NEXT MOVE ===")
	print("Current patrol:", currentPatrol, "Step:", currentPatrolStep, "Patrols completed:", patrolsCompleted)

	-- Check if it's time for room check (every 2-3 patrols)
	if patrolsCompleted > 0 and patrolsCompleted % math.random(2, 3) == 0 and not isCheckingRoom then
		print("Time for room check!")
		performRoomCheck()
		return
	end

	-- Follow patrol pattern
	local currentPattern = patrolPatterns[currentPatrol]
	
	if currentPatrolStep <= #currentPattern then
		local nextWaypoint = currentPattern[currentPatrolStep]
		print("Following patrol pattern - going to waypoint", nextWaypoint)
		
		currentPatrolStep = currentPatrolStep + 1
		moveFatherTo(waypoints[nextWaypoint])
	else
		-- Patrol complete, start new one
		print("Patrol complete, starting next patrol")
		patrolsCompleted = patrolsCompleted + 1
		currentPatrol = (patrolsCompleted % #patrolPatterns) + 1
		currentPatrolStep = 1
		
		-- Small delay before next patrol
		spawn(function()
			wait(math.random(3, 6))
			if gameActive then
				chooseFatherNextMove()
			end
		end)
	end
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		updateFatherPosition:FireClient(player, fatherRootPart.Position)
	end)
end)

-- Main game loop
RunService.Heartbeat:Connect(function()
	if gameActive then
		-- Any continuous checks can go here
	end
end)

-- Debug commands
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if player.Name == game.CreatorId or player.Name == "YourUsernameHere" then
			if message:lower() == "/roomcheck" then
				print("Manual room check triggered")
				performRoomCheck()
			elseif message:lower() == "/jumpscare" then
				print("Manual jumpscare triggered")
				triggerJumpscare({player})
			elseif message:lower() == "/status" then
				print("=== FATHER STATUS ===")
				print("gameActive:", gameActive)
				print("fatherMoving:", fatherMoving)
				print("isCheckingRoom:", isCheckingRoom)
				print("currentPatrol:", currentPatrol)
				print("currentPatrolStep:", currentPatrolStep)
				print("patrolsCompleted:", patrolsCompleted)
			end
		end
	end)
end)

-- Start the game
spawn(function()
	print("=== INITIALIZING ENHANCED HORROR GAME ===")
	wait(math.random(5, 8))
	print("Starting structured patrol system...")
	chooseFatherNextMove()
end)

print("Enhanced horror game initialized with patrol system and room checks!")