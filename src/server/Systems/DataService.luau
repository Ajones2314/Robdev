--!strict
-- Loads, holds and saves every player's Profile.
--
-- Safety features (losing progress is the #1 reason players quit for good):
--   * Retries with backoff on every DataStore call.
--   * Session lock: a profile is "owned" by one server at a time, so a player
--     hopping servers quickly can't load stale data and duplicate items.
--   * Autosave every Config.AUTOSAVE_INTERVAL seconds, save on leave, and save
--     everyone on shutdown (BindToClose).
--   * Missing fields are filled from defaults, so adding new fields later is safe.
--
-- Other systems change data through `getSession(player).profile` and then call
-- `markDirty(player)`; changes are pushed to the client a few times a second.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Actions = require(script.Parent.Actions)

export type Session = {
	profile: Types.Profile,
	passes: { [string]: boolean },
	canSave: boolean,
}

local PROFILE_VERSION = 1
local LOCK_EXPIRY = 30 * 60 -- a lock older than this belongs to a crashed server
local LOCK_RETRIES = 6
local MAX_PURCHASE_IDS = 100
local FLUSH_INTERVAL = 0.15

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

local DataService = {}

local sessions: { [Player]: Session } = {}
local dirty: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, Session) -> () } = {}
local changedCallbacks: { (Player, Session) -> () } = {}
local pendingSaves = 0

local stateRemote: RemoteEvent
local notifyRemote: RemoteEvent

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function defaultProfile(): Types.Profile
	return {
		version = PROFILE_VERSION,
		coins = Config.STARTING_COINS,
		totalCoins = 0,
		rebirths = 0,
		upgrades = {},
		pets = {},
		equipped = {},
		lastDaily = 0,
		purchaseIds = {},
	}
end

-- Copies saved fields onto a fresh default profile, keeping only fields whose
-- type matches. Old saves missing new fields get the defaults.
local function reconcile(data: unknown): Types.Profile
	local profile = defaultProfile()
	if typeof(data) == "table" then
		local saved = data :: { [string]: any }
		local target = profile :: any
		for key, defaultValue in target do
			local value = saved[key]
			if value ~= nil and typeof(value) == typeof(defaultValue) then
				target[key] = value
			end
		end
	end
	profile.version = PROFILE_VERSION
	return profile
end

local function retry(label: string, attempts: number, fn: () -> ()): boolean
	for attempt = 1, attempts do
		local ok, err: any = pcall(fn)
		if ok then
			return true
		end
		warn(`[DataService] {label} failed (attempt {attempt}/{attempts}): {err}`)
		if attempt < attempts then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

local function isLockedByOtherServer(record: unknown, now: number): boolean
	if typeof(record) ~= "table" then
		return false
	end
	local lock = (record :: any).lock
	if typeof(lock) ~= "table" then
		return false
	end
	return lock.jobId ~= game.JobId and now - (tonumber(lock.time) or 0) < LOCK_EXPIRY
end

local function loadProfile(player: Player): Types.Profile?
	local key = keyFor(player)
	for attempt = 1, LOCK_RETRIES do
		local lockedOut = false
		local result: Types.Profile? = nil
		local ok = retry("Load", 3, function()
			store:UpdateAsync(key, function(old: unknown): any
				local now = os.time()
				-- On the last attempt, take the lock anyway: the other server
				-- most likely crashed without releasing it.
				if attempt < LOCK_RETRIES and isLockedByOtherServer(old, now) then
					lockedOut = true
					return nil
				end
				lockedOut = false
				local profile = reconcile(if typeof(old) == "table" then (old :: any).data else nil)
				result = profile
				return { data = profile, lock = { jobId = game.JobId, time = now } }
			end)
		end)
		if not ok then
			return nil
		end
		if not lockedOut then
			return result
		end
		task.wait(5)
	end
	return nil
end

-- Saves a session. `release` gives up the lock (used when the player leaves).
local function saveSession(player: Player, session: Session, release: boolean): boolean
	if not session.canSave then
		return true
	end
	pendingSaves += 1
	local lostLock = false
	local ok = retry("Save", 3, function()
		store:UpdateAsync(keyFor(player), function(old: unknown): any
			if isLockedByOtherServer(old, 0) then
				-- Another server now owns this profile. Never overwrite it.
				lostLock = true
				return nil
			end
			lostLock = false
			return {
				data = session.profile,
				lock = if release then nil else { jobId = game.JobId, time = os.time() },
			}
		end)
	end)
	pendingSaves -= 1
	if lostLock then
		session.canSave = false
		if player.Parent then
			player:Kick("Your data was opened in another server. Please rejoin.")
		end
		return false
	end
	return ok
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, profile: Types.Profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local coins = leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("NumberValue") then
		coins.Value = profile.coins
	end
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = profile.rebirths
	end
