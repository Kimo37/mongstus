-- Enhanced Horror Game Client Script
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
	warn("RemoteEvents folder not found!")
	return
end

local updateFatherPosition = remoteEvents:WaitForChild("UpdateFatherPosition", 10)
local gameOverEvent = remoteEvents:WaitForChild("GameOver", 10)
local jumpscareEvent = remoteEvents:WaitForChild("Jumpscare", 10)

-- Find objects in workspace
local computer = workspace:WaitForChild("Computer", 10)
local bed = workspace:WaitForChild("Bed", 10)

if not computer or not bed then
	warn("Computer or Bed not found!")
	return
end

-- Game state
local isAtComputer = false
local isInBed = false
local nearComputer = false
local nearBed = false
local fatherPosition = Vector3.new(0, 0, 0)
local inDangerZone = false
local gameOver = false

-- Enhanced waypoint positions (matching server script)
local waypoints = {
	{position = Vector3.new(-124.497, 5.295, -13.348), name = "Living Room"},
	{position = Vector3.new(-162.4, 5.095, -17.444), name = "Kitchen"},
	{position = Vector3.new(-103.4, 5.095, -29.444), name = "Hallway"},
	{position = Vector3.new(-67.9, 5.095, -28.944), name = "Bathroom"},
	{position = Vector3.new(-102.9, 5.095, -11.944), name = "Another Room"},
	{position = Vector3.new(-84.9, 5.095, -30.944), name = "Near Your Room"},
	{position = Vector3.new(-75.4, 5.095, -48.444), name = "IN YOUR ROOM!"} -- NEW!
}

-- Create main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HorrorGameGui"
screenGui.Parent = playerGui

-- Computer screen GUI
local computerFrame = Instance.new("Frame")
computerFrame.Size = UDim2.new(0.8, 0, 0.8, 0)
computerFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
computerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
computerFrame.BorderSizePixel = 2
computerFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
computerFrame.Visible = false
computerFrame.Parent = screenGui

local computerTitle = Instance.new("TextLabel")
computerTitle.Size = UDim2.new(1, 0, 0.1, 0)
computerTitle.Position = UDim2.new(0, 0, 0, 0)
computerTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
computerTitle.Text = "My Computer - Don't get caught!"
computerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
computerTitle.TextScaled = true
computerTitle.Font = Enum.Font.Code
computerTitle.Parent = computerFrame

local cameraFrame = Instance.new("Frame")
cameraFrame.Size = UDim2.new(0.4, 0, 0.6, 0)
cameraFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
cameraFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
cameraFrame.BorderSizePixel = 1
cameraFrame.BorderColor3 = Color3.fromRGB(0, 255, 0)
cameraFrame.Parent = computerFrame

local cameraLabel = Instance.new("TextLabel")
cameraLabel.Size = UDim2.new(1, 0, 0.1, 0)
cameraLabel.Position = UDim2.new(0, 0, 0, 0)
cameraLabel.BackgroundColor3 = Color3.fromRGB(0, 50, 0)
cameraLabel.Text = "SECURITY CAMERA - DAD TRACKER"
cameraLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
cameraLabel.TextScaled = true
cameraLabel.Font = Enum.Font.Code
cameraLabel.Parent = cameraFrame

local dadIndicator = Instance.new("TextLabel")
dadIndicator.Size = UDim2.new(1, 0, 0.8, 0)
dadIndicator.Position = UDim2.new(0, 0, 0.1, 0)
dadIndicator.BackgroundColor3 = Color3.fromRGB(0, 20, 0)
dadIndicator.Text = "Dad Location: Living Room\nStatus: SAFE"
dadIndicator.TextColor3 = Color3.fromRGB(0, 255, 0)
dadIndicator.TextScaled = true
dadIndicator.Font = Enum.Font.Code
dadIndicator.TextWrapped = true
dadIndicator.Parent = cameraFrame

local gameFrame = Instance.new("Frame")
gameFrame.Size = UDim2.new(0.4, 0, 0.6, 0)
gameFrame.Position = UDim2.new(0.5, 0, 0.15, 0)
gameFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
gameFrame.BorderSizePixel = 1
gameFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
gameFrame.Parent = computerFrame

