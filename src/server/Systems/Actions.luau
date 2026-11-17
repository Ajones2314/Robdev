--!strict
-- The single doorway for client requests. Systems register named handlers here;
-- this module checks the request shape and rate-limits each player before any
-- handler runs. Handlers must still validate their own `arg`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

export type Handler = (player: Player, arg: unknown) -> (boolean, string?)

local RATE_PER_SECOND = 8
local BURST = 15

local Actions = {}

local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { tokens: number, last: number } } = {}

function Actions.register(name: string, handler: Handler)
	assert(handlers[name] == nil, `Action {name} registered twice`)
	handlers[name] = handler
end

local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = BURST, last = now }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(BURST, bucket.tokens + (now - bucket.last) * RATE_PER_SECOND)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function Actions.start()
	local remote = Net.func(Net.ACTION)
	remote.OnServerInvoke = function(
		player: Player,
		name: unknown,
		arg: unknown
	): (boolean, string?)
		if typeof(name) ~= "string" then
			return false, "Bad request"
		end
		local handler = handlers[name]
		if not handler then
			return false, "Unknown action"
		end
		if not allow(player) then
			return false, "Slow down!"
		end
		local ok, success, message = pcall(handler, player, arg)
		if not ok then
			warn(`[Actions] {name} failed for {player.Name}: {success}`)
			return false, "Something went wrong"
		end
		return success, message
	end

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Actions
