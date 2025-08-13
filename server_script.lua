-- Enhanced Horror Game Server Script (FIXED CRITICAL BUGS)
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
	Vector3.new(-74.4, 2.595, -42.944),       -- 7: Room entrance (just inside door)
	Vector3.new(-74.4, 2.595, -48.944)        -- 8: Room center (your exact position)
}

-- Room boundaries for detection
local ROOM_CENTER = Vector3.new(-74.4, 2.595, -48.944)
local ROOM_DETECTION_RADIUS = 8
local BED_POSITION = Vector3.new(-74.4, 2.595, -48.944)

-- Patrol patterns - Dad teleports to these rooms
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

-- Forward declare the function
local scheduleNextMovement

-- Function to clean up all active connections
local function cleanupConnections()
	print("Cleaning up", #activeConnections, "connections")
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
			local distanceToBed = (playerPos - BED_POSITION).Magnitude
			
			-- Check if player is close to bed and laying down (rotated)
			local rotation = player.Character.HumanoidRootPart.Rotation
			local isLayingDown = math.abs(rotation.Z) > 45
			
			if distanceToBed < 8 and isLayingDown then
				table.insert(playersInBed, player)
			else
				table.insert(playersAwake, player)
			end
		end
	end
	
	return playersInBed, playersAwake
end

-- Function to trigger jumpscare for specific players (ONLY ONCE)
local jumpscareTriggered = false
local function triggerJumpscare(players)
	if jumpscareTriggered then 
		print("Jumpscare already triggered, skipping")
		return 
	end
	
	jumpscareTriggered = true
	for _, player in pairs(players) do
		jumpscareEvent:FireClient(player)
		print("Jumpscare triggered for", player.Name)
	end
	
	-- Reset flag after room check is completely done (longer delay)
	spawn(function()
		wait(15) -- Increased from 5 to 15 seconds
		jumpscareTriggered = false
		print("Jumpscare cooldown reset")
	end)
end

-- SIMPLE Function to teleport father to a waypoint
local function teleportFatherTo(waypointIndex)
	if not gameActive then return end
	
	local targetPosition = waypoints[waypointIndex]
	print("=== TELEPORTING FATHER ===")
	print("To waypoint", waypointIndex, "at position:", targetPosition)
	
	-- Teleport father instantly
	fatherRootPart.CFrame = CFrame.new(targetPosition)
	
	-- Update clients about new position
	updateFatherPosition:FireAllClients(targetPosition, false)
	
	print("Father teleported successfully!")
end

-- Function to complete room check and reset state
local function completeRoomCheck()
	print("=== COMPLETING ROOM CHECK ===")
	
	-- Clean up any remaining connections
	cleanupConnections()
	
	-- Reset state
	isCheckingRoom = false
	fatherMoving = false
	
	-- Reset patrol after room check
	patrolsCompleted = 0
	currentPatrol = math.random(1, #patrolPatterns)
	currentPatrolStep = 1
	
	print("Room check complete. Starting new patrol:", currentPatrol)
	
	-- Send all clear
	updateFatherPosition:FireAllClients(waypoints[6], false)
	
	-- Schedule next patrol
	scheduleNextMovement()
end

-- Function to perform room check (SIMPLIFIED SEQUENTIAL APPROACH)
local function performRoomCheck()
	print("=== PERFORMING ROOM CHECK ===")
	print("Patrols completed before room check:", patrolsCompleted)
	isCheckingRoom = true
	fatherMoving = true
	
	-- Clean up any existing connections first
	cleanupConnections()
	
	-- Use spawn to run the entire sequence without blocking
	spawn(function()
		-- Step 1: Teleport to danger zone
		print("Step 1: Moving to danger zone...")
		teleportFatherTo(6)
		updateFatherPosition:FireAllClients(waypoints[6], true)
		wait(3) -- Tension building
		
		if not gameActive or not isCheckingRoom then 
			print("Room check cancelled during step 1")
			completeRoomCheck()
			return 
		end
		
		-- Step 2: Move to room entrance
		print("Step 2: Moving to room entrance...")
		fatherHumanoid:MoveTo(waypoints[7])
		
		-- Wait for movement to complete OR timeout
		local moveStarted = tick()
		local reached = false
		local connection = fatherHumanoid.MoveToFinished:Connect(function()
			reached = true
		end)
		
		-- Wait up to 10 seconds for movement
		while not reached and (tick() - moveStarted) < 10 and gameActive and isCheckingRoom do
			wait(0.1)
		end
		
		connection:Disconnect()
		
		if not gameActive or not isCheckingRoom then 
			print("Room check cancelled during step 2")
			completeRoomCheck()
			return 
		end
		
		print("Step 3: Announcing room invasion...")
		updateFatherPosition:FireAllClients(ROOM_CENTER, true) -- "IN YOUR ROOM!" signal
		wait(1)
		
		-- Step 4: Move to room center
		print("Step 4: Moving to room center...")
		fatherHumanoid:MoveTo(waypoints[8])
		
		-- Wait for center movement OR timeout
		moveStarted = tick()
		reached = false
		connection = fatherHumanoid.MoveToFinished:Connect(function()
			reached = true
		end)
		
		-- Wait up to 8 seconds for center movement
		while not reached and (tick() - moveStarted) < 8 and gameActive and isCheckingRoom do
			wait(0.1)
		end
		
		connection:Disconnect()
		
		if not gameActive or not isCheckingRoom then 
			print("Room check cancelled during step 4")
			completeRoomCheck()
			return 
		end
		
		-- Step 5: Check players and potentially trigger jumpscare
		print("Step 5: Checking player status...")
		wait(1) -- Give players a moment
		
		local playersInBed, playersAwake = getPlayersInBed()
		
		if #playersAwake > 0 then
			print("Players caught awake:", #playersAwake)
			triggerJumpscare(playersAwake)
		else
			print("All players safe in bed")
		end
		
		-- Step 6: Leave room
		print("Step 6: Father leaving room...")
		wait(2) -- Dramatic pause
		teleportFatherTo(6) -- Back to outside room
		wait(1)
		
		-- Step 7: Complete room check
		print("Step 7: Completing room check...")
		completeRoomCheck()
	end)
end

-- Function to schedule next movement (FIXED)
scheduleNextMovement = function()
	if movementDebounce then return end
	movementDebounce = true
	
	print("Scheduling next movement...")
	spawn(function()
		local waitTime = math.random(3, 6)
		print("Waiting", waitTime, "seconds before next move")
		wait(waitTime)
		movementDebounce = false
		
		if gameActive and not fatherMoving and not isCheckingRoom then
			chooseFatherNextMove()
		end
	end)
end

-- SIMPLE Enhanced movement selection (with teleports)
function chooseFatherNextMove()
	if not gameActive or fatherMoving or isCheckingRoom then 
		print("Cannot choose next move - gameActive:", gameActive, "fatherMoving:", fatherMoving, "isCheckingRoom:", isCheckingRoom)
		return 
	end

	print("=== CHOOSING FATHER'S NEXT MOVE ===")
	print("Current patrol:", currentPatrol, "Step:", currentPatrolStep, "Patrols completed:", patrolsCompleted)

	-- Check if it's time for room check (every 2 patrols)
	if patrolsCompleted >= 2 then
		print("Time for room check! (2+ patrols completed)")
		performRoomCheck()
		return
	end

	-- Follow patrol pattern with TELEPORTS
	local currentPattern = patrolPatterns[currentPatrol]
	
	if currentPatrolStep <= #currentPattern then
		local nextWaypoint = currentPattern[currentPatrolStep]
		print("Following patrol pattern - TELEPORTING to waypoint", nextWaypoint)
		
		-- TELEPORT instead of pathfinding
		teleportFatherTo(nextWaypoint)
		
		currentPatrolStep = currentPatrolStep + 1
		
		-- Schedule next move
		scheduleNextMovement()
	else
		-- Patrol complete, start new one
		print("=== PATROL COMPLETE ===")
		patrolsCompleted = patrolsCompleted + 1
		currentPatrol = (currentPatrol % #patrolPatterns) + 1
		currentPatrolStep = 1
		
		print("Completed patrols:", patrolsCompleted, "Starting patrol:", currentPatrol)
		
		-- Small delay before next patrol
		spawn(function()
			wait(math.random(2, 4))
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

-- Enhanced debug commands
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
				print("jumpscareTriggered:", jumpscareTriggered)
				print("activeConnections:", #activeConnections)
				print("Father position:", fatherRootPart.Position)
			elseif message:lower() == "/forceroom" then
				print("FORCING ROOM CHECK")
				patrolsCompleted = 2
				chooseFatherNextMove()
			elseif message:lower() == "/reset" then
				print("RESETTING GAME STATE")
				cleanupConnections()
				isCheckingRoom = false
				fatherMoving = false
				movementDebounce = false
				jumpscareTriggered = false
				patrolsCompleted = 0
				currentPatrol = 1
				currentPatrolStep = 1
				chooseFatherNextMove()
			elseif message:lower():sub(1, 3) == "/tp" then
				local waypointNum = tonumber(message:lower():sub(5))
				if waypointNum and waypointNum >= 1 and waypointNum <= #waypoints then
					print("Teleporting father to waypoint", waypointNum)
					teleportFatherTo(waypointNum)
				end
			end
		end
	end)
end)

-- Start the game
spawn(function()
	print("=== INITIALIZING FIXED HORROR GAME ===")
	wait(math.random(3, 5))
	print("Starting teleport patrol system...")
	chooseFatherNextMove()
end)

print("FIXED Horror game initialized with proper connection management!")