local gameLabel = Instance.new("TextLabel")
gameLabel.Size = UDim2.new(1, 0, 0.2, 0)
gameLabel.Position = UDim2.new(0, 0, 0, 0)
gameLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
gameLabel.Text = "Totally Not Playing Games"
gameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
gameLabel.TextScaled = true
gameLabel.Font = Enum.Font.SourceSans
gameLabel.Parent = gameFrame

local instructionsLabel = Instance.new("TextLabel")
instructionsLabel.Size = UDim2.new(1, 0, 0.15, 0)
instructionsLabel.Position = UDim2.new(0, 0, 0.85, 0)
instructionsLabel.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
instructionsLabel.Text = "Move closer to computer or bed..."
instructionsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
instructionsLabel.TextScaled = true
instructionsLabel.Font = Enum.Font.SourceSans
instructionsLabel.Parent = screenGui

-- Enhanced Warning overlay
local warningFrame = Instance.new("Frame")
warningFrame.Size = UDim2.new(1, 0, 1, 0)
warningFrame.Position = UDim2.new(0, 0, 0, 0)
warningFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
warningFrame.BackgroundTransparency = 0.7
warningFrame.Visible = false
warningFrame.Parent = screenGui

local warningText = Instance.new("TextLabel")
warningText.Size = UDim2.new(0.8, 0, 0.3, 0)
warningText.Position = UDim2.new(0.1, 0, 0.35, 0)
warningText.BackgroundTransparency = 1
warningText.Text = "⚠️ DAD IS COMING! ⚠️\nGET TO BED NOW!"
warningText.TextColor3 = Color3.fromRGB(255, 255, 255)
warningText.TextScaled = true
warningText.Font = Enum.Font.SourceSansBold
warningText.TextStrokeTransparency = 0
warningText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
warningText.Parent = warningFrame

-- JUMPSCARE SCREEN
local jumpscareFrame = Instance.new("Frame")
jumpscareFrame.Size = UDim2.new(1, 0, 1, 0)
jumpscareFrame.Position = UDim2.new(0, 0, 0, 0)
jumpscareFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
jumpscareFrame.Visible = false
jumpscareFrame.Parent = screenGui

local jumpscareImage = Instance.new("ImageLabel")
jumpscareImage.Size = UDim2.new(1, 0, 1, 0)
jumpscareImage.Position = UDim2.new(0, 0, 0, 0)
jumpscareImage.BackgroundTransparency = 1
jumpscareImage.Image = "rbxassetid://0" -- You can add a scary image ID here
jumpscareImage.ScaleType = Enum.ScaleType.Stretch
jumpscareImage.Parent = jumpscareFrame

local jumpscareText = Instance.new("TextLabel")
jumpscareText.Size = UDim2.new(1, 0, 0.3, 0)
jumpscareText.Position = UDim2.new(0, 0, 0.35, 0)
jumpscareText.BackgroundTransparency = 1
jumpscareText.Text = "YOU WERE CAUGHT!\nYOU SHOULD HAVE BEEN SLEEPING!"
jumpscareText.TextColor3 = Color3.fromRGB(255, 0, 0)
jumpscareText.TextScaled = true
jumpscareText.Font = Enum.Font.SourceSansBold
jumpscareText.TextStrokeTransparency = 0
jumpscareText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
jumpscareText.Parent = jumpscareFrame

local gameOverText = Instance.new("TextLabel")
gameOverText.Size = UDim2.new(1, 0, 0.15, 0)
gameOverText.Position = UDim2.new(0, 0, 0.7, 0)
gameOverText.BackgroundTransparency = 1
gameOverText.Text = "Press R to restart..."
gameOverText.TextColor3 = Color3.fromRGB(255, 255, 255)
gameOverText.TextScaled = true
gameOverText.Font = Enum.Font.SourceSans
gameOverText.Parent = jumpscareFrame

