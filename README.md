# Alt-Click Status (Classic Era)

[![Tag](https://img.shields.io/github/v/tag/patrickdoane/AltClickStatus?label=tag)](https://github.com/patrickdoane/AltClickStatus/tags)
[![release-on-tag CI](https://github.com/patrickdoane/AltClickStatus/actions/workflows/release-on-tag.yml/badge.svg)](https://github.com/patrickdoane/AltClickStatus/actions/workflows/release-on-tag.yml)
[![Release](https://img.shields.io/github/v/release/patrickdoane/AltClickStatus)](https://github.com/patrickdoane/AltClickStatus/releases)
[![CurseForge Downloads](https://img.shields.io/curseforge/dt/1333613?label=CurseForge\&logo=curseforge)](https://legacy.curseforge.com/wow/addons/altclickstatus)

Quickly announce your character state with **Alt+LeftClick** — inspired by Dota 2’s Alt-click pings.

> **Supports:** World of Warcraft **Classic Era (1.15.x)**. Optimized for **ElvUI** and Blizzard default action bars.

---

## ✨ Features

* **Action buttons:** Alt+LeftClick to announce the button’s spell **or** item status to party/raid chat.

  * Spells: **Ready**, **On Cooldown (Xs)**, **On GCD (Xs)**, **Not enough *Power*** (e.g., Mana/Rage/Energy/Focus with `(have/need)` when available).
  * Items/consumables/trinkets: **Ready**, **On Cooldown (Xs)**, **Not in Bags**, **Not Equipped** (for `/use 13`/`14`).
  * Macro-aware: understands `/cast` and `/castsequence` with conditionals (e.g., `[@cursor]`, empty `[]`).
  * `/use` support: item **names**, `item:ID`, and **trinket slots** `13` / `14`.
* **ElvUI unitframes:** Alt+LeftClick announces **HP%** and **Power%** for player/target/focus/pet.
* **Auras:** Alt+LeftClick your buff row or a target's buff/debuff to share remaining time or stack count — works with Blizzard and ElvUI widgets.
* **Mouse-only gate:** Only **Alt+LeftClick** counts — **Alt+keybinds (e.g., Alt+1)** won’t trigger announcements.
* **Range suffix toggle:** Hidden by default; opt-in with `/acs showrange on`.
* **Non-casting:** Alt+LeftClick does **not** activate the action; it only announces.
* **Smart channel** selection: `INSTANCE_CHAT` > `RAID` > `PARTY` > `SAY`.
* Lightweight and Classic-friendly (guards Classic APIs like `GetItemCooldown`).

---

## 🛠 Installation

**From CurseForge (recommended):**

* Project: `AltClickStatus` (ID **1333613**). Install via your addon manager.

**Manual:**

1. Download a release ZIP (`AltClickStatus-vX.Y.Z-classic.zip`).
2. Extract to your WoW Classic Era folder so the structure is:

   ```
   _classic_era_/Interface/AddOns/AltClickStatus/AltClickStatus.toc
   _classic_era_/Interface/AddOns/AltClickStatus/AltClickStatus.lua
   ```
3. Restart the game or `/reload`.

---

## 🚀 Usage

### Action bars

* **Alt+LeftClick** a spell or item button.
* Works with Blizzard bars and **ElvUI** bars.
* The addon won’t cast; it only prints a message to group chat.

### ElvUI unit frames

* **Alt+LeftClick** on Player / Target / Focus / Pet frames to announce HP% and Power%.

### Auras

* **Alt+LeftClick** your buff row to share remaining duration. Supports both Blizzard and ElvUI aura bars.
* **Alt+LeftClick** a target's buff or debuff to report its name and stacks (Blizzard UI: debuffs only).

### Slash commands

* `/acs debug on|off` — verbose debug prints.
* `/acs hook elv` — reconfigure hooks (use out of combat).
* `/acs showrange on|off|toggle` — show/hide range suffix in messages.

---

## 🧪 Handy test macros

```macro
#showtooltip
/cast [@cursor][] Blizzard
```

```macro
#showtooltip
/use 13
```

```macro
#showtooltip Major Healing Potion
/use Major Healing Potion
```

---

## ⚙️ How it works (tech notes)

* Hooks action buttons and injects a secure **`alt-type1=macro`** attribute that runs a tiny script to announce status.
* Prefers **`GetActionCooldown(action)`** for accurate cooldowns on bar slots; safely falls back to `GetItemCooldown`/`GetInventoryItemCooldown` where applicable.
* Item names are resolved via:

  1. action-slot tooltip scan; 2) bag link/name; 3) `GetItemInfo` cache; 4) inventory link (trinket slots). Falls back to `Item #ID` when uncached.
* Strict mouse gating records **PreClick** + **OnMouseDown** timing to avoid Alt+keybind false positives.

---

## ✅ Current compatibility

* **Client:** Classic Era (1.15.x).
* **Action bars:** Blizzard default, **ElvUI**.
* **Unit frames:** **ElvUI** (player/target/focus/pet).

> **Planned:** party/raid frames (ElvUI + default), bag-slot `/use <bag> <slot>`, config panel, localization & templates. See the issue tracker.

---

## 🧯 Troubleshooting

* **No message on Alt+Click:** Ensure you’re **out of combat** for initial hook; run `/acs hook elv`, then `/reload` if needed.
* **Items say `Not in Bags` but you have it:** If it’s a brand new drop, the client cache may be cold — use the item once or reopen bags.
* **Range always `N/A`:** Some items don’t report range from action slots; try a spell on the bar to verify range suffix.
* **Alt+keybind announces:** Update to a version ≥ `v0.3.0k` where the **mouse-only gate** is enforced.
* **Need the frame name under the cursor:** Some clients omit `GetMouseFocus`; run `/run print(MouseFocus and MouseFocus:GetName() or "nil")` while hovering to report it.

---

## 🤝 Contributing

* File bugs/ideas in **GitHub Issues**. Labels used: `status/todo`, `status/doing`, `status/done`, `type/bug`, `type/feat`.
* PRs welcome! Keep commits focused; include a short **Testing** section.

### Releases (CI)

* Tag-driven via GitHub Actions: push tag `vX.Y.Z` → package with **BigWigs Packager** → upload to **CurseForge**.
* Changelogs follow **Keep a Changelog** style; version badge updated on release.

### License

* MIT. See `LICENSE`.
