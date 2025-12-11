# Stage 1 – UI Contracts & Reference Data Feeds
- Stage ID: 01
- Version: 1.1.0
- Last Updated: 2025-11-29
- Author/Agent: Planning & Roadmap Agent ([PLANNER])

## Context & Goals
- Purpose: deliver the first functional vertical slice by wiring Stage 0 deterministic foundations (commands/validator previews, RNG, persistence/log fixtures, schema checks) into UI-facing contracts and data feeds.
- Builds on Stage 0 outputs: reuses command DTOs, validator preview hooks, ProductionResolver, seeded RNG/state hashing, persistence fixtures, schema validation scripts, and LoS/cover micro-bench plan scaffolds as stable inputs.
- MVP slice focus: battlefield view plus action/log/reference UI powered by state snapshots and events; desktop pointer/keyboard input mapped to commands; rules/reference data pulled from data dictionary exports.
- Critical step: freeze UI/data contracts so Stage 2 can implement full rules without reworking presentation or data flows; ensure traceability to GR/DA/CP/AQ/MP requirements is maintained.
- Scope & constraints (traceability):
	- Board/state snapshot fidelity: show 15x9 grid, units, terrain, bounds, reachability per validator (GR-001, GR-018, GR-032, DA-004); keep seeded RNG/hash visible for replay (AQ-003–AQ-004, MP-005).
	- Actions/validation previews: half-move + Shoot/Melee, First Aid, Hold, reroll legality surfaced via DTOs (GR-015–GR-028, GR-045, DA-004–DA-007, DA-012, DA-018).
	- LoS/cover visuals: indicators and optional ray diagnostics aligned to validator outputs (GR-004, GR-031, DA-005, DA-021).
	- Mission/campaign overlays: mission IDs, per-round scoring, campaign totals/advantages surfaced (GR-033–GR-040, DA-009, DA-015–DA-017).
	- Optional rules toggles: commander/events/campaign flags represented and immutable unless enabled (GR-041–GR-042, DA-010, DA-019–DA-020, AQ-006).
- Input maps: desktop pointer/keyboard bindings to Command DTOs; mobile/touch deferred unless approved (CP-001–CP-004; confirm CP-001 touch parity scope for Stage 1).
- Reference data feed: glossary/reference panel consumes generated JSON from data dictionary/rules exports (DA-014, AQ-002).

## UI Snapshot/Event DTO Summary (Stage 1 frozen)
- Snapshot DTO (GR/DA/AQ/MP coverage):

| Field | Type | Required | Notes | Req IDs |
| --- | --- | --- | --- | --- |
| version | string | yes | Snapshot schema version | AQ-003–AQ-004 |
| board | object | yes | `{columns:int, rows:int}` | GR-001, DA-004 |
| units | array | yes | `[{id, owner_id, position{col,row}, status, cover?, in_range?, activated?}]` | GR-005–GR-030, GR-045, DA-003–DA-007, DA-012, DA-018 |
| terrain | array | yes | `[{template_id, cells:[{col,row}]}]` | GR-002–GR-004, GR-018, GR-031, DA-004–DA-005 |
| reachability | array | no | `[{col,row,color?,name?}]` (half-move labels allowed) | GR-018–GR-020, DA-004 |
| los | array | no | `[{from,to,visible,path?,blocker?,rays?}]`; `rays[]` included by default | GR-004, GR-031, DA-005, DA-021 |
| cover_sources | array | no | `[{col,row,kind}]` | GR-004, DA-005 |
| activation | object | yes | `{round:int, active_player:string, remaining:int}` | GR-013–GR-017, GR-043–GR-044, DA-003 |
| mission | object | yes | `{mission_id:string, scores:{p1:int,p2:int}, round:int}` | GR-033–GR-035.1, DA-008–DA-009, DA-016 |
| campaign | object | yes | `{battle_index:int, total_battles:int, scores:{p1:int,p2:int}, advantages:[string]}` | GR-036–GR-040, DA-009, DA-015–DA-017 |
| options | object | yes | `{commander:bool, events:bool, quick_start_used:bool, revive_used:bool}` | GR-041–GR-042, DA-010, DA-017, DA-019–DA-020, AQ-006 |
| rng | object | yes | `{seed:string, offset:int}` | AQ-003–AQ-004, MP-005 |
| logs | array | yes | Strings or structured entries `{type,message,requirements?,timestamp?,severity?}` | DA-013, MP-004 |
| errors | array | no | `[{code:string,message:string,requirement_id?:string}]` | DA-001–DA-007 |
| hash | string | no | State hash for determinism evidence | AQ-003, MP-005 |

