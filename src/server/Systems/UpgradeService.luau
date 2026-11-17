--!strict
-- Upgrades (spend coins for permanent boosts) and Rebirth (reset coins and
-- upgrades for a permanent coin multiplier). Also keeps walk speed in sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Actions = require(script.Parent.Actions)
local DataService = require(script.Parent.DataService)

local UpgradeService = {}

local function applyWalkSpeed(player: Player)
	local session = DataService.getSession(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if session and humanoid then
		humanoid.WalkSpeed = Formulas.walkSpeed(session.profile, session.passes)
	end
end

local function buyUpgrade(player: Player, arg: unknown): (boolean, string?)
	if typeof(arg) ~= "string" then
		return false, "Bad upgrade"
	end
	local def = Config.UPGRADES[arg]
	if not def then
		return false, "Bad upgrade"
	end
	local session = DataService.getSession(player)
	if not session then
		return false, "Still loading..."
	end
	local profile = session.profile
	local level = profile.upgrades[arg] or 0
	if level >= def.maxLevel then
		return false, "Already max level!"
	end
	local cost = Formulas.upgradeCost(arg, level)
	if profile.coins < cost then
		return false, "Not enough coins"
	end
	profile.coins -= cost
	profile.upgrades[arg] = level + 1
	DataService.markDirty(player)
	return true, `{def.displayName} is now level {level + 1}!`
end

local function rebirth(player: Player): (boolean, string?)
	local session = DataService.getSession(player)
	if not session then
		return false, "Still loading..."
	end
	local profile = session.profile
	local cost = Formulas.rebirthCost(profile.rebirths)
	if profile.coins < cost then
		return false, `You need {Formulas.formatNumber(cost)} coins to rebirth`
	end
	profile.coins = 0
	profile.upgrades = {}
	profile.rebirths += 1
	DataService.markDirty(player)
	local bonus = math.floor(profile.rebirths * Config.REBIRTH.BONUS * 100)
	return true, `Rebirth {profile.rebirths}! You now earn +{bonus}% coins forever.`
end

function UpgradeService.init()
	Actions.register("BuyUpgrade", buyUpgrade)
	Actions.register("Rebirth", function(player)
		return rebirth(player)
	end)
	DataService.onChanged(function(player)
		applyWalkSpeed(player)
	end)
end

function UpgradeService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			applyWalkSpeed(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return UpgradeService
