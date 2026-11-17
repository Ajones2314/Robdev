--!strict
-- All on-screen UI, built in code so it lives in the repo with everything else.
-- Sizes use Scale (percent of screen) so it fits phones and PCs.
--
--   * Top-left stats: coins, multiplier, rebirths
--   * Left menu: Upgrades, Pets, Shop, Daily
--   * Center panel: whichever menu is open (redrawn when data changes)
--   * Toasts: short messages at the top of the screen

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Types = require(Shared:WaitForChild("Types"))
local StateController = require(script.Parent:WaitForChild("StateController"))

type Snapshot = Types.Snapshot
type PanelName = "Upgrades" | "Pets" | "Shop"

local player = Players.LocalPlayer

local COLORS = {
	panel = Color3.fromRGB(30, 34, 48),
	row = Color3.fromRGB(44, 50, 70),
	text = Color3.fromRGB(245, 245, 250),
	muted = Color3.fromRGB(170, 175, 195),
	green = Color3.fromRGB(70, 200, 110),
	blue = Color3.fromRGB(70, 140, 255),
	gold = Color3.fromRGB(255, 190, 40),
	red = Color3.fromRGB(230, 80, 80),
	purple = Color3.fromRGB(160, 90, 255),
	gray = Color3.fromRGB(90, 95, 115),
}
local FONT = Enum.Font.FredokaOne
local POP = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HudController = {}

local gui: ScreenGui
local coinsLabel: TextLabel
local multiplierLabel: TextLabel
local rebirthLabel: TextLabel
local dailyButton: TextButton
local panel: Frame
local panelTitle: TextLabel
local panelList: ScrollingFrame
local toastList: Frame
local openPanel: PanelName? = nil

-- Small helper: Instance.new + set properties + parent children.
local function make(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className) :: any
	for key, value in props do
		instance[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

local function corner(radius: number): Instance
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function textSize(max: number): Instance
	return make("UITextSizeConstraint", { MaxTextSize = max })
end

local function label(text: string, props: { [string]: any }?): TextLabel
	local result = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		Text = text,
		TextColor3 = COLORS.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { textSize(24) })
	if props then
		for key, value in props do
			(result :: any)[key] = value
		end
	end
	return result
end

local function button(text: string, color: Color3, onClick: () -> ()): TextButton
	local result: TextButton = make("TextButton", {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Font = FONT,
		Text = text,
		TextColor3 = COLORS.text,
		TextScaled = true,
	}, {
		corner(10),
		textSize(22),
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	local scale = make("UIScale", { Parent = result })
	result.Activated:Connect(function()
		-- a little "pop" makes every click feel good
		local down = TweenService:Create(scale, POP, { Scale = 0.9 })
		down.Completed:Once(function()
			TweenService:Create(scale, POP, { Scale = 1 }):Play()
		end)
		down:Play()
		onClick()
	end)
	return result
end

function HudController.toast(text: string, color: Color3?)
	local toast: TextLabel = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.15,
		Font = FONT,
		Text = text,
		TextColor3 = color or COLORS.text,
		TextScaled = true,
		TextTransparency = 1,
	}, {
		corner(10),
		textSize(24),
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	})
	toast.Parent = toastList
	TweenService:Create(toast, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	task.delay(2.5, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.4), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		fade.Completed:Once(function()
			toast:Destroy()
		end)
		fade:Play()
	end)
end

-- Sends an action and shows the server's message (errors in red).
local function act(action: string, arg: any?)
	task.spawn(function()
		local ok, message = StateController.request(action, arg)
		if message then
			HudController.toast(message, if ok then COLORS.green else COLORS.red)
		end
	end)
end

-- A row in the open panel: text on the left, buttons on the right.
local function row(text: string, textColor: Color3?, buttons: { TextButton }, height: number?)
	local rowHeight = height or 56
	local buttonWidth = 0.26
	local textWidth = 1 - buttonWidth * #buttons
	local frame = make("Frame", {
		Size = UDim2.new(1, -8, 0, rowHeight),
		BackgroundColor3 = COLORS.row,
		LayoutOrder = #panelList:GetChildren(),
	}, { corner(10) })
	label(text, {
		Size = UDim2.new(textWidth, -14, 1, -8),
		Position = UDim2.new(0, 10, 0, 4),
		TextColor3 = textColor or COLORS.text,
		TextWrapped = true,
		Parent = frame,
	})
	for i, btn in buttons do
		btn.Size = UDim2.new(buttonWidth, -8, 1, -14)
		btn.Position = UDim2.new(textWidth + buttonWidth * (i - 1), 2, 0, 7)
		btn.Parent = frame
	end
	frame.Parent = panelList
end