- Event DTO (dice/results/log stream):

| Field | Type | Required | Notes | Req IDs |
| --- | --- | --- | --- | --- |
| type | string | yes | Event kind (dice_roll, attack_resolved, melee_resolved, mission_score, campaign_score, error, log_line, etc.) | DA-006, DA-013 |
| payload | object | yes | Event-specific data (dice, attacker/target ids, damage, hashes) | GR-022–GR-028, GR-033–GR-035.1 |
| requirements | array\<string> | yes | Traceability IDs | GR/DA coverage |
| severity | string | yes | Enum: info/warning/error | DA-006, DA-013 |
| timestamp | int | no | Optional epoch ms for logs/telemetry | DA-013 |
| event_seq | int | no | Optional monotonic sequence for ordering | AQ-003, MP-003 |

- Adapter alignment (validator preview + resolver):
	- `preview.reachable_tiles` → `reachability` with optional `name` labels (half-move, first-aid).
	- `valid_targets`/range flags → `units[].in_range` and/or picker helper data.
	- LoS/cover preview → `los`, `cover_sources`, `units[].cover`; optional `rays` for diagnostics.
	- Activation legality → `activation.remaining`, `units[].activated`.
	- Dice/attack/melee outcomes → `event` stream; status updates reflected in `units[].status`.
	- Mission/campaign scoring → `mission` and `campaign` blocks plus `mission_score`/`campaign_score` events.
	- Optional rules usage → `options` flags (commander/events/campaign), `quick_start_used`, `revive_used`.
- Determinism → `rng.seed`, `rng.offset`, optional `hash`; consider `event_seq` if telemetry ordering is needed.

## UI Scene & Input Mapping Plan
- Scenes/nodes (project/src/ui/scenes):
	- `battlefield_view.tscn` (`battlefield_view.gd`): Grid layers (tiles/reachability/LoS rays/units), StatusLabel, LogPanel/LogText. Consumes snapshot fields `board`, `units`, `terrain`, `reachability`, `los` (with `rays`), `cover_sources`, `activation`, `mission`, `campaign`, `options`, `rng`, `logs`, `errors`. Signals (to add): `cell_selected(col,row)`, `unit_selected(unit_id)`, `command_requested(command_dict)`.
	- `action_picker.tscn` (`action_picker.gd`): OptionButton for actions; consumes `units[].status/in_range`, `activation.remaining`, `options`. Signals: `action_chosen(action_id)`, `target_requested`.
	- `dice_panel.tscn` (`dice_panel.gd`): RichTextLabel for dice/results; consumes event stream entries (`dice_roll`, `attack_resolved`, `melee_resolved`, `mission_score`, `campaign_score`, `log_line`). Signals: none.
	- `log_viewer` (within battlefield/log panel): shows `logs` and error events; consumes `logs`, `errors`, event stream. Signals: `log_scrolled`.
	- `reference_panel.tscn` (`reference_panel.gd`): RichTextLabel loading `docs/data-definition/exports/ui_reference.json`; consumes `factions`, `actions`, `missions`, `optional_rules`, `glossary`, including `localizations` and `per_round_deltas`. Signals: `reference_loaded`, `reference_failed`.
	- `stage01_slice.tscn` (`stage01_slice.gd`): Composition scene wiring `battlefield_view`, `action_picker`, `dice_panel`, `reference_panel`; uses `UISliceLoader` to load `docs/data-definition/fixtures/save_match.json` as canonical fixture.
	- Prototypes: `los_test_slice.tscn`/`.gd` and `los_bbox_slice.tscn`/`.gd` for LoS/cover visualization spikes (consume `los.rays`, `reachability`).
	- Placeholder assets: simple colored sprites/tiles for units/terrain; line2D for rays; icons for actions (optional). No binary assets required; reuse Godot primitives.

