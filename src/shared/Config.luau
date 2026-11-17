--!strict
-- All the numbers that tune the game live here. Change prices, pets, eggs and
-- rewards in this one file.
--
-- NOTE: this module is replicated to clients, so it must not hold secrets. The
-- server never trusts a value a client sends; it always reads from here.

export type UpgradeDef = {
	displayName: string,
	description: string,
	baseCost: number,
	growth: number, -- each level costs `growth` times the previous one
	maxLevel: number,
	perLevel: number,
}

export type PetDef = {
	displayName: string,
	rarity: string,
	boost: number, -- 0.25 = +25% coins while equipped
}

export type EggDef = {
	displayName: string,
	price: number,
	position: Vector3,
	color: Color3,
	weights: { [string]: number }, -- pet kind -> relative chance
}

export type PassDef = {
	id: number, -- paste the Game Pass ID from the Creator Dashboard (0 = not set up yet)
	displayName: string,
	description: string,
}

export type ProductDef = {
	id: number, -- paste the Developer Product ID from the Creator Dashboard (0 = not set up yet)
	displayName: string,
	baseCoins: number, -- multiplied by the buyer's coin multiplier
}

local Config = {}

-- Bump the name only if you want to wipe everyone's saves.
Config.DATASTORE_NAME = "PlayerData_v1"
Config.AUTOSAVE_INTERVAL = 60
Config.STARTING_COINS = 0

Config.COINS = {
	SPAWN_CENTER = Vector3.new(0, 1.5, 0), -- the default Baseplate's top is at Y = 0
	SPAWN_RADIUS = 90,
	MAX_COINS = 60,
	SPAWN_INTERVAL = 0.4,
	BASE_VALUE = 1,
	MAGNET_RADIUS = 25,
}

Config.BASE_WALK_SPEED = 16

Config.UPGRADE_ORDER = { "CoinValue", "WalkSpeed" }
Config.UPGRADES = {
	CoinValue = {
		displayName = "Coin Value",
		description = "+1 coin per pickup",
		baseCost = 25,
		growth = 1.55,
		maxLevel = 50,
		perLevel = 1,
	},
	WalkSpeed = {
		displayName = "Walk Speed",
		description = "+2 walk speed",
		baseCost = 50,
		growth = 1.9,
		maxLevel = 10,
		perLevel = 2,
	},
} :: { [string]: UpgradeDef }

Config.REBIRTH = {
	BASE_COST = 10000,
	GROWTH = 3,
	BONUS = 0.5, -- +50% coins per rebirth, forever
}

Config.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
Config.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
} :: { [string]: Color3 }

Config.PETS = {
	Cat = { displayName = "Cat", rarity = "Common", boost = 0.1 },
	Dog = { displayName = "Dog", rarity = "Common", boost = 0.15 },
	Bunny = { displayName = "Bunny", rarity = "Uncommon", boost = 0.3 },
	Fox = { displayName = "Fox", rarity = "Rare", boost = 0.6 },
	Unicorn = { displayName = "Unicorn", rarity = "Epic", boost = 1.2 },
	Dragon = { displayName = "Dragon", rarity = "Legendary", boost = 3 },
} :: { [string]: PetDef }

Config.EGG_ORDER = { "Basic", "Golden" }
Config.EGGS = {
	Basic = {
		displayName = "Basic Egg",
		price = 100,
		position = Vector3.new(-12, 3, 30),
		color = Color3.fromRGB(240, 235, 220),
		weights = { Cat = 50, Dog = 35, Bunny = 12, Fox = 3 },
	},
	Golden = {
		displayName = "Golden Egg",
		price = 2500,
		position = Vector3.new(12, 3, 30),
		color = Color3.fromRGB(255, 200, 50),
		weights = { Bunny = 45, Fox = 35, Unicorn = 17, Dragon = 3 },
	},
} :: { [string]: EggDef }

Config.MAX_PETS = 50
Config.EQUIP_SLOTS = 3

-- Game passes: one-time purchases. Create them in the Creator Dashboard
-- (your game > Monetization > Passes), then paste each ID here.
Config.PASS_ORDER = { "DoubleCoins", "VIP", "Magnet" }
Config.GAME_PASSES = {
	DoubleCoins = { id = 0, displayName = "2x Coins", description = "Double every coin, forever." },
	VIP = { id = 0, displayName = "VIP", description = "+25% coins, +4 speed, +1 pet slot." },
	Magnet = { id = 0, displayName = "Coin Magnet", description = "Grab coins from far away." },
} :: { [string]: PassDef }

Config.VIP = {
	COIN_MULTIPLIER = 1.25,
	EXTRA_SPEED = 4,
	EXTRA_PET_SLOTS = 1,
}

-- Developer products: can be bought again and again. Create them in the
-- Creator Dashboard (your game > Monetization > Developer Products).
Config.PRODUCT_ORDER = { "CoinsSmall", "CoinsLarge" }
Config.DEV_PRODUCTS = {
	CoinsSmall = { id = 0, displayName = "Coin Pouch", baseCoins = 500 },
	CoinsLarge = { id = 0, displayName = "Coin Chest", baseCoins = 6000 },
} :: { [string]: ProductDef }

Config.DAILY = {
	COOLDOWN = 20 * 60 * 60, -- 20 hours, so players who come back "tomorrow" always can claim
	BASE_REWARD = 250, -- multiplied by (1 + rebirths)
}

return Config
