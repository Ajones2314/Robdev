--!strict
-- Spins every coin on this client only (visual juice, no network cost).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPIN_SPEED = math.rad(120) -- degrees per second

local CoinSpinController = {}

local coins: { [BasePart]: boolean } = {}

local function add(instance: Instance)
	if instance:IsA("BasePart") then
		coins[instance] = true
	end
end

function CoinSpinController.start()
	for _, instance in CollectionService:GetTagged("Coin") do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal("Coin"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(instance)
		coins[instance :: BasePart] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local rotation = CFrame.Angles(0, SPIN_SPEED * dt, 0)
		for coin in coins do
			coin.CFrame = coin.CFrame * rotation
		end
	end)
end

return CoinSpinController