- Input mapping (desktop pointer/keyboard → Command DTOs):
	- Pointer select (LMB): select unit/cell → build `command{type:"select", payload:{unit_id?, cell}}` (internal UI command, not sent to resolver).
	- Pointer confirm (LMB on highlighted): `command{type:"move"/"attack"/"melee"/"first_aid"/"hold"}` depending on current action selection and target.
	- Right-click / ESC: cancel current selection → internal cancel command.
	- Keyboard bindings (Godot InputMap):
		- `A`/`1`: action select Move (`command_type:"move"` payload path from preview).
		- `S`/`2`: Attack (`command_type:"attack"` with target).
		- `D`/`3`: Melee (`command_type:"melee"`).
		- `F`/`4`: First Aid (`command_type:"first_aid"`).
		- `H`/`0`: Hold (`command_type:"hold"`).
		- `R`: Reroll (`command_type:"reroll"` with die selection).
		- `Q`: Quick Start Move (when available) (`command_type:"quick_start_move"`).
		- `Ctrl+Z`: undo UI selection only (no game-state undo in Stage 1).
	- Mapping stored in `project/src/ui/ui_input_map.gd` and documented in `docs/architecture/architecture.md` under UI/Input.
- Touch/mobile: deferred; add later per CP-001 approval.
- Control scheme: Desktop bindings locked (LMB select/confirm, RMB/ESC cancel, A/1 Move, S/2 Attack, D/3 Melee, F/4 First Aid, H/0 Hold, R Reroll, Q Quick Start, Ctrl+Z UI undo). Touch/mobile deferred.

## LoS/Cover Visualization Spike
- Prototypes:
	- Bresenham overlay: `project/src/ui/scenes/los_test_slice.tscn/.gd` renders tile highlights for LoS blocks/corners; good clarity but less explicit on blockers.
	- Bounding-box raycast: `project/src/ui/scenes/los_bbox_slice.tscn/.gd` samples multiple rays per cell; renders rays and blockers, clearer performance footprint and debug info.
- Chosen approach: bounding-box raycast sampling (preferred) with `los.rays` included in snapshot for debug rendering. Performance acceptable in prototype; keep Line2D rendering lightweight. Rays live behind a Debug View toggle (per scene) so overlays can be enabled/disabled.
- UI cues:
	- Rays (Debug View): draw Line2D from attacker to target; blocked rays colored red, clear rays green; toggle on/off per scene.
	- Tiles: highlight reachable tiles and cover sources; blocked cells shaded; cover markers on target-adjacent blockers.
	- Tooltip/log: log blocker info from `los.rays[].blocker`.
- Updates needed in `battlefield_view`:
	- Consume `los.rays` for line rendering when Debug View is enabled (toggle flag in `battlefield_view.gd`); retain shaded tiles for blocked paths.
	- Ensure cover icons/markers align to `cover_sources` and unit cover flags.
	- Keep performance budget by batching ray draws and limiting per-frame updates to current selection.
- Confirmed visualization: rays + shaded tiles + cover icons, with rays gated by Debug View toggle. Touch/mobile can keep rays off by default.

- Control scheme approval: please confirm desktop bindings above or suggest alternatives (e.g., WASD vs number keys, right-click cancel vs keyboard-only cancel). Touch/mobile remains deferred unless you want parity now.

## Step-by-Step Implementation Plan (with Agent Mapping)
- Context reload & scope note (ARCH lead, REQ support): Re-read `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/architecture/tech-stack.md`, `docs/data-definition/data-dictionary.md`, `docs/plans/roadmap.md`, and `docs/plans/plan-stage-00-output.md`; restate Stage 1 scope/constraints in this file with GR/DA/CP/AQ/MP traceability.
- Freeze UI snapshot + event DTOs (ARCH lead, REQ review): Define render-facing DTOs for board grid, units, reachability/LoS/cover previews, activation/round status, mission/campaign scores, RNG/log events (dice rolls/results), and errors. Record full field lists and types in `docs/architecture/architecture.md`; mirror summary tables here with requirement IDs.
	- DTO field summary (refs: GR-001–GR-045, DA-001–DA-021, AQ-001–AQ-004): Snapshot → `version`, `board{columns,rows}`, `units{id,owner_id,position,status,cover?,in_range?}`, `terrain{template_id,cells[]}`, `reachability[{col,row,color?,name?}]`, `los[{from,to,visible,path?,blocker?}]` (or per-target flags), `cover_sources[{col,row,kind}]`, `activation{round,active_player,remaining}`, `mission{mission_id,scores,round}`, `campaign{battle_index,total_battles,scores,advantages[]}`, `options{commander,events,quick_start_used,revive_used}`, `rng{seed,offset}`, `logs[]`, `errors{code,message,requirement_id?}`, `hash?`; Event → `{type,payload,requirements[],severity,timestamp?}`; Preview MAY include LoS ray diagnostics `rays[{from,to,blocked,blocker?}]` for the raycast method.
