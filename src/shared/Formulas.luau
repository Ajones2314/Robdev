--!strict
-- Pure math shared by server and client. No side effects, so it is easy to test
-- and the UI always shows the same numbers the server uses.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Formulas = {}

function Formulas.upgradeCost(kind: string, level: number): number
	local def = Config.UPGRADES[kind]
	return math.floor(def.baseCost * def.growth ^ level)
end

function Formulas.rebirthCost(rebirths: number): number
	return math.floor(Config.REBIRTH.BASE_COST * Config.REBIRTH.GROWTH ^ rebirths)
end

function Formulas.petBoost(pets: { Types.Pet }, equipped: { string }): number
	local total = 0
	for _, pet in pets do
		if table.find(equipped, pet.id) then
			local def = Config.PETS[pet.kind]
			if def then
				total += def.boost
			end
		end
	end
	return total
end

function Formulas.coinMultiplier(profile: Types.Profile, passes: { [string]: boolean }): number
	local multiplier = (1 + profile.rebirths * Config.REBIRTH.BONUS)
		* (1 + Formulas.petBoost(profile.pets, profile.equipped))
	if passes.DoubleCoins then
		multiplier *= 2
	end
	if passes.VIP then
		multiplier *= Config.VIP.COIN_MULTIPLIER
	end
	return multiplier
end

function Formulas.coinValue(profile: Types.Profile, passes: { [string]: boolean }): number
	local level = profile.upgrades.CoinValue or 0
	local base = Config.COINS.BASE_VALUE + level * Config.UPGRADES.CoinValue.perLevel
	return math.max(1, math.floor(base * Formulas.coinMultiplier(profile, passes) + 0.5))
end

function Formulas.walkSpeed(profile: Types.Profile, passes: { [string]: boolean }): number
	local level = profile.upgrades.WalkSpeed or 0
	local speed = Config.BASE_WALK_SPEED + level * Config.UPGRADES.WalkSpeed.perLevel
	if passes.VIP then
		speed += Config.VIP.EXTRA_SPEED
	end
	return speed
end

function Formulas.equipSlots(passes: { [string]: boolean }): number
	return Config.EQUIP_SLOTS + if passes.VIP then Config.VIP.EXTRA_PET_SLOTS else 0
end

-- Picks a key from a weight table. `roll` must be in [0, 1).
-- Keys are sorted first so the same roll always gives the same result.
function Formulas.pickWeighted(weights: { [string]: number }, roll: number): string
	local keys = {}
	local total = 0
	for key, weight in weights do
		table.insert(keys, key)
		total += weight
	end
	table.sort(keys)
	local target = roll * total
	for _, key in keys do
		target -= weights[key]
		if target < 0 then
			return key
		end
	end
	return keys[#keys]
end

-- Chance of `kind` from a weight table, as a percentage (shown to players,
-- because random paid rewards must disclose their odds).
function Formulas.oddsPercent(weights: { [string]: number }, kind: string): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	if total == 0 then
		return 0
	end
	return (weights[kind] or 0) / total * 100
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 5600000 -> "5.6M"
function Formulas.formatNumber(n: number): string
	local value = math.floor(n)
	local index = 1
	local scaled = value
	while math.abs(scaled) >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	if index == 1 then
		return tostring(value)
	end
	local text = string.format("%.2f", scaled):gsub("%.?0+$", "")
	return text .. SUFFIXES[index]
end

return Formulas
