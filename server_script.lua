-- Enhanced Horror Game Server Script (FIXED BUGS - NO MORE SPAM)
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

-- Function to trigger jumpscare for specific players (PROTECTED AGAINST SPAM)
local jumpscareTriggered = false
local function triggerJumpscare(players)
	if jumpscareTriggered then
		print("Jumpscare already triggered, skipping...")
		return
	end
	
	jumpscareTriggered = true
	print("=== TRIGGERING JUMPSCARE ===")
	
	for _, player in pairs(players) do
		jumpscareEvent:FireClient(player)
		print("Jumpscare fired for", player.Name)
	end
	
	-- Reset flag after a delay
	spawn(function()
		wait(5)
		jumpscareTriggered = false
		print("Jumpscare flag reset")
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

-- Function to complete room check and resume patrol
local function completeRoomCheck()
	print("=== COMPLETING ROOM CHECK ===")
	
	-- Clean up any lingering connections
	cleanupConnections()
	
	-- Reset state
	isCheckingRoom = false
	fatherMoving = false
	jumpscareTriggered = false
	
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

-- Function to perform room check (COMPLETELY REWRITTEN - NO MORE SPAM)
local function performRoomCheck()
	print("=== PERFORMING ROOM CHECK ===")
	print("Patrols completed before room check:", patrolsCompleted)
	isCheckingRoom = true
	jumpscareTriggered = false -- Reset jumpscare flag
	
	-- Clean up any existing connections first
	cleanupConnections()
	
	-- First teleport to outside room (waypoint 6)
	print("Teleporting to room entrance...")
	teleportFatherTo(6) -- Teleport to danger zone
	updateFatherPosition:FireAllClients(waypoints[6], true) -- Send danger warning
	
	-- Wait 3 seconds for tension
	spawn(function()
		wait(3)
		
		if not gameActive or not isCheckingRoom then return end
		
		-- Now PATHFIND into the room (only time we pathfind)
		print("Pathfinding into room...")
		fatherMoving = true
		
		-- Move to room entrance first
		fatherHumanoid:MoveTo(waypoints[7])
		
		-- Create connection for room entrance
		local enterConnection
		enterConnection = fatherHumanoid.MoveToFinished:Connect(function(reached)
			print("Father reached room entrance!")
			
			-- Immediately disconnect this connection
			if enterConnection then
				enterConnection:Disconnect()
				enterConnection = nil
			end
			
			if not gameActive or not isCheckingRoom then 
				completeRoomCheck()
				return 
			end
			
			-- Send "IN YOUR ROOM" signal
			updateFatherPosition:FireAllClients(ROOM_CENTER, true)
			
			-- Short pause then move to center
			wait(1)
			
			print("Moving to room center...")
			fatherHumanoid:MoveTo(waypoints[8]) -- Room center
			
			-- Create connection for room center
			local centerConnection
			centerConnection = fatherHumanoid.MoveToFinished:Connect(function(reachedCenter)
				print("Father reached room center!")
				
				-- Immediately disconnect this connection
				if centerConnection then
					centerConnection:Disconnect()
					centerConnection = nil
				end
				
				if not gameActive or not isCheckingRoom then 
					completeRoomCheck()
					return 
				end
				
				-- Check player status ONCE
				local playersInBed, playersAwake = getPlayersInBed()
				
				if #playersAwake > 0 and not jumpscareTriggered then
					print("Players caught awake:", #playersAwake)
					triggerJumpscare(playersAwake)
				else
					print("All players safe in bed")
				end
				
				-- Wait then leave
				wait(2)
				print("Father leaving room...")
				
				-- Teleport back outside
				teleportFatherTo(6)
				wait(1)
				
				-- Complete the room check
				completeRoomCheck()
			end)
			
			-- Timeout for center movement (8 seconds)
			spawn(function()
				wait(8)
				if centerConnection then
					print("Center movement timed out")
					centerConnection:Disconnect()
					centerConnection = nil
					
					if not jumpscareTriggered then
						-- Still do the check even if timed out
						local playersInBed, playersAwake = getPlayersInBed()
						
						if #playersAwake > 0 then
							print("Players caught awake (timeout):", #playersAwake)
							triggerJumpscare(playersAwake)
						end
					end
					
					-- Leave and complete
					wait(1)
					teleportFatherTo(1)
					completeRoomCheck()
				end
			end)
		end)
		
		-- Timeout for room entry (10 seconds)
		spawn(function()
			wait(10)
			if enterConnection then
				print("Room entry timed out")
				enterConnection:Disconnect()
				enterConnection = nil
				
				-- Teleport away and complete
				teleportFatherTo(1)
				completeRoomCheck()
			end
		end)
	end)
end

-- Function to schedule next movement
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

-- Enhanced movement selection (with teleports)
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
			if gameActive and not isCheckingRoom then
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
				cleanupConnections()
				isCheckingRoom = false
				fatherMoving = false
				performRoomCheck()
			elseif message:lower() == "/jumpscare" then
				print("Manual jumpscare triggered")
				triggerJumpscare({player})
			elseif message:lower() == "/status" then
				print("=== FATHER STATUS ===")
				print("gameActive:", gameActive)
				print("fatherMoving:", fatherMoving)
				print("isCheckingRoom:", isCheckingRoom)
				print("jumpscareTriggered:", jumpscareTriggered)
				print("currentPatrol:", currentPatrol)
				print("currentPatrolStep:", currentPatrolStep)
				print("patrolsCompleted:", patrolsCompleted)
				print("Active connections:", #activeConnections)
				print("Father position:", fatherRootPart.Position)
			elseif message:lower() == "/forceroom" then
				print("FORCING ROOM CHECK")
				patrolsCompleted = 2
				cleanupConnections()
				chooseFatherNextMove()
			elseif message:lower() == "/cleanup" then
				print("Manual cleanup triggered")
				cleanupConnections()
				isCheckingRoom = false
				fatherMoving = false
				jumpscareTriggered = false
			elseif message:lower():sub(1, 3) == "/tp" then
				local waypointNum = tonumber(message:lower():sub(5))
				if waypointNum and waypointNum >= 1 and waypointNum <= #waypoints then
					print("Teleporting father to waypoint", waypointNum)
					cleanupConnections()
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

print("FIXED Horror game initialized - NO MORE SPAM!")