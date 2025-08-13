-- Client Script (LocalScript in StarterPlayerScripts)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents with better error handling
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
	warn("RemoteEvents folder not found!")
	return
end

local updateFatherPosition = remoteEvents:WaitForChild("UpdateFatherPosition", 10)
local gameOverEvent = remoteEvents:WaitForChild("GameOver", 10)

if not updateFatherPosition then
	warn("UpdateFatherPosition event not found!")
	return
end

-- Find objects in workspace with better error handling
local computer = workspace:WaitForChild("Computer", 10) -- Wait up to 10 seconds
local bed = workspace:WaitForChild("Bed", 10) -- Wait up to 10 seconds

if not computer then
	warn("Computer not found in Workspace! Make sure it's named exactly 'Computer'")
	-- List what IS in workspace
	print("Current Workspace contents:")
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name ~= "Camera" and child.Name ~= "Terrain" and not child:IsA("Player") then
			print("  - " .. child.Name)
		end
	end
	return
end

if not bed then
	warn("Bed not found in Workspace! Make sure it's named exactly 'Bed'")
	return
end

print("Found Computer:", computer.Name)
print("Found Bed:", bed.Name)

-- Game state
local isAtComputer = false
local isInBed = false
local nearComputer = false
local nearBed = false
local fatherPosition = Vector3.new(0, 0, 0)
local inDangerZone = false

-- Create GUI (same as before)
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

-- [All the same GUI elements as before - computer title, camera frame, etc.]
local computerTitle = Instance.new("TextLabel")
computerTitle.Size = UDim2.new(1, 0, 0.1, 0)
computerTitle.Position = UDim2.new(0, 0, 0, 0)
computerTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
computerTitle.Text = "My Computer - Don't get caught!"
computerTitle.TextColor3 = Color3.fromRGB(255, 255, 255) -- Fixed: was Color3.white
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
gameLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Fixed: was Color3.white
gameLabel.TextScaled = true
gameLabel.Font = Enum.Font.SourceSans
gameLabel.Parent = gameFrame

local instructionsLabel = Instance.new("TextLabel")
instructionsLabel.Size = UDim2.new(1, 0, 0.15, 0)
instructionsLabel.Position = UDim2.new(0, 0, 0.85, 0)
instructionsLabel.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
instructionsLabel.Text = "Move closer to computer or bed..."
instructionsLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Fixed: was Color3.white
instructionsLabel.TextScaled = true
instructionsLabel.Font = Enum.Font.SourceSans
instructionsLabel.Parent = screenGui -- Put on main GUI so it shows always

-- Warning overlay
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
warningText.Text = "⚠️ DAD IS COMING! ⚠️\nRUN TO BED!"
warningText.TextColor3 = Color3.fromRGB(255, 255, 255) -- Fixed: was Color3.white
warningText.TextScaled = true
warningText.Font = Enum.Font.SourceSansBold
warningText.TextStrokeTransparency = 0
warningText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
warningText.Parent = warningFrame

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
			-- Use PrimaryPart if it exists
			objectPosition = object.PrimaryPart.Position
		else
			-- Find any Part in the model (searches through nested models too)
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
				warn("No parts found in model: " .. object.Name)
				return false
			end
		end
	else
		-- Object is a Part
		objectPosition = object.Position
	end

	local distance = (playerPosition - objectPosition).Magnitude
	return distance <= (maxDistance or 5)
end

-- Function to update proximity checks
local function updateProximity()
	nearComputer = isNearObject(computer, 5)
	nearBed = isNearObject(bed, 5)

	-- Update instructions based on what's nearby
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

	-- Change instruction color based on danger
	if inDangerZone then
		instructionsLabel.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
		instructionsLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	else
		instructionsLabel.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
		instructionsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- Function to update dad's location display
local function updateDadLocation(position, danger)
	local locationText = "Unknown"
	local status = "SAFE"

	-- [Same location detection code as before]
	local distance = {
		livingRoom = (position - Vector3.new(0, 0, 0)).Magnitude,
		kitchen = (position - Vector3.new(10, 0, 5)).Magnitude,
		hallway = (position - Vector3.new(-5, 0, 10)).Magnitude,
		bathroom = (position - Vector3.new(15, 0, -5)).Magnitude,
		kidsRoom = (position - Vector3.new(5, 0, 15)).Magnitude
	}

	local minDistance = math.huge
	local closestLocation = "Unknown"

	for location, dist in pairs(distance) do
		if dist < minDistance then
			minDistance = dist
			closestLocation = location
		end
	end

	if closestLocation == "livingRoom" then locationText = "Living Room"
	elseif closestLocation == "kitchen" then locationText = "Kitchen"
	elseif closestLocation == "hallway" then locationText = "Hallway"
	elseif closestLocation == "bathroom" then locationText = "Bathroom"
	elseif closestLocation == "kidsRoom" then locationText = "Near Your Room" end

	if danger or closestLocation == "kidsRoom" then
		status = "⚠️ DANGER! ⚠️"
		dadIndicator.TextColor3 = Color3.fromRGB(255, 0, 0)
		dadIndicator.BackgroundColor3 = Color3.fromRGB(50, 0, 0)

		inDangerZone = true
		warningFrame.Visible = true

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

-- Function to use computer
local function useComputer()
	if not nearComputer or isInBed then return end

	isAtComputer = not isAtComputer
	computerFrame.Visible = isAtComputer

	if isAtComputer then
		-- Lock camera to computer screen
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		-- Position camera to look at computer screen
		local computerPosition = computer.Position
		if computer:IsA("Model") and computer.PrimaryPart then
			computerPosition = computer.PrimaryPart.Position
		end
		workspace.CurrentCamera.CFrame = CFrame.lookAt(
			computerPosition + Vector3.new(0, 2, -3), 
			computerPosition
		)
	else
		-- Unlock camera
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

-- Function to exit computer (separate from useComputer for clarity)
local function exitComputer()
	if not isAtComputer then return end
	
	isAtComputer = false
	computerFrame.Visible = false
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

-- Function to get in bed
local function getInBed()
	if not nearBed then return end

	isInBed = not isInBed
	warningFrame.Visible = false

	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		if isInBed then
			-- Find bed position
			local bedPosition
			if bed:IsA("Model") then
				if bed.PrimaryPart then
					bedPosition = bed.PrimaryPart.Position + Vector3.new(0, 3, 0)
				else
					-- Find any part in the bed model
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
				-- Make player lay down (rotate)
				character.HumanoidRootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(90))
			end
		else
			-- Stand up
			character.HumanoidRootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(-90))
		end
	end
end

-- Function to exit bed (separate from getInBed for clarity)
local function exitBed()
	if not isInBed then return end
	
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		-- Stand up
		character.HumanoidRootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(-90))
		isInBed = false
		warningFrame.Visible = false
	end
end

-- Main loop to check proximity
RunService.Heartbeat:Connect(function()
	updateProximity()
end)

-- Fixed Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		-- E key: Use computer (only if not in bed and near computer)
		if not isInBed and nearComputer then
			useComputer()
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Q key: Context-sensitive exit/enter
		if isAtComputer then
			-- Exit computer if currently using it
			exitComputer()
		elseif isInBed then
			-- Exit bed if currently in bed
			exitBed()
		elseif nearBed and not isAtComputer then
			-- Enter bed if near bed and not using computer
			getInBed()
		end
	end
end)

-- Listen for father position updates
updateFatherPosition.OnClientEvent:Connect(function(position, danger)
	fatherPosition = position
	updateDadLocation(position, danger)
end)

print("Client script loaded!")