-- Function to check if player is near an object
local function isNearObject(object, maxDistance)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end

	local playerPosition = character.HumanoidRootPart.Position
	local objectPosition

	if object:IsA("Model") then
		if object.PrimaryPart then
			objectPosition = object.PrimaryPart.Position
		else
			local function findFirstPart(parent)
				for _, child in pairs(parent:GetChildren()) do
					if child:IsA("Part") then
						return child
					elseif child:IsA("Model") then
						local found = findFirstPart(child)
						if found then return found end
					end
				end
				return nil
			end

			local firstPart = findFirstPart(object)
			if firstPart then
				objectPosition = firstPart.Position
			else
				return false
			end
		end
	else
		objectPosition = object.Position
	end

	local distance = (playerPosition - objectPosition).Magnitude
	return distance <= (maxDistance or 5)
end

-- Function to update proximity checks
local function updateProximity()
	if gameOver then return end
	
	nearComputer = isNearObject(computer, 5)
	nearBed = isNearObject(bed, 5)

	local instructionText = ""

	if isAtComputer then
		instructionText = "Using computer... Watch the camera! Press Q to exit computer!"
	elseif isInBed then
		instructionText = "Pretending to sleep... Press Q to get out of bed!"
	elseif inDangerZone and nearBed then
		instructionText = "⚠️ DANGER! Press Q to jump in bed! ⚠️"
	elseif nearComputer and not isInBed then
		instructionText = "Press E to use computer"
	elseif nearBed and not isAtComputer then
		instructionText = "Press Q to get in bed"
	else
		instructionText = "Move closer to computer or bed..."
	end

	instructionsLabel.Text = instructionText

	if inDangerZone then
		instructionsLabel.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
		instructionsLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	else
		instructionsLabel.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
		instructionsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- Enhanced function to update dad's location display
local function updateDadLocation(position, danger)
	if gameOver then return end
	
	local locationText = "Unknown"
	local status = "SAFE"

	-- Find the closest waypoint to father's position
	local minDistance = math.huge
	local closestWaypoint = nil

	for i, waypoint in ipairs(waypoints) do
		local distance = (position - waypoint.position).Magnitude
		if distance < minDistance then
			minDistance = distance
			closestWaypoint = waypoint
		end
	end

	if closestWaypoint then
		locationText = closestWaypoint.name
	end

	-- Special handling for room invasion
	if closestWaypoint and closestWaypoint.name == "IN YOUR ROOM!" then
		status = "🚨 HE'S IN YOUR ROOM! 🚨"
		dadIndicator.TextColor3 = Color3.fromRGB(255, 255, 0)
		dadIndicator.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
		
		inDangerZone = true
		warningFrame.Visible = true
		warningText.Text = "🚨 HE'S IN YOUR ROOM! 🚨\nSTAY IN BED!"
		
	elseif danger or (closestWaypoint and closestWaypoint.name == "Near Your Room") then
		status = "⚠️ DANGER! ⚠️"
		dadIndicator.TextColor3 = Color3.fromRGB(255, 0, 0)
		dadIndicator.BackgroundColor3 = Color3.fromRGB(50, 0, 0)

		inDangerZone = true
		warningFrame.Visible = true
		warningText.Text = "⚠️ DAD IS COMING! ⚠️\nGET TO BED NOW!"

		local flashTween = TweenService:Create(warningFrame, 
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{BackgroundTransparency = 0.3}
		)
		flashTween:Play()
	else
		status = "SAFE"
		dadIndicator.TextColor3 = Color3.fromRGB(0, 255, 0)
		dadIndicator.BackgroundColor3 = Color3.fromRGB(0, 20, 0)

		inDangerZone = false
		warningFrame.Visible = false
	end

	dadIndicator.Text = "Dad Location: " .. locationText .. "\nStatus: " .. status
end

-- Function to trigger jumpscare
local function triggerJumpscare()
	print("JUMPSCARE TRIGGERED!")
	gameOver = true
	
	-- Hide all other UI
	computerFrame.Visible = false
	warningFrame.Visible = false
	instructionsLabel.Visible = false
	
	-- Reset camera
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	
	-- Show jumpscare
	jumpscareFrame.Visible = true
	
	-- Jumpscare effects
	jumpscareFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	
	-- Flash effect
	local flashTween = TweenService:Create(jumpscareFrame,
		TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 5, true),
		{BackgroundColor3 = Color3.fromRGB(0, 0, 0)}
	)
	flashTween:Play()
	
	-- Shake effect for jumpscare text
	spawn(function()
		for i = 1, 20 do
			jumpscareText.Position = UDim2.new(0, math.random(-10, 10), 0.35, math.random(-5, 5))
			wait(0.1)
		end
		jumpscareText.Position = UDim2.new(0, 0, 0.35, 0)
	end)
	
	-- Play jumpscare sound (if you have one)
	-- local jumpscareSound = Instance.new("Sound")
	-- jumpscareSound.SoundId = "rbxassetid://YourSoundID"
	-- jumpscareSound.Volume = 1
	-- jumpscareSound.Parent = workspace
	-- jumpscareSound:Play()
