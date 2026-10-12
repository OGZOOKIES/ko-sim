--!strict
-- Shapes of the data shared between server and client.

export type PetData = {
	Id: string,
	Species: string,
	Tier: number, -- 1 Normal, 2 Gold, 3 Diamond, 4 Rainbow
}

-- Saved player data. The server owns it; clients receive a copy without Lock.
-- When you add a field, add it to ServerScriptService.Logic.DataTemplate too.
export type PlayerData = {
	Version: number,
	Power: number,
	Wins: number,
	RebirthCount: number,
	RebirthTokens: number,
	OwnedGloves: { [string]: boolean },
	EquippedGlove: string,
	Pets: { [string]: PetData },
	EquippedPets: { string },
	NextPetId: number,
	Upgrades: { [string]: number },
	UnlockedWorlds: { [string]: boolean },
	CurrentWorld: string,
	SelectedBag: string,
	BestDistances: { [string]: number },
	Settings: { AutoTrain: boolean },
	Stats: { Launches: number, TotalWinsEarned: number, PetsHatched: number },
	Lock: { JobId: string, Time: number }?,
}

export type Result = {
	ok: boolean,
	message: string?,
	[string]: any,
}

return {}
