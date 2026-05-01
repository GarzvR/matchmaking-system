local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local PartyUI = PlayerGui:WaitForChild("PartyUI")

local mainFrame = PartyUI:WaitForChild("MainFrame")
local lobbyFrame = PartyUI:WaitForChild("LobbyFrame")
local joinFrame = PartyUI:WaitForChild("JoinFrame")

local remotes = ReplicatedStorage:WaitForChild("PartySystemRemotes")
local createPartyRemote = remotes:WaitForChild("CreateParty")
local joinPartyRemote = remotes:WaitForChild("JoinParty")
local leavePartyRemote = remotes:WaitForChild("LeaveParty")
local kickPlayerRemote = remotes:WaitForChild("KickPlayer")
local startGameRemote = remotes:WaitForChild("StartGame")
local getPartiesRemote = remotes:WaitForChild("GetParties")
local partyUpdatedRemote = remotes:WaitForChild("PartyUpdated")
local partyListUpdatedRemote = remotes:WaitForChild("PartyListUpdated")

local matchmakingZone = workspace:WaitForChild("MatchmakingZone", 10)
local DETECTION_RADIUS = 10

local inZone = false
local currentParty = nil -- nil or the party data table
local currentPanel = "Main" -- Main, Lobby, Join

local function updateUIVisibility()
	if not inZone then
		PartyUI.Enabled = false
		mainFrame.Visible = false
		lobbyFrame.Visible = false
		joinFrame.Visible = false
		return
	end
	
	PartyUI.Enabled = true
	mainFrame.Visible = (currentPanel == "Main")
	lobbyFrame.Visible = (currentPanel == "Lobby")
	joinFrame.Visible = (currentPanel == "Join")
end

local function populateMembersList()
	local membersList = lobbyFrame.MembersList
	-- Clear existing
	for _, child in ipairs(membersList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	if not currentParty then return end
	
	local isHost = (currentParty.HostId == player.UserId)
	lobbyFrame.StartGameBtn.Visible = isHost
	lobbyFrame.LeavePartyBtn.Text = isHost and "Close Room" or "Leave Party"
	
	for i, member in ipairs(currentParty.Members) do
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, 0, 0, 40)
		f.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		f.BorderSizePixel = 0
		
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, isHost and -80 or 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = member.Name .. (member.UserId == currentParty.HostId and " (Host)" or "")
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Font = Enum.Font.Gotham
		text.TextSize = 16
		text.Parent = f
		
		if isHost and member.UserId ~= player.UserId then
			local kickBtn = Instance.new("TextButton")
			kickBtn.Size = UDim2.new(0, 70, 0, 30)
			kickBtn.Position = UDim2.new(1, -75, 0.5, -15)
			kickBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			kickBtn.Text = "Kick"
			kickBtn.TextColor3 = Color3.new(1, 1, 1)
			kickBtn.Font = Enum.Font.GothamBold
			kickBtn.TextSize = 14
			kickBtn.Parent = f
			Instance.new("UICorner").Parent = kickBtn
			
			kickBtn.MouseButton1Click:Connect(function()
				kickPlayerRemote:InvokeServer(member.UserId)
			end)
		end
		
		f.Parent = membersList
	end
end

local function refreshJoinList()
	local partiesList = joinFrame.PartiesList
	for _, child in ipairs(partiesList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local parties = getPartiesRemote:InvokeServer()
	for _, party in ipairs(parties) do
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, 0, 0, 40)
		f.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		f.BorderSizePixel = 0
		
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -100, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = party.HostName .. "'s Party (" .. party.MemberCount .. "/" .. party.MaxMembers .. ")"
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Font = Enum.Font.Gotham
		text.TextSize = 16
		text.Parent = f
		
		local joinBtn = Instance.new("TextButton")
		joinBtn.Size = UDim2.new(0, 90, 0, 30)
		joinBtn.Position = UDim2.new(1, -95, 0.5, -15)
		joinBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
		joinBtn.Text = "Join"
		joinBtn.TextColor3 = Color3.new(1, 1, 1)
		joinBtn.Font = Enum.Font.GothamBold
		joinBtn.TextSize = 14
		joinBtn.Parent = f
		Instance.new("UICorner").Parent = joinBtn
		
		joinBtn.MouseButton1Click:Connect(function()
			local success, err = joinPartyRemote:InvokeServer(party.HostId)
			if success then
				-- Server will fire PartyUpdated, changing our view to Lobby
			else
				warn(err)
			end
		end)
		
		f.Parent = partiesList
	end
end

-- Hook up buttons
mainFrame.CreatePartyBtn.MouseButton1Click:Connect(function()
	local success, err = createPartyRemote:InvokeServer()
	if not success then warn(err) end
end)

mainFrame.JoinPartyBtn.MouseButton1Click:Connect(function()
	currentPanel = "Join"
	updateUIVisibility()
	refreshJoinList()
end)

joinFrame.BackBtn.MouseButton1Click:Connect(function()
	currentPanel = "Main"
	updateUIVisibility()
end)

joinFrame.RefreshBtn.MouseButton1Click:Connect(refreshJoinList)

lobbyFrame.LeavePartyBtn.MouseButton1Click:Connect(function()
	local success, err = leavePartyRemote:InvokeServer()
	if not success then warn(err) end
end)

lobbyFrame.StartGameBtn.MouseButton1Click:Connect(function()
	lobbyFrame.StartGameBtn.Text = "Starting..."
	local success, err = startGameRemote:InvokeServer()
	if not success then
		warn(err)
	end
	-- We always reset the text in case of failure or before closing
	lobbyFrame.StartGameBtn.Text = "Start Game"
end)

-- Server Events
partyUpdatedRemote.OnClientEvent:Connect(function(partyData)
	currentParty = partyData
	if currentParty then
		currentPanel = "Lobby"
		populateMembersList()
	else
		currentPanel = "Main"
	end
	updateUIVisibility()
end)

partyListUpdatedRemote.OnClientEvent:Connect(function()
	if currentPanel == "Join" then
		refreshJoinList()
	end
end)

-- Distance Detection
RunService.Heartbeat:Connect(function()
	local char = player.Character
	if not char or not char.PrimaryPart or not matchmakingZone then
		if inZone then
			inZone = false
			updateUIVisibility()
		end
		return
	end
	
	-- Flatten Y axis to ignore height
	local pPos = char.PrimaryPart.Position
	local zPos = matchmakingZone.Position
	local dist = Vector2.new(pPos.X, pPos.Z) - Vector2.new(zPos.X, zPos.Z)
	
	local nowInZone = dist.Magnitude <= DETECTION_RADIUS
	
	if nowInZone ~= inZone then
		inZone = nowInZone
		updateUIVisibility()
	end
end)
