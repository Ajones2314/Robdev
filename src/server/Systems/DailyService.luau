--!strict
-- Daily reward: a reason to come back tomorrow (Day 1 retention).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Actions = require(script.Parent.Actions)
local DataService = require(script.Parent.DataService)

local DailyService = {}

local function claim(player: Player): (boolean, string?)
	local session = DataService.getSession(player)
	if not session then
		return false, "Still loading..."
	end
	local profile = session.profile
	local now = os.time()
	if now - profile.lastDaily < Config.DAILY.COOLDOWN then
		return false, "Come back later for your next reward!"
	end
	local amount = Config.DAILY.BASE_REWARD * (1 + profile.rebirths)
	profile.lastDaily = now
	DataService.addCoins(player, amount)
	return true, `Daily reward: +{Formulas.formatNumber(amount)} coins!`
end

function DailyService.init()
	Actions.register("ClaimDaily", function(player)
		return claim(player)
	end)
	DataService.onLoaded(function(player, session)
		if os.time() - session.profile.lastDaily >= Config.DAILY.COOLDOWN then
			task.wait(3)
			DataService.notify(player, "Your daily reward is ready! Tap Daily to claim it.")
		end
	end)
end

return DailyService
