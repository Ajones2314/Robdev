--!strict
-- Spawns coins around the map and pays players who touch them. The server
-- decides the coin's value, so a client can't pick its own payout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DataService = require(script.Parent.DataService)

local MAGNET_TICK = 0.25
local COIN_COLOR = Color3.fromRGB(255, 200, 40)

local CoinService = {}

local rng = Random.new()
local coins: { [BasePart]: boolean } = {}
local coinCount = 0
local folder: Folder

local function randomPoint(): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	-- sqrt keeps coins evenly spread instead of bunched in the middle
	local distance = math.sqrt(rng:NextNumber()) * Config.COINS.SPAWN_RADIUS
	return Config.COINS.SPAWN_CENTER
		+ Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function collect(player: Player, coin: BasePart)
	if not coins[coin] then
		return -- already collected this frame by someone else
	end
	local session = DataService.getSession(player)
	if not session then
		return
	end
	coins[coin] = nil
	coinCount -= 1
	coin:Destroy()
	DataService.addCoins(player, Formulas.coinValue(session.profile, session.passes))
end

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return player
end

local function spawnCoin()
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.5, 2.6, 2.6)
	coin.Color = COIN_COLOR
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CFrame = CFrame.new(randomPoint()) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	coin:AddTag("Coin") -- the client spins anything tagged "Coin"

	coin.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			collect(player, coin)
		end
	end)

	coins[coin] = true
	coinCount += 1
	coin.Parent = folder
end

local function magnetTick()
	for _, player in Players:GetPlayers() do
		local session = DataService.getSession(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if session and session.passes.Magnet and root and root:IsA("BasePart") then
			local position = root.Position
			for coin in coins do
				if (coin.Position - position).Magnitude <= Config.COINS.MAGNET_RADIUS then
					collect(player, coin)
				end
			end
		end
	end
end

function CoinService.init()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Coins"
	newFolder.Parent = workspace
	folder = newFolder
end

function CoinService.start()
	task.spawn(function()
		while true do
			task.wait(Config.COINS.SPAWN_INTERVAL)
			if coinCount < Config.COINS.MAX_COINS then
				spawnCoin()
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MAGNET_TICK)
			magnetTick()
		end
	end)
end

return CoinService