local function clearPanel()
	for _, child in panelList:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function renderUpgrades(state: Snapshot)
	for _, kind in Config.UPGRADE_ORDER do
		local def = Config.UPGRADES[kind]
		local level = state.upgrades[kind] or 0
		local text = `{def.displayName}  Lv {level}/{def.maxLevel}\n{def.description}`
		if level >= def.maxLevel then
			row(text, nil, { button("MAX", COLORS.gray, function() end) })
		else
			local cost = Formulas.upgradeCost(kind, level)
			local color = if state.coins >= cost then COLORS.green else COLORS.gray
			row(text, nil, {
				button(`{Formulas.formatNumber(cost)} 🪙`, color, function()
					act("BuyUpgrade", kind)
				end),
			})
		end
	end

	local cost = Formulas.rebirthCost(state.rebirths)
	local nextBonus = math.floor((state.rebirths + 1) * Config.REBIRTH.BONUS * 100)
	row(`Rebirth: reset coins and upgrades,\nearn +{nextBonus}% coins forever`, COLORS.gold, {
		button(
			`{Formulas.formatNumber(cost)} 🪙`,
			if state.coins >= cost then COLORS.purple else COLORS.gray,
			function()
				act("Rebirth")
			end
		),
	}, 64)
end

local function renderPets(state: Snapshot)
	row(
		`Pets {#state.pets}/{Config.MAX_PETS}   Equipped {#state.equipped}/{state.equipSlots}`,
		nil,
		{ button("Equip Best", COLORS.blue, function()
			act("EquipBest")
		end) }
	)

	for _, eggName in Config.EGG_ORDER do
		local egg = Config.EGGS[eggName]
		local odds = {}
		for _, kind in Config.RARITY_ORDER do
			for petKind, petDef in Config.PETS do
				if petDef.rarity == kind and egg.weights[petKind] then
					local percent = Formulas.oddsPercent(egg.weights, petKind)
					table.insert(odds, `{petDef.displayName} {string.format("%g", percent)}%`)
				end
			end
		end
		row(`{egg.displayName}: {table.concat(odds, ", ")}`, COLORS.muted, {
			button(
				`{Formulas.formatNumber(egg.price)} 🪙`,
				if state.coins >= egg.price then COLORS.green else COLORS.gray,
				function()
					act("HatchEgg", eggName)
				end
			),
		}, 64)
	end

	local pets = table.clone(state.pets)
	table.sort(pets, function(a, b)
		local boostA = if Config.PETS[a.kind] then Config.PETS[a.kind].boost else 0
		local boostB = if Config.PETS[b.kind] then Config.PETS[b.kind].boost else 0
		return boostA > boostB
	end)
	for _, pet in pets do
		local def = Config.PETS[pet.kind]
		if def then
			local equipped = table.find(state.equipped, pet.id) ~= nil
			row(
				`{def.displayName} ({def.rarity})  +{math.floor(def.boost * 100)}%`,
				Config.RARITY_COLORS[def.rarity],
				{
					button(
						if equipped then "Unequip" else "Equip",
						if equipped then COLORS.gray else COLORS.blue,
						function()
							act("TogglePet", pet.id)
						end
					),
					button("Delete", COLORS.red, function()
						act("DeletePet", pet.id)
					end),
				}
			)
		end
	end
end

local function renderShop(state: Snapshot)
	for _, name in Config.PASS_ORDER do
		local def = Config.GAME_PASSES[name]
		local text = `{def.displayName}\n{def.description}`
		if state.passes[name] then
			row(text, COLORS.gold, { button("Owned", COLORS.gray, function() end) })
		elseif def.id == 0 then
			row(text, COLORS.muted, {
				button("Soon", COLORS.gray, function()
					HudController.toast(
						"This pass isn't set up yet (add its ID in Config)",
						COLORS.muted
					)
				end),
			})
		else
			row(text, COLORS.gold, {
				button("Buy", COLORS.green, function()
					MarketplaceService:PromptGamePassPurchase(player, def.id)
				end),
			})
		end
	end

	for _, name in Config.PRODUCT_ORDER do
		local def = Config.DEV_PRODUCTS[name]
		local amount = math.floor(def.baseCoins * state.multiplier)
		local text = `{def.displayName}\n+{Formulas.formatNumber(amount)} coins`
		if def.id == 0 then
			row(text, COLORS.muted, {
				button("Soon", COLORS.gray, function()
					HudController.toast(
						"This product isn't set up yet (add its ID in Config)",
						COLORS.muted
					)
				end),
			})
		else
			row(text, nil, {
				button("Buy", COLORS.green, function()
					MarketplaceService:PromptProductPurchase(player, def.id)
				end),
			})
		end
	end
end

local function renderPanel()
	local state = StateController.get()
	clearPanel()
	if not openPanel or not state then
		return
	end
	if openPanel == "Upgrades" then
		renderUpgrades(state)
	elseif openPanel == "Pets" then
		renderPets(state)
	elseif openPanel == "Shop" then
		renderShop(state)
	end
