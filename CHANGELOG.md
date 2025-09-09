# Changelog



All notable changes to this project are documented here.



This format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).



## [Unreleased]



### Added
- Alt+LeftClick party/raid unit frames (ElvUI party/raid incl. Raid40, Blizzard party).




### Changed
- Target buff/debuff announcements now show the target with remaining duration formatted with hours and minutes when applicable.

### Fixed

-



### Removed

-



### Notes for Users
- Announce teammate HP/Power by Alt+LeftClicking their unit frame in party/raid/battlegrounds.



### Dev / CI

-



---



## [v0.3.0k] - 2025-08-28



### Added

- ElvUI unit frames: Alt+LeftClick announces HP/Power (player, target, focus, pet).

- Finalized Items & `/use` support: direct items on bars, `/use item:ID`, item names, and trinket slots 13/14.



### Changed

- Range suffix hidden by default to reduce chat noise; toggle with `/acs showrange on|off|toggle`.



### Fixed

- Alt + keybind (e.g., Alt+1) no longer triggers announcements; only Alt+Left mouse clicks. (#12)

- Announce **Not enough _Resource_** (Mana/Rage/Energy/Focus) when a spell is otherwise ready but you lack resources, including `(have/need)` when available via `GetSpellPowerCost`. (#17)

- `/acs showrange` toggle reliably adds/removes range suffix; uses action-slot range with spell fallback.

- Macro parsing for `/cast` handles `[@cursor]`, `[]`, and `castsequence` noise; macro’d spells no longer print `Action > Ready`.

- Item/trinket announcements show full names (tooltip/bag/inventory fallback) instead of raw IDs.

- Guarded Classic cooldown APIs; prefer action-slot cooldowns when available.



[Compare v0.3.0i…v0.3.0k](https://github.com/patrickdoane/AltClickStatus/compare/v0.3.0i...v0.3.0k)



---



## [v0.3.0i] - 2025-08-26



### Notes for Users

- No gameplay changes.



### Dev / CI

- Tag-driven release workflow stabilized:

  - Primary publisher: **BigWigs Packager** to CurseForge.

  - **Automatic game version** derived from TOC `## Interface:` (e.g., `11507 → 1.15.7`).

  - Fallback uploader to CurseForge if packager zips nothing.

  - Keeps GitHub asset: `AltClickStatus_vX.Y.Z.zip`.



[Compare v0.3.0h…v0.3.0i](https://github.com/patrickdoane/AltClickStatus/compare/v0.3.0h...v0.3.0i)



---



## [v0.3.0h] - 2025-08-25



### Notes for Users

- No gameplay changes.



### Dev / CI

- Added **debug job** that runs on failure and prints packager staging to diagnose zipping issues.

- Clean `.pkgmeta` generated in CI to avoid CRLF / whitespace edge cases.



[Compare v0.3.0g…v0.3.0h](https://github.com/patrickdoane/AltClickStatus/compare/v0.3.0g...v0.3.0h)



---



## [v0.3.0g] - 2025-08-25



### Notes for Users

- No gameplay changes.



### Dev / CI

- **Repository layout moved** to top-level `AltClickStatus/` (packager-friendly).

- TOC updated to use `## Version: @project-version@` and `## X-Curse-Project-ID: 1333613`.

- Simplified `.pkgmeta` (`package-as: AltClickStatus`).



[Compare v0.3.0f…v0.3.0g](https://github.com/patrickdoane/AltClickStatus/compare/v0.3.0f...v0.3.0g)



---



## [v0.3.0f] - 2025-08-25



### Notes for Users

- No gameplay changes.



### Dev / CI

- CI preflights: verify tag exists; dump repo tree; fail early if TOC/.pkgmeta are missing at the **tag**.

- Hardened `.pkgmeta` for multiple layouts (transitional).



[Compare v0.3.0d…v0.3.0f](https://github.com/patrickdoane/AltClickStatus/compare/v0.3.0d...v0.3.0f)



---



## [v0.3.0d] - 2025-08-24



### Notes for Users

- No gameplay changes.



### Dev / CI

- Fixed release artifacts:

  - Ensure internal ZIP structure is `./AltClickStatus/...`.

  - Ensure TOC `## Version` is correctly set in packaged copies.

  - Introduced `.pkgmeta` and `@project-version@` flow for CurseForge packager.



[Compare v0.3.0b…v0.3.0d](https://github.com/patrickdoane/AltClickStatus/compare/v0.3.0b...v0.3.0d)



---



## [v0.3.0b] - 2025-08-24



### Added

- **Debug mode** toggle and improved logging for troubleshooting.



### Changed

- **Alt+LeftClick no longer casts the spell**; it only announces status in chat.

- Improved compatibility with ElvUI action buttons and Classic Era secure frames.



### Fixed

- Macro parsing: empty bracket conditional `[]` no longer breaks announcements (e.g.,  

  ```

  #showtooltip

  /cast [@cursor][] Blizzard

  ```

  now announces correctly).- Resolved syntax/loader errors (e.g., unfinished string; hook errors on load).



### Notes for Users

- You can Alt+LeftClick on action buttons to announce readiness or cooldown (with remaining seconds).

- Health/mana and spell announcements use concise, party-friendly phrasing.



### Dev / CI

- Initial CI added: GitHub Release ZIP + badges; groundwork for packager.



[Compare v0.3.0…v0.3.0b](https://github.com/patrickdoane/AltClickStatus/compare/v0.3.0...v0.3.0b)



---



## [v0.3.0] - 2025-08-23



### Added

- **Alt-Click Announce** for Classic Era:

- Alt+LeftClick your **health**/**mana** bars to announce percentages.

- Alt+LeftClick **spells** to announce **Ready** or **On Cooldown (Xs)**.

- Works with standard action buttons; ElvUI supported.

- Basic slash command `/acs` (toggles / help).



### Notes for Users

- Designed to reduce voice/typing overhead in dungeons/raids by broadcasting your status quickly.



[Compare initial…v0.3.0](https://github.com/patrickdoane/AltClickStatus/compare/HEAD~1...v0.3.0)