- Validator-preview + resolver alignment (ARCH lead): Map DTO fields to Stage 0 validator preview outputs and ProductionResolver responses; define minimal adapter stubs in `project/src/ui/` to translate engine data → UI DTOs; capture adapter contract notes here.
- Reference data export plan (DATA ENG lead, REQ review): Design generator flow to emit `docs/data-definition/exports/ui_reference.json` combining stats/actions/missions/optional rules from `docs/data-definition/data-dictionary.md` and `docs/rules.md`; specify schema, paths, and sync cadence; note any required fixtures in `docs/data-definition/fixtures/`.
- UI scene scaffolding (ARCH/tech-stack lead, ENG support): Outline Godot scenes/nodes under `project/src/ui/` for battlefield grid, unit tokens, action picker, dice/result panel, log viewer, and reference/glossary panel; list placeholder assets and signals; map each scene to DTOs and note autoload/singletons used.
	- Current nodes/signals/assets: `battlefield_view.tscn` (Grid with Tiles/Reachability/Rays/Units layers, StatusLabel, LogPanel/LogText; consumes snapshot board/units/los/reachability/logs; no signals yet), `action_picker.tscn` (OptionButton, no signals), `dice_panel.tscn` (RichTextLabel, no signals), `reference_panel.tscn` (RichTextLabel loads `ui_reference.json`), `los_test_slice.tscn`/`los_bbox_slice.tscn` (LoS prototypes). Autoloads: none required yet (UIContracts/UIAdapter/UICommandBus are constructed per slice). Asset gaps: real unit/terrain tokens, dice/icons, glossary formatting/styling.
- Input mapping (ARCH lead, ENG support, REQ review): Define desktop pointer/keyboard bindings to Command DTOs via command bus abstraction; list bindings (select, path preview, attack target, reroll, cancel); document in `docs/architecture/architecture.md` and summarize here.
- Integration slice assembly (ARCH lead, ENG support): Plan end-to-end flow: load fixture match from `docs/data-definition/fixtures/`, render via UI DTOs, invoke validator preview on selection, execute a command through ProductionResolver, update state/log view, and recompute hash; enumerate required stubs/mocks and file touchpoints.
	- Smoke harness: `project/tests/ui_snapshot_smoke.gd` loads `docs/data-definition/fixtures/save_match.json`, renders snapshot via `UISliceLoader`, and runs a hold command through `UICommandBus` to exercise DTO wiring end-to-end.

## Integration Slice Plan (End-to-End)
- Flow:
	1) Load canonical fixture `docs/data-definition/fixtures/save_match.json` into `UISliceLoader` (uses seeded RNG, data_config).
	2) Adapter maps engine state → UI snapshot DTO (frozen Stage 1 fields).
	3) User selects unit/cell; `UICommandBus.preview` invokes validator preview → updates `reachability`/`los`/`cover_sources` in snapshot.
	4) Execute command via `UICommandBus.enqueue` → ProductionResolver → new state/log/events/hash → adapter to snapshot.
	5) UI panels render snapshot/event stream; logs updated; RNG offset/hash tracked.
- Stubs/mocks & touchpoints:
	- `project/src/ui/ui_slice_loader.gd` (loader/orchestrator).
	- `project/src/ui/ui_adapter.gd` (state→snapshot).
	- `project/src/ui/ui_command_bus.gd` (binding→command, validator/resolver wiring).
	- `project/src/validation/command_validator.gd`, `project/src/core/sample_resolver.gd` (ProductionResolver stub).
	- `project/src/services/rng_service.gd` (seeded RNG).
	- Scenes: `battlefield_view.tscn`, `action_picker.tscn`, `dice_panel.tscn`, `reference_panel.tscn`, `stage01_slice.tscn`.
	- Fixture/data: `docs/data-definition/fixtures/save_match.json`; reference feed `docs/data-definition/exports/ui_reference.json`.
	- Hash/logs: ensure snapshot includes `hash`, `rng.offset`, `logs` (strings/structured); recompute hash via resolver/state_hasher if needed.