end

-- Function to restart game
local function restartGame()
	gameOver = false
	isAtComputer = false
	isInBed = false
	inDangerZone = false
	
	jumpscareFrame.Visible = false
	instructionsLabel.Visible = true
	warningFrame.Visible = false
	
	-- Reset player position if needed
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character.HumanoidRootPart.CFrame = CFrame.new(-75.4, 7, -48.444) -- Spawn near bed
	end
	
	print("Game restarted!")
end

-- Computer and bed functions (same as before but with game over check)
local function useComputer()
	if gameOver or not nearComputer or isInBed then return end
	
	isAtComputer = not isAtComputer
	computerFrame.Visible = isAtComputer

	if isAtComputer then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		
		local computerPosition
		if computer:IsA("Model") then
			if computer.PrimaryPart then
				computerPosition = computer.PrimaryPart.Position
			else
				local function findFirstPart(parent)
					for _, child in pairs(parent:GetChildren()) do
						if child:IsA("Part") then
							return child
						elseif child:IsA("Model") then
							local found = findFirstPart(child)
							if found then return found end
						end
					end
					return nil
				end
				local computerPart = findFirstPart(computer)
				if computerPart then
					computerPosition = computerPart.Position
				end
			end
		else
			computerPosition = computer.Position
		end
		
		if computerPosition then
			workspace.CurrentCamera.CFrame = CFrame.lookAt(
				computerPosition + Vector3.new(0, 2, -3), 
				computerPosition
			)
		end
	else
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

local function exitComputer()
	if gameOver or not isAtComputer then return end
	
	isAtComputer = false
	computerFrame.Visible = false
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function getInBed()
	if gameOver or not nearBed then return end

	isInBed = not isInBed
	warningFrame.Visible = false

	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		if isInBed then
			local bedPosition
			if bed:IsA("Model") then
				if bed.PrimaryPart then
					bedPosition = bed.PrimaryPart.Position + Vector3.new(0, 3, 0)
				else
					local function findFirstPart(parent)
						for _, child in pairs(parent:GetChildren()) do
							if child:IsA("Part") then
								return child
							elseif child:IsA("Model") then
								local found = findFirstPart(child)
								if found then return found end
							end
						end
						return nil
					end
					local bedPart = findFirstPart(bed)
					if bedPart then
						bedPosition = bedPart.Position + Vector3.new(0, 3, 0)
					end
				end
			else
				bedPosition = bed.Position + Vector3.new(0, 3, 0)
			end

			if bedPosition then
				character.HumanoidRootPart.CFrame = CFrame.new(bedPosition)
				character.HumanoidRootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(90))
			end
		else
			character.HumanoidRootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(-90))
		end
	end
end

local function exitBed()
	if gameOver or not isInBed then return end
	
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character.HumanoidRootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(-90))
		isInBed = false
		warningFrame.Visible = false
	end
end

-- Main loop
RunService.Heartbeat:Connect(function()
	updateProximity()
end)

-- Enhanced input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.R and gameOver then
		restartGame()
	elseif not gameOver then
		if input.KeyCode == Enum.KeyCode.E then
			if not isInBed and nearComputer then
				useComputer()
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			if isAtComputer then
				exitComputer()
			elseif isInBed then
				exitBed()
			elseif nearBed and not isAtComputer then
				getInBed()
			end
		end
	end
end)

-- Listen for server events
updateFatherPosition.OnClientEvent:Connect(function(position, danger)
	fatherPosition = position
	updateDadLocation(position, danger)
end)

jumpscareEvent.OnClientEvent:Connect(function()
	triggerJumpscare()
end)

print("Enhanced client script loaded with jumpscare system!")