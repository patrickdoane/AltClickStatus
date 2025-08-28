### Added
- Finalized Items & `/use` support: direct items on bars, `/use item:ID`, item names, and trinket slots 13/14.

### Fixed
- Macro parsing for `/cast` (handles `[@cursor]`, `[]`, `castsequence`).
- Item/trinket announcements now use proper names (tooltip/bag/inventory fallback) instead of raw IDs.
- Guarded Classic cooldown APIs; prefer action-slot cooldowns.