- Smoke harness (`project/tests/ui_snapshot_smoke.gd`):
	- Loads `save_match.json`, renders initial snapshot, prints counts.
	- Builds a `hold` command (binding → command) and enqueues it through `UICommandBus`/ProductionResolver.
	- Prints resulting snapshot and events to verify DTO wiring; uses default data_config with board/home zones.
	- Headless invocation via `godot --headless --path project -s res://project/tests/ui_snapshot_smoke.gd`.
- Open question: none; canonical fixture confirmed as `save_match.json`.

## Reference JSON Import Spike (Godot Reference Panel)
- Steps:
	1) Load `docs/data-definition/exports/ui_reference.json` in `reference_panel.gd` using `FileAccess.get_file_as_string` and `JSON.parse_string`.
	2) Validate presence of `version`, `factions`, `actions`, `missions`, `optional_rules`, `glossary`, `localizations`, `per_round_deltas`.
	3) Render basic RichText output (fallback plain text) listing factions/actions/missions/optional rules; include per-round deltas if present.
	4) Log parse errors to the Godot console and emit `reference_failed` if JSON is missing or invalid; emit `reference_loaded` on success.
	5) (Optional) Add shape check to `tools/schema_validate.js` for `ui_reference.json` and run in CI.
- Blockers/risks:
	- Current generator (`tools/build_ui_reference.js`) still uses inline data; parsing data dictionary/rules needed for full fidelity.
	- Localization formatting and size constraints not yet defined; RichText styling TBD.
- Conventions (if spike succeeds):
	- Keep `ui_reference.json` JSON-only (no binary assets); include `generated_at`.
	- Support `localizations` object with per-locale name/description fields.
	- Include `per_round_deltas` in missions array for scoring displays.
- Questions for user:
	- Glossary formatting preference: plain text vs styled RichText (bold/headers/lists)?
	- Any size limits for `ui_reference.json` or per-entry text length?

## Stage 1 Validation Checklist (Execution)
- DTO/data export alignment: `docs/architecture/architecture.md` and this plan contain frozen snapshot/event DTO tables; `ui_reference.json` regenerated from fixtures with version/generated_at, per-round deltas, and requirements (validated via `node tools/schema_validate.js`).
- Scene wiring: `stage01_slice.tscn` composes battlefield/action/dice/reference panels; `battlefield_view.tscn` renders board/units/reachability/logs and debug rays; `reference_panel.gd` imports RichText from `ui_reference.json`.
- Input map: `ui_input_map.gd` defines desktop bindings (LMB select/confirm, RMB/ESC cancel, A/1 Move, S/2 Attack, D/3 Melee, F/4 First Aid, H/0 Hold, R Reroll, Q Quick Start, Ctrl+Z UI undo, F9 Debug toggle). Touch/mobile deferred.
- Integration slice: `stage01_slice.gd` loads `docs/data-definition/fixtures/save_match.json`, previews via validator, runs demo hold command via `UISliceLoader`/`UICommandBus`; `ui_snapshot_smoke.gd` covers fixture→DTO→hold command flow.
- LoS/cover: `los_bbox_slice` (preferred) and `los_test_slice` prototypes; `battlefield_view.gd` renders `los.rays` when Debug View is enabled (checkbox/F9).
- Godot checks: `godot --headless --check-only --quit --path project` passing; editor_settings save warnings present (tolerated). Import pass (`godot --headless --editor --import --quit --path project`) pending if required for Stage 1 exit.
- Godot import: `godot --headless --editor --import --quit --path .` run; only warnings were editor_settings save and GodotTools socket bind (permission denied). Both tolerated for Stage 1; note for cleanup later.
- Acceptance gates: snapshot/event DTOs frozen with traceability; `ui_reference.json` regenerated and validated; scenes load without parse errors; desktop bindings wired; integration smoke executes hold path; LoS rays behind Debug View; headless check runs without fatal errors.
- Evidence: `tools/schema_validate.js` PASS; `godot --headless --check-only --quit --path project` PASS (with editor_settings warnings).
- Request: confirm tolerance for editor_settings warnings (and GodotTools socket warnings, if they appear) before Stage 1 sign-off.

