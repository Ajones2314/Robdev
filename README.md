# Robdev: Coin Simulator

A starter Roblox simulator game. Players run around collecting coins, buy upgrades, hatch pets from eggs, and rebirth for permanent multipliers. Robux purchases are built in: game passes and coin packs.

All the code lives in this repo and syncs into Roblox Studio with [Rojo](https://rojo.space).

## Load it into Roblox Studio

You do this once per computer.

1. **Install Rojo.**
   - In Roblox Studio, open the **Toolbox**, search the Plugins tab for **"Rojo"**, and install the plugin by **rojo-rbx**.
   - Install the Rojo command-line tool on your computer. The easiest way is [Rokit](https://github.com/rojo-rbx/rokit): install it, then run `rokit install` in this folder. Rokit reads `rokit.toml` and installs the right versions of Rojo, Selene and StyLua.
   - Alternative without Rokit: download `rojo` from the [Rojo releases page](https://github.com/rojo-rbx/rojo/releases).
2. **Get the code.** Clone this repo, for example with `git clone https://github.com/Ajones2314/Robdev.git`, or use GitHub Desktop.
3. **Open a new place.** In Studio, create a new **Baseplate** place.
4. **Start syncing.** In a terminal inside the repo folder, run:
   ```
   rojo serve
   ```
5. **Connect Studio.** In Studio, open the **Plugins** tab, click **Rojo**, and click **Connect**. The scripts appear in ServerScriptService, ReplicatedStorage and StarterPlayerScripts.
6. **Play.** Press **Play** (F5). Coins spawn around the spawn point, and the two eggs are just in front of it.

While `rojo serve` is running, every code change you save shows up in Studio right away.

### Make saving work in Studio

Studio can't save player data until you allow it:

1. Publish the place with **File > Publish to Roblox**.
2. Open **Game Settings > Security** and turn on **Enable Studio Access to API Services**.

Until you do this, the game still runs, but progress resets every time you play. The Output window warns you about it.

## Set up Robux purchases

The shop shows "Soon" until you add your real IDs.

1. Publish the game.
2. Go to the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open your game, and then open **Monetization**.
3. Create **Passes** named 2x Coins, VIP and Coin Magnet. Give each one an icon and turn on **Item for Sale** with a price. Starting prices that work well are 199, 249 and 149 Robux.
4. Create **Developer Products** named Coin Pouch and Coin Chest. Starting prices: 25 and 199 Robux.
5. Copy each ID into `src/shared/Config.luau` under `GAME_PASSES` and `DEV_PRODUCTS`, replacing the `0`.

## What's in the game

| Feature | Where |
|---|---|
| Coins spawn and get collected; the Coin Magnet pass pulls them in | `src/server/Systems/CoinService.luau` |
| Upgrades (Coin Value, Walk Speed) and Rebirth | `src/server/Systems/UpgradeService.luau` |
| Eggs, hatching, equipping and deleting pets | `src/server/Systems/PetService.luau` |
| Game passes and coin packs (Robux) | `src/server/Systems/PassService.luau` |
| Daily reward | `src/server/Systems/DailyService.luau` |
| Saving: retries, session lock and autosave | `src/server/Systems/DataService.luau` |
| Handling client requests, with rate limiting | `src/server/Systems/Actions.luau` |
| HUD, menus and pop-up messages | `src/client/Controllers/HudController.luau` |
| Pets following players, spinning coins | `src/client/Controllers/` |
| All prices, odds, pets and rewards | `src/shared/Config.luau` |

**Tuning the game:** almost everything is a number in `src/shared/Config.luau`. That includes coin value, upgrade costs, egg prices and odds, pet boosts, the rebirth cost and the daily reward amount.

**Safety rules the code follows:**
- The server decides all coins, purchases and hatches. The client only asks.
- Every request is checked and rate-limited.
- Robux purchases are recorded, so a retry can never pay out twice.
- Egg odds are shown in the Pets menu.

## Project layout

- `src/shared` → ReplicatedStorage/Shared: config, types and shared math
- `src/server` → ServerScriptService/Server: everything authoritative
- `src/client` → StarterPlayerScripts/Client: UI and visuals

## Checks

- Format: `stylua src`
- Lint: `selene src`

CI runs both on every pull request.
