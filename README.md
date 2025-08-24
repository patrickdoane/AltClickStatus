# Alt‑Click Status (Classic Era + ElvUI)

Alt‑Click Status is a World of Warcraft **Classic Era** addon that lets you quickly communicate the status of your **spells** and **character** via **Alt + Left‑click**—inspired by Dota 2’s ping/announce system.

* **Alt+Left‑click a spell** → prints its status (Ready / Cooldown with seconds / Recharging charges / On GCD, plus Range info) to your party/raid.
* **Alt+Left‑click Player/Target frames** → prints **HP%** and current **power** (Mana/Rage/Energy/etc.).
* **Alt+Left‑click does *not cast*** the spell (secure modifier override)—it only announces.
* Auto‑selects a chat channel (PARTY/RAID/SAY) or lets you force one.

> **Classic Era target**: Interface `11507`. ElvUI is **optional** (supported).

---

## Features

* Spell announcements with cooldowns, charges, GCD status, and in‑range hint
* Player/Target HP% + power announcements
* Does **not** trigger the spell on Alt+Left‑click (secure override)
* Works with **Blizzard** action bars and **ElvUI** bars
* Lightweight, combat‑safe configuration (defers secure changes until out of combat)

---

## Installation

1. Download the latest release ZIP from **GitHub Releases**.
2. Extract to:

   ```
   World of Warcraft/_classic_/Interface/AddOns/AltClickStatus/
     AltClickStatus.toc
     AltClickStatus.lua
   ```
3. Launch the game → **AddOns** (character select) → enable **Alt‑Click Status**.
4. In‑game, run `/reload`. You should see:

   ```
   Alt‑Click Status loaded (Interface 11507). Use /acs for options.
   ```

> If it shows as out‑of‑date, tick **Load out of date AddOns** or update to a build matching your client’s Interface number.

---

## Usage

### Announcing

* **Spells**: Hold **Alt** and **Left‑click** an action button.
* **Player frame**: Alt+Left‑click → “I have X% HP, Y% Power.”
* **Target frame**: Alt+Left‑click → “Name: X% HP, Y% Power.”

### Slash Commands

| Command                                 | Description                                             |
| --------------------------------------- | ------------------------------------------------------- |
| `/acs`                                  | Show usage/help.                                        |
| `/acs auto`                             | Auto channel selection (default).                       |
| `/acs say` / `/acs party` / `/acs raid` | Force output channel.                                   |
| `/acs toggle bar`                       | Enable/disable action‑bar Alt‑click behavior.           |
| `/acs toggle unit`                      | Enable/disable unit‑frame Alt‑click behavior.           |
| `/acs toggle elv`                       | Enable/disable ElvUI‑specific hooks.                    |
| `/acs hook elv`                         | Re‑run configuration (useful after UI profile changes). |
| `/acs debug on` / `off`                 | Toggle debug prints.                                    |

### Channel Auto‑Selection

Priority: **RAID** → **PARTY** → **SAY** (unless forced via `/acs`).

---

## ElvUI Support

* Hooks **ElvUI\_Bar** buttons and **ElvUF\_Player/Target** frames.
* If bars didn’t hook on login, use `/acs hook elv` once.

---

## How “no‑cast on Alt‑click” works

The addon sets secure attributes on each action button **out of combat**:

```lua
btn:SetAttribute("alt-type1", "macro")
btn:SetAttribute("alt-macrotext1", "/run AltClickStatus_AltClick(ButtonName)")
```

This sends the click to the addon’s function instead of casting. If you enter the world while in combat, the addon defers configuration and completes it on `PLAYER_REGEN_ENABLED`.

---

## Troubleshooting

**I don’t see the load message and `/acs` does nothing**

* Verify the folder and names:

  ```
  _classic_/Interface/AddOns/AltClickStatus/AltClickStatus.toc
  ```
* Ensure the folder name **AltClickStatus** matches the `.toc`.
* Check your client interface number with `/dump select(4, GetBuildInfo())`.

**Buttons still cast on Alt+Left‑click**

* Turn on debug: `/acs debug on`, then `/reload`.
* If a specific button isn’t overridden, get its name:

  ```
  /run print(GetMouseFocus():GetName())
  ```

  Open an issue with that name; we’ll add its prefix.

**I got an `ADDON_ACTION_BLOCKED` / taint error**

* That usually means a secure change was attempted **in combat**. The addon defers setup; if you still get errors, report steps to reproduce (were you entering the world in combat? which UI?)

---

## Development

### Repo Structure

```
AltClickStatus/
 ├─ AltClickStatus.toc
 └─ AltClickStatus.lua
```

### Building/Packaging

* Tag a version (e.g., `v0.3.0`) and attach a ZIP containing the **AltClickStatus/** folder with both files.

### Code Notes

* Uses only `HookScript` for read‑only hooks.
* No `RegisterForClicks` on secure buttons.
* Secure attribute overrides are applied out of combat; configuration is retried after `PLAYER_REGEN_ENABLED`.

---

## Roadmap

* Party/Raid **mouseover** announcements
* Item/Trinket cooldown announcements
* Message template customization per class/spec
* Localization

---

## Contributing

Issues and PRs are welcome! Please include:

* Client flavor + Interface number (e.g., Classic Era `11507`)
* Steps to reproduce
* Any error text
* If a button isn’t overridden, include `GetMouseFocus():GetName()` output

---

## License

MIT. See `LICENSE`.