end

local function onPlayerAdded(player: Player)
	local profile = loadProfile(player)
	local canSave = true
	if not profile then
		if RunService:IsStudio() then
			warn(
				"[DataService] Using temporary data that will NOT save. To save in Studio, turn on "
					.. "Game Settings > Security > Enable Studio Access to API Services."
			)
			profile = defaultProfile()
			canSave = false
		else
			player:Kick("We couldn't load your data. Please rejoin in a minute.")
			return
		end
	end
	assert(profile, "profile is set above")

	local session: Session = { profile = profile, passes = {}, canSave = canSave }
	if not player.Parent then
		-- Left while loading: release the lock we just took.
		saveSession(player, session, true)
		return
	end

	sessions[player] = session
	createLeaderstats(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, session)
	end
	DataService.markDirty(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	saveSession(player, session, true)
	sessions[player] = nil
	dirty[player] = nil
end

function DataService.getSession(player: Player): Session?
	return sessions[player]
end

-- Runs `callback` once a player's data is loaded.
function DataService.onLoaded(callback: (Player, Session) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Runs `callback` whenever a player's data has changed (batched).
function DataService.onChanged(callback: (Player, Session) -> ())
	table.insert(changedCallbacks, callback)
end

function DataService.markDirty(player: Player)
	if sessions[player] then
		dirty[player] = true
	end
end

function DataService.addCoins(player: Player, amount: number)
	local session = sessions[player]
	if not session or amount <= 0 then
		return
	end
	session.profile.coins += amount
	session.profile.totalCoins += amount
	DataService.markDirty(player)
end

-- Records a purchase id. Returns false if it was already recorded.
function DataService.recordPurchase(session: Session, purchaseId: string): boolean
	local ids = session.profile.purchaseIds
	if table.find(ids, purchaseId) then
		return false
	end
	table.insert(ids, purchaseId)
	while #ids > MAX_PURCHASE_IDS do
		table.remove(ids, 1)
	end
	return true
end

function DataService.hasPurchase(session: Session, purchaseId: string): boolean
	return table.find(session.profile.purchaseIds, purchaseId) ~= nil
end

-- Saves right now (used after a Robux purchase). Returns true on success.
function DataService.saveNow(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	return saveSession(player, session, false)
end

function DataService.notify(player: Player, text: string, color: Color3?)
	notifyRemote:FireClient(player, text, color)
end

function DataService.snapshot(session: Session): Types.Snapshot
	local profile = session.profile
	return {
		coins = profile.coins,
		rebirths = profile.rebirths,
		upgrades = profile.upgrades,
		pets = profile.pets,
		equipped = profile.equipped,
		multiplier = Formulas.coinMultiplier(profile, session.passes),
		coinValue = Formulas.coinValue(profile, session.passes),
		passes = session.passes,
		dailyReadyIn = math.max(0, profile.lastDaily + Config.DAILY.COOLDOWN - os.time()),
		equipSlots = Formulas.equipSlots(session.passes),
	}
end

local function flush()
	for player in dirty do
		dirty[player] = nil
		local session = sessions[player]
		if session and player.Parent then
			updateLeaderstats(player, session.profile)
			for _, callback in changedCallbacks do
				task.spawn(callback, player, session)
			end
			stateRemote:FireClient(player, DataService.snapshot(session))
		end
	end
end

function DataService.init()
	stateRemote = Net.event(Net.STATE)
	notifyRemote = Net.event(Net.NOTIFY)

	-- The client asks for a fresh snapshot when its UI is ready, in case the
	-- first one was sent before it was listening.
	Actions.register("Sync", function(player)
		DataService.markDirty(player)
		return true, nil
	end)
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for player, session in sessions do
			task.spawn(saveSession, player, session, true)
		end
		local deadline = os.clock() + 25
		task.wait() -- let the saves above start
		while pendingSaves > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player, session in sessions do
				task.spawn(saveSession, player, session, false)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			flush()
		end
	end)
end

return DataService
