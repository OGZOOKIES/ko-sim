# Architecture and balancing

## Server

```
Bootstrap.server.luau
  Net.Init()                      creates ReplicatedStorage.Remotes from Shared/Remotes
  Services: Init() in order, then Start() (PlayerDataService starts last)

PlayerDataService   load/save, session lock, autosave, pushes data to the client
WorldService        builds all five worlds, unlock + travel
ZoneRewardService   distance -> zone -> Wins (called by LaunchService)
TrainingService     Train event, bag selection, Auto Train loop
ShopService         gloves + glove visuals on the character
PetService          eggs, equip/unequip/delete, EquippedPets attribute
PetUpgradeService   5 identical pets -> next tier
RebirthService      rebirths
UpgradeService      token upgrades
LaunchService       charge -> launch -> flight tracking -> reward
```

Dependencies only point downward: services use `PlayerDataService`, `Net` and `Logic/Economy`, and `LaunchService` also uses `WorldService` and `ZoneRewardService`. Nothing depends on `LaunchService`.

Every change to a player's progress goes through `Logic/Economy.luau`. Its functions never yield, so a change can't be interrupted halfway. That is why fusing pets can never lose pets without granting the result, and why repeated requests can't duplicate currency. `Net` also allows only one request per player at a time and rate-limits each remote.

## Client

```
Client.client.luau      listens for StateUpdated, starts controllers, fetches initial state
ClientState             latest data copy + Changed signal
Controllers/
  UIController          ScreenGui, HUD, panels, toasts, confirm dialogs, Request()
  TrainingController    train button (tap/hold), auto toggle, +Power pop-ups
  LaunchController      charge meter, release, follow camera, live readout, results
  PetController         local pet followers for every player
  WorldController       station prompts -> panels, per-world lighting
UI/
  Theme, Components     shared look and building blocks
  Hud                   always-visible HUD
  HatchAnimation        egg hatch overlay
  Panels/*Panel.luau    one file per panel: Create(ui) -> { Name, Panel, Refresh, Key? }
```

Panels only rebuild when their `Key(data)` changes, so they don't flicker while Power ticks up.

## The launch

1. The player triggers the dummy prompt (or **Retry**). The server checks that their data is loaded, they're in that world, within `StationRange`, not mid-launch and off cooldown.
2. The client shows a meter that goes up and down (`Formulas.ChargeAt`). On release it sends the value it showed. The server accepts that value only if its own meter passed through it within the player's ping window; otherwise it uses its own value. A punch that is never released is released automatically after `MaxChargeTime`.
3. The server works out the distance from the player's stats (`Formulas.LaunchDistance`). It spawns a ragdoll that it simulates itself, aimed so its flight covers `FlightRangeFactor` of that distance. Tumbling covers the rest, which adds a little randomness.
4. Every frame the server measures the ragdoll's position along the runway. The launch ends when the ragdoll settles, leaves the runway (the last on-runway distance counts), or reaches `MaxFlightTime`. A session can only end once, so Wins are awarded once.
5. Ragdolls are in a collision group that ignores characters and other ragdolls, so players can't interfere with each other.

## Gloves

- `Shared/Config/GloveDesigns.luau` describes all 50 gloves. Each one picks:
  - a shell
  - a knuckle style
  - a cuff
  - an emblem
  - extra details
  - an effect
  - a palette and materials

  A test makes sure no two gloves share the same construction.
- `Shared/Gloves/GloveBuilder.luau` turns a design into parts:
  - `Build` / `BuildPair` make the 3D shop previews.
  - `Attach` puts the pair on a character. It works on R15 (hands) and R6 (arms), welds the gloves on, and replaces any old pair, so respawning never duplicates them.
- `ShopService` attaches the gloves on spawn and whenever you buy or equip a glove. The shop preview and the worn gloves use the same builder, so they always match.

## The punch

| Step | Where |
|---|---|
| Hold E on the dummy → charge (stance, wind-up pose, meter) | `LaunchController`, `PunchAnimator` |
| Release (let go of E / RELEASE / F) or Quick Punch (Q) | `LaunchController` → `ReleasePunch` |
| Server checks the timing, decides Perfect, tells everyone to play the punch | `LaunchService.Release` → `PunchFx` |
| After `ImpactDelay` the fist connects and the server launches the ragdoll | `LaunchService` |
| Flash, shockwave, sparks, sound, field-of-view kick and camera shake | `ImpactFx`, `LaunchController` |
| Follow camera (skippable), live readout, runway progress bar | `LaunchController` |
| Results count up, then "Punch again" | `LaunchController` |

