# UI Layer Overview (Stage 1)

- Scenes (in `project/src/ui/scenes/`):
  - `stage01_slice.tscn` – demo composition scene wiring fixture load → battlefield view → action picker → dice panel → reference panel. Loads canonical fixture `res://docs/data-definition/fixtures/save_match.json`.
  - `battlefield_view.tscn` – grid/units/reachability/LoS rays; renders snapshot fields `board`, `units`, `terrain`, `reachability`, `los.rays`, `cover_sources`, `activation`, `mission`, `campaign`, `options`, `rng`, `logs`, `errors`.
  - `action_picker.tscn` – action OptionButton; consumes unit/action state; emits action selection.
  - `dice_panel.tscn` – shows event stream entries (`dice_roll`, `attack_resolved`, `melee_resolved`, `mission_score`, etc.).
  - `reference_panel.tscn` – loads `docs/data-definition/exports/ui_reference.json` (with localizations and per-round deltas) for glossary/reference.
  - Prototypes: `los_test_slice.tscn`, `los_bbox_slice.tscn` for LoS/cover visualization.

- Input bindings (desktop, Stage 1):
  - LMB select/confirm; RMB/ESC cancel.
  - Keys: `A/1` Move, `S/2` Attack, `D/3` Melee, `F/4` First Aid, `H/0` Hold, `R` Reroll, `Q` Quick Start, `Ctrl+Z` UI-undo selection.
  - Debug toggle: `F9` toggles ray overlays (Debug View) in `battlefield_view`.
  - Defined in `project/src/ui/ui_input_map.gd` via `UIContracts.input_binding`.
  - Touch/mobile deferred for Stage 1; add later if CP-001 parity is needed.

- DTO alignment:
  - Snapshots consume frozen Stage 1 DTO fields (board/units/terrain/reachability/los.rays/cover_sources/activation/mission/campaign/options/rng/logs/errors/hash).
  - Event stream uses `{type,payload,requirements,severity,timestamp?,event_seq?}`; logs accept strings or structured entries.

- Running the Stage 1 slice:
  - Open `stage01_slice.tscn` in Godot or run headless: `godot --headless --path . --scene res://project/src/ui/scenes/stage01_slice.tscn` (UI preview recommended via editor).
  - Demo button in the sidebar runs a sample `hold` command through `UISliceLoader`.