## Ownership, Completion, and Stage 2 Prereqs
- Ownership (Stage 1 tasks):
	- DTO freeze: ARCH lead, REQ review.
	- Reference export: DATA ENG lead, REQ review.
	- UI scenes/input map: ARCH/ENG.
	- Integration slice & smoke: ARCH/ENG.
	- LoS/cover spike: ARCH/ENG.
	- Validation checklist: AUDITOR review, PLANNER coordination.
- Completed in Stage 1:
	- Snapshot/event DTOs frozen with GR/DA/CP/AQ/MP traceability and adapter notes.
	- `ui_reference.json` regenerated from fixtures; import spike implemented with styled RichText.
	- UI scaffolding + input map (desktop) wired; Debug View toggle (checkbox/F9) for rays.
	- Integration slice loads `save_match.json`, previews, executes demo hold via validator/resolver; smoke harness in place.
	- LoS/cover prototypes with preferred bounding-box raycast and `los.rays` debug overlay.
	- Headless check passes (editor_settings warnings tolerated).
- Remaining before Stage 2 entry:
	- Optional: run/import pass `godot --headless --editor --import --quit --path project` if you want it as a gate.
	- Address editor_settings/GodotTools warnings later (tolerated for Stage 1).
	- (Optional) Add keybinding for Debug View toggle if desired beyond F9/checkbox.
- Stage 2 prerequisites:
	- Stage 1 checklist accepted; DTOs remain frozen unless Stage 2 requires change control.
	- `ui_reference.json` remains current; rerun generator if rules/data change.
	- Fixture `save_match.json` stays canonical for smoke until replaced by Stage 2 fixtures.
	- Confirm whether import pass is required as a formal gate.
- Handoff check: please confirm readiness for Stage 2 and if the tolerated warnings (editor_settings, any GodotTools sockets) are acceptable for the handoff. Also confirm if the import pass should be run now or at Stage 2 start.
- Data export → Godot import spike (DATA ENG lead, ARCH support): Timebox validation of JSON import into Godot for glossary/reference panel; capture steps, blockers, and decisions; record resulting conventions in this file and `docs/data-definition/exports/README.md` if needed.
- LoS/cover visualization spike (ARCH lead, ENG support): Prototype line rendering + cover indicators driven by preview data; capture chosen approach, performance notes, and UI cues; record the scenario matrix in `project/src/ui/scenes/los_test_slice.gd`/`los_test_slice.tscn`, the Bresenham highlight overlays in `project/src/ui/scenes/battlefield_view.gd`, and the logging outcomes so Stage 2 can reuse the verified visualization.
	- Update: Added second LoS prototype using bounding boxes + raycast sampling (`project/src/ui/scenes/los_bbox_slice.gd`/`.tscn`) with multi-point rays and line overlays; performance and clarity favor this method—preferred implementation for Stage 2 unless new constraints emerge.
- Validation checklist (AUDITOR lead, ARCH/DATA support): Add checklist to this file to verify DTO/data export alignment to data dictionary and requirements, Godot scenes match contracts, and integration slice exercises command bus + resolver without errors.
- Documentation + handoff (PLANNER lead, AUDITOR review): Finalize plan updates, ensure task ownership marked (REQ/ARCH/DATA/AUDITOR/ENG/PLAYTEST), and note Stage 2 prerequisites and acceptance gates.

## Test Plan
- DTO contract lint (ARCH, REQ): DTO field lists traced to GR/DA/CP/AQ/MP; `docs/architecture/architecture.md` tables present and schema-check passes for snapshot/event DTOs.
- UI snapshot render sanity (ARCH, ENG): Load fixture → render board/units/mission scores without runtime errors; coordinates and cover/LoS flags match fixture expectations.
- Validator preview hook (ARCH): Unit selection returns reachable tiles/targets matching Stage 0 validator preview; terrain/cover surfaced; no crashes on invalid selections.
- Command execution slice (ARCH, ENG): Execute move + attack via command bus → ProductionResolver → state/log update; state hash increments and command log appends deterministically.
- Reference export check (DATA ENG): Generated `docs/data-definition/exports/ui_reference.json` matches data dictionary fields; schema validation script passes; glossary/reference panel loads file in Godot without parse errors.
- Input mapping check (ARCH, ENG): Pointer/keyboard bindings create correct Command DTOs; invalid targets rejected by validator with clear surfaced error message.
- Audit readiness checklist (AUDITOR): Stage 1 checklist completed; no missing coverage for UI contracts, data exports, integration slice, or acceptance gates before Stage 2 entry.

