# Contributing

## Getting set up

1. Accept the GitHub invite to the repository.
2. Clone it somewhere that is **not** inside OneDrive, Dropbox or iCloud. Sync tools can corrupt Git repositories.
   ```powershell
   git clone https://github.com/OGZOOKIES/ko-sim.git
   cd ko-sim
   ```
3. Follow **One-time setup** in [README.md](README.md). `rokit install` gives everyone the same Rojo version.
4. Ask for edit access to the Roblox place (Game Settings → Permissions).

## Branches

- `main`: stable, playable versions. Never commit directly to it.
- `dev`: where finished features come together and get tested.
- Feature branches: one per system, made from `dev`. For example `feature/trading`, `fix/ragdoll-stuck` or `balance/desert-gloves`.

## Workflow for each change

```powershell
git switch dev
git pull
git switch -c feature/my-thing
# ...work, then test in Studio (check that the [Tests] line in Output passes)...
git add .
git commit -m "Add pet trading"
git push -u origin feature/my-thing
```

Open a pull request into `dev` on GitHub. The other person reviews it and merges it. When `dev` is stable, open a pull request from `dev` into `main`.

## Not overwriting each other

1. **Code goes through Git, not Studio.** Edit files in `src/`. Script edits made in Studio are overwritten on the next Rojo sync.
2. **Split work by file.** The code is split so that two people rarely need the same file:
   - Each system has its own service (`Services/*.luau`) and its own panel (`UI/Panels/*.luau`).
   - Balance changes only touch `Shared/Config/*.luau`.
   - Shared files that everyone edits now and then: `Logic/Economy.luau`, `Logic/Formulas.luau`, `Shared/Remotes.luau`, `Logic/DataTemplate.luau`. Tell each other before changing these.
3. **Pull before you start.** Commit small changes often.
4. **Test in your own copy of the place.** Each person runs `rojo serve` against their own place file or test place. If two people sync to the same Team Create place, each sync overwrites the other's.
5. **Changing saved data:** add the new field in `DataTemplate.New()` and `Shared/Types.luau`. If old saves need converting, bump `VERSION` and add a migration. Never rename or remove a saved field without a migration.
6. **Never commit secrets.** That includes API keys, Open Cloud keys and `.ROBLOSECURITY` cookies.

## Code rules

- **The server decides everything that matters.** Clients only *ask* through remotes. Every remote handler checks argument types and looks ids up in config. A client never sends prices, rewards, odds, distances or positions that the server trusts.
- **Every progress change goes through `Logic/Economy.luau`.** Its functions must not yield, so each change finishes completely or not at all. Add a test in `Tests/Economy.spec.luau` for anything new.
- **Gameplay numbers live in `Shared/Config` and `Shared/Logic/Formulas.luau`, not inside services.**
- Log with `Log.new("Tag")` instead of bare `print`.
- New remotes: add the name to `Shared/Remotes.luau`, handle it with `Net.Handle` / `Net.On` in a service.

## What gets committed

Commit everything in the repository except what `.gitignore` excludes: place files (`.rbxl`/`.rbxlx`), `build/`, `sourcemap.json`, `.env` files and package folders.
