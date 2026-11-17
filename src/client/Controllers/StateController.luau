--!strict
-- Holds the latest Snapshot from the server and sends actions to it.
-- The client never changes data itself; it asks the server and redraws.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))

type Snapshot = Types.Snapshot

local StateController = {}

local current: Snapshot? = nil
local listeners: { (Snapshot) -> () } = {}
local notifyListeners: { (string, Color3?) -> () } = {}
local actionRemote: RemoteFunction? = nil

function StateController.get(): Snapshot?
	return current
end

function StateController.onChanged(callback: (Snapshot) -> ())
	table.insert(listeners, callback)
	if current then
		task.spawn(callback, current)
	end
end

function StateController.onNotify(callback: (string, Color3?) -> ())
	table.insert(notifyListeners, callback)
end

-- Sends an action to the server. Returns (ok, message).
function StateController.request(action: string, arg: any?): (boolean, string?)
	local remote = actionRemote or Net.func(Net.ACTION)
	actionRemote = remote
	local ok, success, message = pcall(remote.InvokeServer, remote, action, arg)
	if not ok then
		return false, "Connection problem, try again"
	end
	return success == true, message
end

function StateController.start()
	Net.event(Net.STATE).OnClientEvent:Connect(function(snapshot: Snapshot)
		current = snapshot
		for _, callback in listeners do
			task.spawn(callback, snapshot)
		end
	end)
	Net.event(Net.NOTIFY).OnClientEvent:Connect(function(text: string, color: Color3?)
		for _, callback in notifyListeners do
			task.spawn(callback, text, color)
		end
	end)
	StateController.request("Sync")
end

return StateController
