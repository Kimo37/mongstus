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

local jumpscareEvent = Instance.new("RemoteEvent")
jumpscareEvent.Name = "JumpscareEvent"
jumpscareEvent.Parent = remoteEvents

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

-- Special positions for kid's room entry
local kidsRoomDoorPosition = Vector3.new(-75.4, 5.095, -40.444) -- Door to kid's room
local kidsRoomPosition = Vector3.new(-75.4, 5.095, -48.444) -- Inside kid's room

-- Game state
local gameActive = true
local fatherCurrentWaypoint = 1
local fatherMoving = false
local movementDebounce = false
local isInKidsRoom = false
local jumpscareCooldown = false
local jumpscareDebounceTime = 5 -- 5 seconds between jumpscare checks

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

-- Function to teleport father instantly to a position
local function teleportFatherTo(targetPosition)
	print("=== TELEPORTING FATHER ===")
	print("From:", fatherRootPart.Position)
	print("To:", targetPosition)
	
	fatherRootPart.CFrame = CFrame.new(targetPosition)
	
	-- Update all players about father's new position
	updateFatherPosition:FireAllClients(targetPosition)
	
	print("Teleportation complete!")
end

-- Function to move father to kid's room using pathfinding (only time we pathfind)
local function pathfindToKidsRoom()
	if not gameActive or fatherMoving then 
		print("Movement blocked - gameActive:", gameActive, "fatherMoving:", fatherMoving)
		return 
	end

	fatherMoving = true
	print("=== PATHFINDING TO KID'S ROOM ===")
	print("Moving father from door to kid's room")
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
		path:ComputeAsync(fatherRootPart.Position, kidsRoomPosition)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local pathWaypoints = path:GetWaypoints()
		print("Pathfinding successful! Found", #pathWaypoints, "waypoints")

		-- Update all players about father's movement
		updateFatherPosition:FireAllClients(kidsRoomPosition, true) -- true = danger zone

		-- Move through each waypoint
		local waypointIndex = 1
		local function moveToNextWaypoint()
			if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
				local waypoint = pathWaypoints[waypointIndex]
				print("Moving to waypoint", waypointIndex, "of", #pathWaypoints, "at position:", waypoint.Position)

				-- Handle jumping if needed
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					print("Jumping at waypoint", waypointIndex)
					fatherHumanoid.Jump = true
				end

				fatherHumanoid:MoveTo(waypoint.Position)

				local connection
				local timeoutConnection

				connection = fatherHumanoid.MoveToFinished:Connect(function(reached)
					print("Waypoint", waypointIndex, "finished. Reached:", reached)
					connection:Disconnect()
					if timeoutConnection then timeoutConnection:Disconnect() end

					waypointIndex = waypointIndex + 1

					if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
						print("Moving to next waypoint:", waypointIndex)
						moveToNextWaypoint()
					else
						-- Movement complete - father is now in kid's room
						print("=== FATHER ENTERED KID'S ROOM ===")
						isInKidsRoom = true
						fatherMoving = false

						-- Trigger jumpscare after a short delay
						spawn(function()
							wait(2) -- 2 second delay before jumpscare
							if gameActive and isInKidsRoom and not jumpscareCooldown then
								jumpscareCooldown = true
								print("TRIGGERING JUMPSCARE!")
								jumpscareEvent:FireAllClients()
								gameOverEvent:FireAllClients()
								gameActive = false
							end
						end)
					end
				end)

				-- Timeout for each waypoint
				timeoutConnection = spawn(function()
					wait(10) -- 10 second timeout per waypoint
					if connection then
						print("Waypoint", waypointIndex, "timed out")
						connection:Disconnect()
						if timeoutConnection then timeoutConnection:Disconnect() end

						waypointIndex = waypointIndex + 1
						if waypointIndex <= #pathWaypoints and gameActive and fatherMoving then
							print("Moving to next waypoint after timeout:", waypointIndex)
							moveToNextWaypoint()
						else
							print("=== MOVEMENT TIMED OUT ===")
							fatherMoving = false
							isInKidsRoom = true -- Assume we made it
							scheduleNextMovement()
						end
					end
				end)
			else
				print("Cannot continue waypoint movement")
				fatherMoving = false
				isInKidsRoom = true
				scheduleNextMovement()
			end
		end

		-- Start moving through waypoints
		moveToNextWaypoint()

	else
		-- Pathfinding failed, teleport as fallback
		print("=== PATHFINDING FAILED ===")
		print("Error:", errorMessage)
		print("Using teleport fallback")

		teleportFatherTo(kidsRoomPosition)
		isInKidsRoom = true
		fatherMoving = false

		-- Trigger jumpscare after teleport
		spawn(function()
			wait(2)
			if gameActive and isInKidsRoom and not jumpscareCooldown then
				jumpscareCooldown = true
				print("TRIGGERING JUMPSCARE!")
				jumpscareEvent:FireAllClients()
				gameOverEvent:FireAllClients()
				gameActive = false
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
	print("Is in kid's room:", isInKidsRoom)

	-- If father is in kid's room, he stays there (game over scenario)
	if isInKidsRoom then
		print("Father is in kid's room - staying there")
		return
	end

	-- Random chance to move or stay put
	local moveChance = math.random()
	print("Move chance:", moveChance)

	if moveChance < 0.8 then -- 80% chance to move
		-- Small chance to go to kid's room door (danger!)
		local goToKidsRoom = math.random() < 0.15 -- 15% chance to approach kid's room
		
		if goToKidsRoom then
			print("Father is approaching the kid's room door!")
			teleportFatherTo(kidsRoomDoorPosition)
			
			-- After reaching the door, decide whether to enter
			spawn(function()
				local waitTime = math.random(2, 5)
				wait(waitTime)
				
				if gameActive then
					local enterChance = math.random()
					if enterChance < 0.7 then -- 70% chance to enter once at door
						print("Father is entering the kid's room!")
						pathfindToKidsRoom()
					else
						print("Father decided not to enter the room")
						scheduleNextMovement()
					end
				end
			end)
		else
			-- Normal waypoint movement (teleport)
			local nextWaypoint = math.random(1, #waypoints)
			-- Don't move to the same spot
			local attempts = 0
			while nextWaypoint == fatherCurrentWaypoint and attempts < 10 do
				nextWaypoint = math.random(1, #waypoints)
				attempts = attempts + 1
			end

			print("Father teleporting from waypoint", fatherCurrentWaypoint, "to", nextWaypoint)
			print("Target position:", waypoints[nextWaypoint])
			fatherCurrentWaypoint = nextWaypoint
			
			fatherMoving = true
			teleportFatherTo(waypoints[nextWaypoint])
			
			-- Brief delay to show the teleport, then schedule next move
			spawn(function()
				wait(1)
				fatherMoving = false
				scheduleNextMovement()
			end)
		end
	else
		-- Stay put for a while, then try again
		print("Father staying put for a while")
		spawn(function()
			local waitTime = math.random(3, 6)
			print("Staying put for", waitTime, "seconds")
			wait(waitTime)
			if gameActive and not isInKidsRoom then
				print("Finished staying put, choosing next move")
				chooseFatherNextMove()
			end
		end)
	end
end

-- Function to check if players are hiding properly (improved proximity detection)
local function checkProximityToFather()
	if not gameActive or jumpscareCooldown then return end
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerPosition = player.Character.HumanoidRootPart.Position
			local distance = (fatherRootPart.Position - playerPosition).Magnitude

			-- If player is too close to father (not in kid's room scenario)
			if distance < 10 and not isInKidsRoom then
				print("Player", player.Name, "is too close to father! Distance:", distance)
				jumpscareCooldown = true
				
				-- Trigger jumpscare for being caught
				jumpscareEvent:FireClient(player)
				gameOverEvent:FireClient(player)
				
				-- Reset jumpscare cooldown after delay
				spawn(function()
					wait(jumpscareDebounceTime)
					jumpscareCooldown = false
				end)
				
				break -- Only trigger for one player at a time
			end
		end
	end
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Send initial father position to new player
		updateFatherPosition:FireClient(player, fatherRootPart.Position)
	end)
end)

-- Main game loop with reduced frequency for proximity checking
local proximityCheckInterval = 0
RunService.Heartbeat:Connect(function()
	if gameActive then
		proximityCheckInterval = proximityCheckInterval + 1
		
		-- Only check proximity every 30 frames (roughly twice per second)
		if proximityCheckInterval >= 30 then
			checkProximityToFather()
			proximityCheckInterval = 0
		end
	end
end)

-- Debug command to manually trigger movement
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
				print("isInKidsRoom:", isInKidsRoom)
				print("jumpscareCooldown:", jumpscareCooldown)
				print("Father position:", fatherRootPart.Position)
			elseif message:lower() == "/reset" then
				print("Resetting game state by", player.Name)
				gameActive = true
				fatherMoving = false
				movementDebounce = false
				isInKidsRoom = false
				jumpscareCooldown = false
				chooseFatherNextMove()
			elseif message:lower() == "/kidroom" then
				print("Forcing father to kid's room by", player.Name)
				teleportFatherTo(kidsRoomDoorPosition)
				spawn(function()
					wait(2)
					pathfindToKidsRoom()
				end)
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

print("Horror game initialized with teleport movement and fixed jumpscare system!")