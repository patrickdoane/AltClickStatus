Fix: make `/acs showrange` actually affect messages

**Problem**
Toggling range ON didn't change announcements in some cases.

**Fix**
- Compute range from the **action slot** first (`IsActionInRange(button.action)`), which works for spells/items/macros; fall back to `IsSpellInRange(spell,"target")`.
- Thread the button into the formatter so we can query the slot reliably.

**Result**
- When ON, messages append `· In Range` / `· Out of Range` / `· Range N/A` consistently.
- When OFF, no suffix is shown.
