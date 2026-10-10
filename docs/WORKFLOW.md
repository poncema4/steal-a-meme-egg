# Workflow: Linux laptop (Claude Code) -> GitHub -> Windows PC (Studio)

Code is edited on Linux and pushed to GitHub through PRs. On the Windows PC: `.\scripts\serve.ps1` (git pull + `rojo serve`), Studio plugin > Connect. Rojo syncs scripts live.
Rojo does NOT carry meshes: export from Blender into `assets/`, then Studio > Asset Manager > Bulk Import. Parts-only visuals (the v0 game) need no import.
