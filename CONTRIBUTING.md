# Workflow

Solo project: everything goes straight to `main`.

## Saving your work

```powershell
git add .
git commit -m "What you changed"
git push
```

Commit whenever something works. If you break something, you can always go back.

## Rules that keep the game safe

- **Edit code in `src/`, not in Studio.** Rojo overwrites script edits made in Studio.
- **Balance changes go in `src/ReplicatedStorage/Shared/Config/`.**
- **Changing saved data:** add the new field to `DataTemplate.New()` and `Shared/Types.luau`. Never rename or remove a saved field without adding a migration in `DataTemplate`.
- **The server decides everything that matters.** Clients only ask through remotes, and every progress change goes through `ServerScriptService/Logic/Economy.luau`.
- **Never commit secrets** (API keys, cookies).

## If someone joins later

They clone the repo outside OneDrive, follow the setup in README.md, and you both switch to feature branches and pull requests.
