--!strict
-- Finds (client) or creates (server) the game's RemoteEvents and RemoteFunctions
-- in ReplicatedStorage.Remotes. Every remote name lives here so the two sides
-- can never disagree on spelling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local Net = {
	STATE = "State", -- server -> client: full Snapshot whenever data changes
	NOTIFY = "Notify", -- server -> client: (text, color?) toast message
	ACTION = "Action", -- client -> server: (actionName, arg) -> (ok, message?)
}

local function getFolder(): Instance
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end
	if IS_SERVER then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function getRemote(name: string, className: string): Instance
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if IS_SERVER then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return getRemote(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return getRemote(name, "RemoteFunction") :: RemoteFunction
end

return Net
