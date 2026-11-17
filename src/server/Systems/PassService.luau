--!strict
-- Robux purchases: game passes (bought once) and developer products (coin
-- packs, bought any number of times).
--
-- Developer product rule: a purchase is only "granted" once it is saved, and
-- each receipt is recorded so a retry can never pay out twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DataService = require(script.Parent.DataService)

local PassService = {}

local function passNameFromId(id: number): string?
	for name, def in Config.GAME_PASSES do
		if def.id ~= 0 and def.id == id then
			return name
		end
	end
	return nil
end

local function productFromId(id: number): Config.ProductDef?
	for _, def in Config.DEV_PRODUCTS do
		if def.id ~= 0 and def.id == id then
			return def
		end
	end
	return nil
end

local function loadPasses(player: Player, session: DataService.Session)
	for name, def in Config.GAME_PASSES do
		if def.id ~= 0 then
			local ok, owns = pcall(
				MarketplaceService.UserOwnsGamePassAsync,
				MarketplaceService,
				player.UserId,
				def.id
			)
			if ok and owns then
				session.passes[name] = true
			elseif not ok then
				warn(`[PassService] Could not check pass {name}: {owns}`)
			end
		end
	end
	DataService.markDirty(player)
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local session = player and DataService.getSession(player)
	if not player or not session then
		-- Not in this server or data not loaded yet: Roblox retries later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if DataService.hasPurchase(session, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = productFromId(receiptInfo.ProductId)
	if not product then
		warn(`[PassService] Unknown developer product {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local amount =
		math.floor(product.baseCoins * Formulas.coinMultiplier(session.profile, session.passes))
	DataService.addCoins(player, amount)
	DataService.recordPurchase(session, purchaseId)

	if not DataService.saveNow(player) then
		-- The grant is recorded in memory, so a retry won't pay twice; the next
		-- autosave will persist it.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.notify(
		player,
		`Thanks! +{Formulas.formatNumber(amount)} coins`,
		Color3.fromRGB(255, 210, 60)
	)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PassService.init()
	DataService.onLoaded(loadPasses)
end

function PassService.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local name = passNameFromId(passId)
		local session = DataService.getSession(player)
		if name and session then
			session.passes[name] = true
			DataService.markDirty(player)
			DataService.notify(
				player,
				`Thanks for buying {Config.GAME_PASSES[name].displayName}!`,
				Color3.fromRGB(255, 210, 60)
			)
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return PassService
