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

## Step-by-Step Implementation Plan (with Agent Mapping)
- Context reload & scope note (ARCH lead, REQ support): Re-read `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/architecture/tech-stack.md`, `docs/data-definition/data-dictionary.md`, `docs/plans/roadmap.md`, and `docs/plans/plan-stage-00-output.md`; restate Stage 1 scope/constraints in this file with GR/DA/CP/AQ/MP traceability.
- Freeze UI snapshot + event DTOs (ARCH lead, REQ review): Define render-facing DTOs for board grid, units, reachability/LoS/cover previews, activation/round status, mission/campaign scores, RNG/log events (dice rolls/results), and errors. Record full field lists and types in `docs/architecture/architecture.md`; mirror summary tables here with requirement IDs.
- Validator-preview + resolver alignment (ARCH lead): Map DTO fields to Stage 0 validator preview outputs and ProductionResolver responses; define minimal adapter stubs in `project/src/ui/` to translate engine data → UI DTOs; capture adapter contract notes here.
- Reference data export plan (DATA ENG lead, REQ review): Design generator flow to emit `docs/data-definition/exports/ui_reference.json` combining stats/actions/missions/optional rules from `docs/data-definition/data-dictionary.md` and `docs/rules.md`; specify schema, paths, and sync cadence; note any required fixtures in `docs/data-definition/fixtures/`.
- UI scene scaffolding (ARCH/tech-stack lead, ENG support): Outline Godot scenes/nodes under `project/src/ui/` for battlefield grid, unit tokens, action picker, dice/result panel, log viewer, and reference/glossary panel; list placeholder assets and signals; map each scene to DTOs and note autoload/singletons used.
- Input mapping (ARCH lead, ENG support, REQ review): Define desktop pointer/keyboard bindings to Command DTOs via command bus abstraction; list bindings (select, path preview, attack target, reroll, cancel); document in `docs/architecture/architecture.md` and summarize here.
- Integration slice assembly (ARCH lead, ENG support): Plan end-to-end flow: load fixture match from `docs/data-definition/fixtures/`, render via UI DTOs, invoke validator preview on selection, execute a command through ProductionResolver, update state/log view, and recompute hash; enumerate required stubs/mocks and file touchpoints.
- Data export → Godot import spike (DATA ENG lead, ARCH support): Timebox validation of JSON import into Godot for glossary/reference panel; capture steps, blockers, and decisions; record resulting conventions in this file and `docs/data-definition/exports/README.md` if needed.
- LoS/cover visualization spike (ARCH lead, ENG support): Prototype line rendering + cover indicators driven by preview data; capture chosen approach, performance notes, and UI cues; record the scenario matrix in `project/src/ui/scenes/los_test_slice.gd`/`los_test_slice.tscn`, the Bresenham highlight overlays in `project/src/ui/scenes/battlefield_view.gd`, and the logging outcomes so Stage 2 can reuse the verified visualization.
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