end

local function setPanel(name: PanelName?)
	if openPanel == name then
		name = nil -- clicking the same menu again closes it
	end
	openPanel = name
	panel.Visible = name ~= nil
	panelTitle.Text = name or ""
	panelList.CanvasPosition = Vector2.zero
	renderPanel()
end

local function formatTime(seconds: number): string
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	return string.format("%d:%02d:%02d", h, m, s)
end

local function build()
	gui = make("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Stats (top-left)
	local stats = make("Frame", {
		Position = UDim2.fromScale(0.015, 0.03),
		Size = UDim2.fromScale(0.24, 0.16),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make(
			"UIListLayout",
			{ Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		make(
			"UISizeConstraint",
			{ MinSize = Vector2.new(170, 80), MaxSize = Vector2.new(320, 140) }
		),
	})
	coinsLabel = label("🪙 0", {
		Size = UDim2.fromScale(1, 0.45),
		LayoutOrder = 1,
		TextColor3 = COLORS.gold,
		Parent = stats,
	})
	coinsLabel.TextStrokeTransparency = 0.4
	multiplierLabel =
		label("x1 coins", { Size = UDim2.fromScale(1, 0.25), LayoutOrder = 2, Parent = stats })
	multiplierLabel.TextStrokeTransparency = 0.5
	rebirthLabel =
		label("Rebirths: 0", { Size = UDim2.fromScale(1, 0.25), LayoutOrder = 3, Parent = stats })
	rebirthLabel.TextStrokeTransparency = 0.5

	-- Menu buttons (left side)
	local menu = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.015, 0.5),
		Size = UDim2.fromScale(0.11, 0.36),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make(
			"UIListLayout",
			{ Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		make(
			"UISizeConstraint",
			{ MinSize = Vector2.new(90, 160), MaxSize = Vector2.new(160, 280) }
		),
	})
	local menuItems: { { name: PanelName, color: Color3 } } = {
		{ name = "Upgrades", color = COLORS.green },
		{ name = "Pets", color = COLORS.blue },
		{ name = "Shop", color = COLORS.gold },
	}
	for i, item in menuItems do
		local btn = button(item.name, item.color, function()
			setPanel(item.name)
		end)
		btn.Size = UDim2.fromScale(1, 0.22)
		btn.LayoutOrder = i
		btn.Parent = menu
	end
	dailyButton = button("Daily", COLORS.purple, function()
		act("ClaimDaily")
	end)
	dailyButton.Size = UDim2.fromScale(1, 0.22)
	dailyButton.LayoutOrder = 4
	dailyButton.Parent = menu

	-- Center panel
	panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.5, 0.66),
		BackgroundColor3 = COLORS.panel,
		Visible = false,
		Parent = gui,
	}, {
		corner(16),
		make(
			"UISizeConstraint",
			{ MinSize = Vector2.new(300, 240), MaxSize = Vector2.new(620, 560) }
		),
	})
	panelTitle = label("", {
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(1, -80, 0, 40),
		Parent = panel,
	})
	local close = button("X", COLORS.red, function()
		setPanel(nil)
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(40, 40)
	close.Parent = panel
	panelList = make("ScrollingFrame", {
		Position = UDim2.new(0, 8, 0, 56),
		Size = UDim2.new(1, -16, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Toasts (top-center)
	toastList = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.03),
		Size = UDim2.fromScale(0.4, 0.3),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function onState(state: Snapshot)
	coinsLabel.Text = `🪙 {Formulas.formatNumber(state.coins)}`
	multiplierLabel.Text =
		`x{(string.format("%.2f", state.multiplier):gsub("%.?0+$", ""))} coins  ·  {Formulas.formatNumber(
			state.coinValue
		)} per coin`
	rebirthLabel.Text = `Rebirths: {state.rebirths}`
	renderPanel()
end

function HudController.start()
	build()
	StateController.onChanged(onState)
	StateController.onNotify(function(text, color)
		HudController.toast(text, color)
	end)

	-- Daily button countdown. The server sent "ready in N seconds" at the time
	-- of the last snapshot, so count down locally from there.
	local lastSnapshot: Snapshot? = nil
	local receivedAt = 0
	StateController.onChanged(function(state)
		lastSnapshot = state
		receivedAt = os.clock()
	end)
	while true do
		if lastSnapshot then
			local remaining = math.ceil(lastSnapshot.dailyReadyIn - (os.clock() - receivedAt))
			if remaining <= 0 then
				dailyButton.Text = "Daily 🎁"
				dailyButton.BackgroundColor3 = COLORS.purple
			else
				dailyButton.Text = formatTime(remaining)
				dailyButton.BackgroundColor3 = COLORS.gray
			end
		end
		task.wait(1)
	end
end

return HudController
