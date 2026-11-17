--!strict
-- Eggs, hatching and pets. Eggs cost in-game coins (not Robux). Odds come from
-- Config and are shown to players in the Pets menu.
--
-- Equipped pets boost coins. Their kinds are written to the player's
-- "EquippedPets" attribute so every client can draw pets following them.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Types = require(ReplicatedStorage.Shared.Types)
local Actions = require(script.Parent.Actions)
local DataService = require(script.Parent.DataService)

local PetService = {}

local rng = Random.new()

local function boostOf(pet: Types.Pet): number
	local def = Config.PETS[pet.kind]
	return if def then def.boost else 0
end

local function findPet(profile: Types.Profile, id: string): (Types.Pet?, number?)
	for index, pet in profile.pets do
		if pet.id == id then
			return pet, index
		end
	end
	return nil, nil
end

local function hatch(player: Player, eggName: unknown): (boolean, string?)
	if typeof(eggName) ~= "string" then
		return false, "Bad egg"
	end
	local egg = Config.EGGS[eggName]
	if not egg then
		return false, "Bad egg"
	end
	local session = DataService.getSession(player)
	if not session then
		return false, "Still loading..."
	end
	local profile = session.profile
	if #profile.pets >= Config.MAX_PETS then
		return false, "Your pet inventory is full! Delete some pets first."
	end
	if profile.coins < egg.price then
		return false, `You need {Formulas.formatNumber(egg.price)} coins`
	end

	profile.coins -= egg.price
	local kind = Formulas.pickWeighted(egg.weights, rng:NextNumber())
	local pet: Types.Pet = { id = HttpService:GenerateGUID(false), kind = kind }
	table.insert(profile.pets, pet)
	if #profile.equipped < Formulas.equipSlots(session.passes) then
		table.insert(profile.equipped, pet.id)
	end
	DataService.markDirty(player)

	local def = Config.PETS[kind]
	DataService.notify(
		player,
		`You hatched a {def.rarity} {def.displayName}!`,
		Config.RARITY_COLORS[def.rarity]
	)
	return true, nil
end

local function togglePet(player: Player, id: unknown): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "Bad pet"
	end
	local session = DataService.getSession(player)
	if not session then
		return false, "Still loading..."
	end
	local profile = session.profile
	if not findPet(profile, id) then
		return false, "Bad pet"
	end
	local index = table.find(profile.equipped, id)
	if index then
		table.remove(profile.equipped, index)
	elseif #profile.equipped < Formulas.equipSlots(session.passes) then
		table.insert(profile.equipped, id)
	else
		return false, "All pet slots are full"
	end
	DataService.markDirty(player)
	return true, nil
end

local function equipBest(player: Player): (boolean, string?)
	local session = DataService.getSession(player)
	if not session then
		return false, "Still loading..."
	end
	local profile = session.profile
	local sorted = table.clone(profile.pets)
	table.sort(sorted, function(a, b)
		return boostOf(a) > boostOf(b)
	end)
	local equipped = {}
	for i = 1, math.min(#sorted, Formulas.equipSlots(session.passes)) do
		table.insert(equipped, sorted[i].id)
	end
	profile.equipped = equipped
	DataService.markDirty(player)
	return true, nil
end

local function deletePet(player: Player, id: unknown): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "Bad pet"
	end
	local session = DataService.getSession(player)
	if not session then
		return false, "Still loading..."
	end
	local profile = session.profile
	local _, index = findPet(profile, id)
	if not index then
		return false, "Bad pet"
	end
	table.remove(profile.pets, index)
	local equippedIndex = table.find(profile.equipped, id)
	if equippedIndex then
		table.remove(profile.equipped, equippedIndex)
	end
	DataService.markDirty(player)
	return true, nil
end

local function syncEquippedAttribute(player: Player, session: DataService.Session)
	local kinds = {}
	for _, id in session.profile.equipped do
		local pet = findPet(session.profile, id)
		if pet then
			table.insert(kinds, pet.kind)
		end
	end
	local value = table.concat(kinds, ",")
	if player:GetAttribute("EquippedPets") ~= value then
		player:SetAttribute("EquippedPets", value)
	end
end

local function buildEggStand(eggName: string, egg: Config.EggDef)
	local part = Instance.new("Part")
	part.Name = `{eggName}Egg`
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(5, 5, 5)
	part.Color = egg.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.Position = egg.position

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = `{egg.displayName}\n{Formulas.formatNumber(egg.price)} coins`
	label.Parent = billboard
	billboard.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.displayName
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		local ok, message = hatch(player, eggName)
		if not ok and message then
			DataService.notify(player, message)
		end
	end)

	part.Parent = workspace
end

function PetService.init()
	Actions.register("HatchEgg", hatch)
	Actions.register("TogglePet", togglePet)
	Actions.register("EquipBest", function(player)
		return equipBest(player)
	end)
	Actions.register("DeletePet", deletePet)
	DataService.onChanged(syncEquippedAttribute)
end

function PetService.start()
	for eggName, egg in Config.EGGS do
		buildEggStand(eggName, egg)
	end
end

return PetService