## Success Metrics & Acceptance Criteria
- Playable/executable slice: fixture match loads, units render, validator previews reachable/target tiles, and at least one command executes end-to-end updating state and log.
- UI contracts frozen: DTO definitions recorded and stable; UI scenes consume only those DTOs with requirement IDs noted.
- Reference data live: rules/reference panel reads generated JSON; schema validation succeeds.
- Input map proven: desktop pointer/keyboard bindings issue valid commands; invalid actions blocked with clear messaging.
- Stability: slice runs without errors in headless/headful Godot; deterministic hash/log updates remain intact (seed/offset unchanged unless commands are executed).
- Responsiveness: UI interactions (select, hover highlights, command preview) respond within 100 ms on desktop; initial battlefield load from fixture to first render ≤2 seconds on target hardware.
- Documentation: this plan updated with tasks, tests, and traceability; Stage 1 checklist ready for execution and handoff to Stage 2.

## Dependencies, Assumptions, Risks
- Dependencies: Stage 0 outputs (command DTOs, validator preview hooks, ProductionResolver, RNG/hash), fixtures under `docs/data-definition/fixtures/`, data dictionary + rules content, tech stack selections in `docs/architecture/tech-stack.md`.
- Assumptions: Desktop-first input focus for Stage 1; reference export kept in JSON; no new binary assets required beyond placeholders; seed handling unchanged from Stage 0.
- Risks: DTO/scene drift across docs vs Godot stubs (mitigate via checklist and schema lint); export/import pipeline churn (mitigate with spike + schema validation); performance of LoS rendering (mitigate with spike + simplified fallback); scope creep into Stage 2 rules (mitigate by freezing contracts early).

## Open Questions & Follow-Ups
- Do we need mobile/touch bindings in Stage 1 or defer to Stage 2? (REQ/ARCH)
- Which fixtures should be the canonical render sample for tests? (DATA/ARCH)
- Are glossary/reference panels required to support localization now or later? (REQ/DATA)
- Should command bus expose telemetry hooks during Stage 1 for audit/playtest logging? (AUDITOR/ENG)
- Ambiguities to resolve before locking Stage 1 scope:
- Confirm whether touch/mobile bindings must be included now or can remain desktop-only (CP-001–CP-004).
- Choose the canonical fixture for UI rendering and smoke harness (`docs/data-definition/fixtures/`).
- Decide if mission scoring deltas per round must be shown in the initial UI contract or deferred to Stage 2 (GR-033–GR-035.1, DA-009).
- Clarify glossary/reference formatting expectations (plain text vs styled RichText) and localization needs (DA-014, CP-004).
- Confirm whether telemetry/error events need additional fields in the event DTO during Stage 1 (DA-013, AQ-001).

## Reference Data Export Flow (UI Glossary/Reference Panel)
- Output target: `docs/data-definition/exports/ui_reference.json` (schema v1.0.0). Generator: `tools/build_ui_reference.js` (Node). Source docs: `docs/data-definition/data-dictionary.md` (factions, missions, optional rules, actions), `docs/rules.md` (action text, mission notes, scoring).
- Schema (per entry arrays include `requirements` for traceability):

| Field | Type | Notes | Source | Req IDs |
| --- | --- | --- | --- | --- |
| version | string | Export schema version | build script | AQ-002 |
| generated_at | string | ISO8601 timestamp | build script | AQ-002 |
| factions | array | `{id,name,stats{move,range,aq,defense},notes?,requirements[],localizations?}` | Data dictionary → FactionDefinition | GR-005–GR-011, DA-011, DA-014 |
| actions | array | `{id,name,description,requirements[],localizations?}` | Rules → Unit Actions | GR-017–GR-021, DA-012, DA-014 |
| missions | array | `{id,name,summary?,scoring?,per_round_deltas?,requirements[],localizations?}` | Data dictionary → MissionDefinition; rules for scoring text | GR-033–GR-035.1, DA-008–DA-009, DA-014 |
| optional_rules.commander_traits | array | `{id,name,effect?,requirements[],localizations?}` | Data dictionary → CommanderTrait | GR-041, DA-020, DA-014 |
| optional_rules.battle_events | array | `{id,name,effect?,requirements[],localizations?}` | Data dictionary → BattleEvent | GR-042, DA-019–DA-020, DA-014 |
| glossary | array | `{id, title, body, requirements[],localizations?}` (optional) | Rules/data dictionary derived | DA-014 |

