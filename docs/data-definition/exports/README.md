# UI Reference Export
- Purpose: keep in-game glossary/reference data in sync with requirements (GR/DA) and the data dictionary.
- Source inputs: `docs/data-definition/data-dictionary.md`, `docs/rules.md`, `docs/requirements/requirements.md`.
- Target output: `docs/data-definition/exports/ui_reference.json` consumed by Godot UI panels (see `project/src/ui/scenes/reference_panel.gd`).

## Generation
- Run `node tools/build_ui_reference.js` to regenerate `ui_reference.json`.
- Add new factions/missions/actions in the script until a data-source pipeline is introduced.
- Validate JSON shape via `node tools/schema_validate.js` after updates.

## Schema (summary)
- `version`: semantic version of the export.
- `factions[]`: id, name, stats, notes, requirements[].
- `actions[]`: id, name, description, requirements[].
- `missions[]`: id, name, requirements[].
- `optional_rules`: commander_traits[], battle_events[] each with id/name/requirements[].

## Open Items
- Automate extraction from data dictionary tables.
- Add localization keys once the UI needs translated text.
