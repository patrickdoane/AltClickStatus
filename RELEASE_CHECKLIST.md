# AltClickStatus – Release Checklist

## Pre‑flight
- [ ] Bump version in `AltClickStatus.toc` (e.g., `## Version: 0.3.0`).
- [ ] Verify Classic Era interface with `/dump select(4, GetBuildInfo())` and update `## Interface:` if needed.
- [ ] Confirm README is up to date (features, commands, screenshots).
- [ ] Smoke test in game:
- [ ] `/reload` → load message appears.
- [ ] `/acs` works; `/acs debug on` shows hook/override counts after reload.
- [ ] Alt+Left‑click on Blizzard bar: does **not** cast; announces status.
- [ ] Alt+Left‑click on ElvUI bar: does **not** cast; announces status.
- [ ] Alt+Left‑click Player/Target frames: announces HP/Power.
- [ ] No taint errors entering combat; overrides apply after leaving combat if deferred.

## Tag & Release
- [ ] Commit all changes; push to `main`.
- [ ] Create a semver tag: `vX.Y.Z` (e.g., `v0.3.0`).
- [ ] Push tag to GitHub. The **Release** workflow will:
- Build the zip using `.pkgmeta`.
- Create a GitHub Release (with README as changelog if configured).
- Upload to CurseForge/Wago/WoWI if tokens are set.

## Post‑release
- [ ] Install the zipped release locally; final smoke test.
- [ ] Update issue tracker with any follow‑ups.