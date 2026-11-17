--!strict
-- Shared type definitions so the server and client agree on data shapes.

export type Pet = {
	id: string,
	kind: string,
}

-- What gets saved for each player.
export type Profile = {
	version: number,
	coins: number,
	totalCoins: number,
	rebirths: number,
	upgrades: { [string]: number },
	pets: { Pet },
	equipped: { string },
	lastDaily: number,
	purchaseIds: { string },
}

-- What the server sends the client to draw the UI.
export type Snapshot = {
	coins: number,
	rebirths: number,
	upgrades: { [string]: number },
	pets: { Pet },
	equipped: { string },
	multiplier: number,
	coinValue: number,
	passes: { [string]: boolean },
	dailyReadyIn: number,
	equipSlots: number,
}

return {}
