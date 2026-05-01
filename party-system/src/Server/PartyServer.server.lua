local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:WaitForChild("PartySystemRemotes")
local createPartyRemote = remotes:WaitForChild("CreateParty")
local joinPartyRemote = remotes:WaitForChild("JoinParty")
local leavePartyRemote = remotes:WaitForChild("LeaveParty")
local kickPlayerRemote = remotes:WaitForChild("KickPlayer")
local startGameRemote = remotes:WaitForChild("StartGame")
local getPartiesRemote = remotes:WaitForChild("GetParties")
local partyUpdatedRemote = remotes:WaitForChild("PartyUpdated")
local partyListUpdatedRemote = remotes:WaitForChild("PartyListUpdated")

local MAX_PARTY_SIZE = 4
local activeParties = {} 

local function getPlayerParty(player)
	for hostId, party in pairs(activeParties) do
		for _, member in ipairs(party.Members) do
			if member == player then
				return hostId, party
			end
		end
	end
	return nil, nil
end

local function broadcastPartyUpdate(party)
	local membersData = {}
	for _, member in ipairs(party.Members) do
		table.insert(membersData, {UserId = member.UserId, Name = member.Name})
	end

	local partyData = {
		HostId = party.Host.UserId,
		Members = membersData
	}

	for _, member in ipairs(party.Members) do
		partyUpdatedRemote:FireClient(member, partyData)
	end
end

createPartyRemote.OnServerInvoke = function(player)
	if getPlayerParty(player) then
		return false, "Already in a party"
	end

	activeParties[player.UserId] = {
		Host = player,
		Members = {player}
	}

	broadcastPartyUpdate(activeParties[player.UserId])
	partyListUpdatedRemote:FireAllClients()
	return true
end

joinPartyRemote.OnServerInvoke = function(player, hostUserId)
	if getPlayerParty(player) then
		return false, "Already in a party"
	end

	local party = activeParties[hostUserId]
	if not party then
		return false, "Party not found"
	end

	if #party.Members >= MAX_PARTY_SIZE then
		return false, "Party is full"
	end

	table.insert(party.Members, player)
	broadcastPartyUpdate(party)
	return true
end

leavePartyRemote.OnServerInvoke = function(player)
	local hostId, party = getPlayerParty(player)
	if not party then return false, "Not in a party" end

	if player == party.Host then

		local members = party.Members
		activeParties[hostId] = nil
		for _, member in ipairs(members) do
			if member ~= player then
				partyUpdatedRemote:FireClient(member, nil) 

			end
		end
		partyListUpdatedRemote:FireAllClients()
	else

		for i, member in ipairs(party.Members) do
			if member == player then
				table.remove(party.Members, i)
				break
			end
		end
		broadcastPartyUpdate(party)
	end
	return true
end

kickPlayerRemote.OnServerInvoke = function(player, targetUserId)
	local party = activeParties[player.UserId]
	if not party then return false, "You are not the host of a party" end

	for i, member in ipairs(party.Members) do
		if member.UserId == targetUserId and member ~= player then
			table.remove(party.Members, i)
			partyUpdatedRemote:FireClient(member, nil) 

			broadcastPartyUpdate(party)
			return true
		end
	end
	return false, "Player not found in party"
end

startGameRemote.OnServerInvoke = function(player)
	local party = activeParties[player.UserId]
	if not party then return false, "You are not the host of a party" end

	local members = party.Members
	local isStudio = RunService:IsStudio()
	local success = true
	local err = nil

	if isStudio then

		print("Mocking teleport in Studio for Party Host: " .. player.Name)
		local mockSpawnLocation = Vector3.new(0, 50, 0) 

		for _, member in ipairs(members) do
			if member.Character and member.Character.PrimaryPart then
				member.Character:PivotTo(CFrame.new(mockSpawnLocation + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))))
			end
		end
	else

		local placeId = game.PlaceId
		if placeId == 0 then
			return false, "PlaceId is 0. Publish the game to test TeleportService."
		end

		success, err = pcall(function()

			local reserveCode = TeleportService:ReserveServer(placeId)
			TeleportService:TeleportToPrivateServer(placeId, reserveCode, members)
		end)

		if not success then
			warn("Teleport failed: ", err)
			return false, "Teleport failed"
		end
	end

	activeParties[player.UserId] = nil
	for _, member in ipairs(members) do
		partyUpdatedRemote:FireClient(member, nil)
	end
	partyListUpdatedRemote:FireAllClients()

	return true
end

getPartiesRemote.OnServerInvoke = function(player)
	local list = {}
	for hostId, party in pairs(activeParties) do
		table.insert(list, {
			HostId = hostId,
			HostName = party.Host.Name,
			MemberCount = #party.Members,
			MaxMembers = MAX_PARTY_SIZE
		})
	end
	return list
end

Players.PlayerRemoving:Connect(function(player)
	local hostId, party = getPlayerParty(player)
	if party then
		if player == party.Host then
			activeParties[hostId] = nil
			for _, member in ipairs(party.Members) do
				if member ~= player then
					partyUpdatedRemote:FireClient(member, nil)
				end
			end
			partyListUpdatedRemote:FireAllClients()
		else
			for i, member in ipairs(party.Members) do
				if member == player then
					table.remove(party.Members, i)
					break
				end
			end
			broadcastPartyUpdate(party)
		end
	end
end)