- **Perfect window:** the Perfect zone always lasts `LaunchConfig.PerfectWindow` seconds at each peak of the meter, so the Charge Speed upgrade only ever helps.
- **Quick Punch:** uses `AutoCharge` and can never be Perfect, so precise timing is optional but still rewarded.
- **Animations:** the punch is procedural and works on R15 and R6 with no uploads. To use real animations, upload them and paste the ids into `Shared/Config/PunchConfig.luau` (the strike should have an `Impact` marker). Sound ids are in the same file.

## Multipliers

Every multiplier is documented and calculated in `Shared/Logic/Formulas.luau`. Each one feeds exactly one quantity:
- **Training:** bag, rebirths, pets, Training Power upgrade.
- **Punch force:** glove launch force.
- **Distance:** timing, Launch Control.
- **Wins:** Win Bonus.

`Formulas.Breakdown` feeds the in-game 📊 Stats panel, and a test checks that the panel's numbers multiply out to the real totals.

## Training Grounds

Built by `ServerScriptService/World/TrainingArea/` for every world. `WorldBuilder` calls it, and rebuilding replaces the old model instead of duplicating it:

| File | Builds |
|---|---|
| `Pavilion.luau` | Two-tier stone platform, 8 pillars, gabled roof, TRAINING GROUNDS sign, lanterns, banners, bag beam |
| `Bags.luau` | The six bags (models tagged `TrainingBag`, pivot at the hanging ring), mats, chains, labels, Cosmic orbiters |
| `Plaza.luau` | Floor extension, curved walkway and arch, side paths, planters, flower beds, benches, trees, rocks, hills |
| `ProgressBoard.luau` | The Basic → Cosmic board |

How the area looks is set in `Shared/Config/TrainingAreaConfig.luau` (colours, per-bag look, layout). Which bags you can use is still decided by `BagsConfig` and checked on the server in `Economy.SelectBag`.

On the client, `TrainingAreaController` does the following, for that player only:
- Fills in the lock and in-use status on the labels, prompts and board.
- Highlights the bag you walk up to and the bag you're training with.
- Handles the bag prompts: a bag you haven't selected sends `SelectBag`, and the selected bag trains.
- Swings your bag and shows a small impact when your Power rises while you're standing next to it.
- Turns the roof emblem and the Cosmic orbiters, only when the camera is nearby.

## Balancing

All numbers are in `src/ReplicatedStorage/Shared/Config`:

| Want to change... | Edit |
|---|---|
| Zone names, distances, Wins | `WorldsConfig` → `Zones` |
| How much Power reaches the last zone | `WorldsConfig` → `FullStrength` per world |
| How steep the distance curve is | `WorldsConfig.DistanceExponent` |
| Glove power/cost | `GlovesConfig` |
| Pet odds / multipliers | `PetsConfig` (`Rarities`, `WorldScale`) |
| Egg costs | `EggsConfig` |
| Rebirth cost and multiplier | `RebirthConfig` |
| Bags | `BagsConfig` |
| Upgrades | `UpgradesConfig` |
| Charge meter, launch feel, end conditions | `LaunchConfig` |
| Training speed, autosave | `GameConfig` |

The formulas are documented at the top of `Shared/Logic/Formulas.luau`.

The **starting** numbers are first guesses: they have not been playtested. A good first balancing pass is to play Greenfield from scratch and time how long each glove, the first egg and the first rebirth take.

## Saved data

`ServerScriptService/Logic/DataTemplate.luau` defines the schema (version 1). On load: migrate (version upgrades), reconcile (fill in missing fields), sanitize (fix anything that no longer matches the config).

- Data is read and written with `UpdateAsync` only.
- A session lock stops two servers saving the same player. A server that finds a fresh lock waits and retries, and takes the lock over on the last attempt.
- If loading fails on a live server, the player is kicked and nothing is ever saved for them, so default data can never overwrite real progress.
- Autosave runs every 60 seconds, and everyone is saved on shutdown (`BindToClose`).