- Fixtures and inputs: use `docs/data-definition/fixtures/` for canonical sample values (factions.json, missions.json, commander_traits.json, battle_events.json) when testing generator output.
- Generation steps (to document in `tools/build_ui_reference.js` header and README if added):
	1) Parse entities from data dictionary sections (FactionDefinition, MissionDefinition, CommanderTrait, BattleEvent) and rules action text.
	2) Map requirement IDs per entity; fallback to listed requirements if parsing fails.
	3) Emit JSON sorted by id; include `version` and `generated_at`; include `localizations` object when available (e.g., `{en:{name,description}, fr:{...}}`).
	4) For missions, include `per_round_deltas` array if scoring deltas per round are provided in rules/data.
	5) Run `node tools/build_ui_reference.js` → writes `docs/data-definition/exports/ui_reference.json`.
	6) (Optional) Validate shape using `tools/schema_validate.js` once schema is extended to cover `ui_reference.json`.
- Sync cadence: regenerate on any changes to rules, data dictionary, or fixtures; mandatory regen before Stage 1 exit and before Stage 2 starts.
- Open decisions:
	- Canonical fixture for UI rendering/smoke harness: `docs/data-definition/fixtures/save_match.json` (confirmed).
	- Localization fields: include `localizations` blocks now (confirmed).
	- Mission per-round scoring deltas: include `per_round_deltas` in `ui_reference.json` now (confirmed).

## Stage 1 Validation Checklist (Execution)
- UI scene wiring: `project/src/ui/scenes/stage01_slice.tscn` loads fixture snapshot, renders grid/units/log, and demo command executes without errors (ARCH/ENG).
- DTO/adapters: `ui_contracts.gd`, `ui_adapter.gd`, `ui_command_bus.gd`, `ui_slice_loader.gd` load without parse errors and map events/errors to UI DTOs (ARCH/ENG).
- Reference export: `docs/data-definition/exports/ui_reference.json` regenerates via `node tools/build_ui_reference.js`; `node tools/schema_validate.js` passes; `reference_panel.gd` reads file (DATA/ENG).
- Input map: `ui_input_map.gd` contains desktop bindings for select/move/attack/melee/first aid/hold/reroll/quick_start_move (ARCH/ENG).
- LoS visualization: `los_test_slice.tscn` cycles scenario permutations, `project/src/ui/scenes/los_test_slice.gd` logs Bresenham LoS results and cover status, and `battlefield_view.gd` renders the highlight/cover overlays for each case (ARCH/ENG).
- Integration slice: demo command path (hold) flows validator → resolver → UI update; RNG offsets remain stable; no crashes on missing data (ARCH/ENG).
- Godot validation: `godot --headless --editor --import --quit --path .` and `godot --headless --editor --check-only --quit --path .` succeed aside from known GodotTools socket/editor_settings warnings (ENG).

## Dependencies, Assumptions, Risks
- Dependencies: Stage 0 outputs (validator preview, seeded RNG/state hash, persistence fixtures, schema validation scripts, LoS/cover micro-bench plan), current requirements/architecture/data dictionary/tech stack.
- Assumptions: desktop-first verification; placeholder assets acceptable; no network access required for this stage.
- Risks: DTO/UI drift from data dictionary (mitigate via export-driven glossary and schema checks); LoS/cover preview performance (mitigate with spike and reuse micro-bench plan); command bus coupling to UI (mitigate via abstraction layer); placeholders obscuring clarity (mitigate with minimal consistent markers).

## Open Questions / Follow-ups
- Confirm final DTO field names for event stream and preview payloads; adjust data export to match.
- Decide whether to include mission scoring deltas per round in the initial UI contract or add in Stage 2 with full scoring.
