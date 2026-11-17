--!strict
-- Draws each player's equipped pets as glowing orbs that float behind them.
-- Purely visual and client-side: the server only publishes which pet kinds
-- are equipped (the "EquippedPets" attribute on each Player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local SPACING = 3.2
local BEHIND = 4.5
local FOLLOW_SPEED = 10

local PetFollowController = {}

local folder: Folder
local orbs: { [Player]: { Part } } = {}

local function makeOrb(kind: string): Part
	local def = Config.PETS[kind]
	local color = if def then Config.RARITY_COLORS[def.rarity] else Color3.new(1, 1, 1)
	local orb = Instance.new("Part")
	orb.Name = kind
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.6, 1.6, 1.6)
	orb.Color = color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(100, 24)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.MaxDistance = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = if def then def.displayName else kind
	label.Parent = billboard
	billboard.Parent = orb

	orb.Parent = folder
	return orb
end

local function rebuild(player: Player)
	local old = orbs[player]
	if old then
		for _, orb in old do
			orb:Destroy()
		end
	end
	local list = {}
	local value = player:GetAttribute("EquippedPets")
	if typeof(value) == "string" and value ~= "" then
		for _, kind in string.split(value, ",") do
			table.insert(list, makeOrb(kind))
		end
	end
	orbs[player] = list
end

local function watch(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
end

local function step(dt: number)
	local t = os.clock()
	local alpha = math.min(1, dt * FOLLOW_SPEED)
	for player, list in orbs do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local count = #list
			for i, orb in list do
				local side = (i - (count + 1) / 2) * SPACING
				local bob = math.sin(t * 3 + i) * 0.3
				local target = root.CFrame * CFrame.new(side, bob, BEHIND)
				orb.CFrame = orb.CFrame:Lerp(target, alpha)
			end
		end
	end
end

function PetFollowController.start()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "ClientPets"
	newFolder.Parent = workspace
	folder = newFolder

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local list = orbs[player]
		if list then
			for _, orb in list do
				orb:Destroy()
			end
		end
		orbs[player] = nil
	end)

	RunService.RenderStepped:Connect(step)
end

return PetFollowController
