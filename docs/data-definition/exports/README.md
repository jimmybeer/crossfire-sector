# UI Reference Export
- Purpose: keep in-game glossary/reference data in sync with requirements (GR/DA) and the data dictionary.
- Source inputs: `docs/data-definition/data-dictionary.md`, `docs/rules.md`, `docs/requirements/requirements.md`.
- Target output: `docs/data-definition/exports/ui_reference.json` consumed by Godot UI panels (see `project/src/ui/scenes/reference_panel.gd`).

## Generation
- Run `node tools/build_ui_reference.js` to regenerate `ui_reference.json`.
- Source data: temporarily inline in `tools/build_ui_reference.js`; future work is to parse `docs/data-definition/data-dictionary.md` and `docs/rules.md`.
- Validate JSON shape via `node tools/schema_validate.js` after updates.

## Schema (summary)
- `version`: semantic version of the export.
- `generated_at`: ISO8601 timestamp.
- `factions[]`: id, name, stats, notes, requirements[], localizations?{}.
- `actions[]`: id, name, description, requirements[], localizations?{}.
- `missions[]`: id, name, summary?, scoring?, per_round_deltas?, requirements[], localizations?{}.
- `optional_rules`: commander_traits[], battle_events[] each with id/name/effect?/requirements[]/localizations?{}.
- `glossary[]` (optional): id, title, body, requirements[], localizations?{}.

## Open Items
- Automate extraction from data dictionary tables.
- Add localization keys once the UI needs translated text.
