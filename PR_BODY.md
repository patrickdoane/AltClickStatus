feat(items): finalize Items & /use support; fix names & macro parsing (Issue #25)

### Summary
- **Items & `/use` support**: recognize `/use 13|14` (trinket slots), `item:ID`, item names, and direct action-slot items.
- **Name resolution**: prefer real item names, avoiding raw IDs via:
  - action-slot **tooltip** scan (for uncached items on bars),
  - bag scan by exact name, and
  - inventory link for trinket slots.
- **Macro parsing**: robust handling of bracket conditionals (e.g., `[@cursor]`, `[]`) for `/cast` and `/castsequence`.
- **Safety**: guarded `GetItemCooldown`, prefer `GetActionCooldown`, strict mouse-only gate (prevents Alt+keybind announcements).
- **Unit frames**: ElvUI Alt+LClick status remains supported.

### Testing
- Spell button (e.g., *Blizzard (Rank 1)*) → `Blizzard (Rank 1) > Ready`.
- Macro: `/cast [@cursor] Blizzard` → resolves spell correctly (not `Action > Ready`).
- Item on bar (no macro): *Greater Healing Potion* → real name (not `1710`) and correct status.
- Macro: `/use Greater Healing Potion` → resolves name & bag presence.
- `/use 13` with/without trinket → trinket name or `Not Equipped`.

Closes #25.
