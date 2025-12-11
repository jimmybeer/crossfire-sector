# Stage 1 Execution Prompts
- Use these prompts to drive Stage 1 tasks from `docs/plans/plan-stage-01.md`; ensure each response updates the cited docs/files and calls out acceptance evidence.

## Scope Reload & Traceability
- Prompt: “Re-read `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/architecture/tech-stack.md`, `docs/data-definition/data-dictionary.md`, `docs/plans/roadmap.md`, and `docs/plans/plan-stage-00-output.md`. Restate Stage 1 scope/constraints in `docs/plans/plan-stage-01.md` with GR/DA/CP/AQ/MP traceability. List any ambiguous requirements and ask the user to resolve them before proceeding.”

## Freeze UI Snapshot/Event DTOs
- Prompt: “Define and freeze UI snapshot/event DTOs for board, units, reachability/LoS/cover previews, activation/round status, mission/campaign scores, RNG/logs/errors. Record full field lists and types in `docs/architecture/architecture.md` and mirror summary tables in `docs/plans/plan-stage-01.md` with requirement IDs. Align DTO fields with validator preview + ProductionResolver outputs; add adapter notes in `project/src/ui/` stubs. Ask the user to confirm any uncertain field names or optional telemetry before freezing.”

## Reference Data Export Plan
- Prompt: “Design the generator flow for `docs/data-definition/exports/ui_reference.json` pulling from `docs/data-definition/data-dictionary.md` and `docs/rules.md`. Specify schema, paths, fixtures under `docs/data-definition/fixtures/`, and sync cadence; document steps in the plan. Confirm with the user which fixture should be canonical for UI rendering and whether localization or per-round scoring deltas are needed now.”

## UI Scaffolding & Input Map
- Prompt: “Outline Godot scenes/nodes under `project/src/ui/` for battlefield grid, unit tokens, action picker, dice/result panel, log viewer, and reference/glossary panel. List placeholder assets and signals; map each scene to the frozen DTOs; document in `docs/plans/plan-stage-01.md`. Define desktop pointer/keyboard bindings → Command DTOs and record them in `docs/architecture/architecture.md` with a summary in the plan. Ask the user to approve the control scheme or provide alternatives (e.g., touch/mobile deferral).”

## Integration Slice Assembly
- Prompt: “Plan the end-to-end slice: load fixture (`docs/data-definition/fixtures/`), render via UI DTOs, invoke validator preview on selection, execute a command through ProductionResolver, update state/log view, recompute hash. Enumerate required stubs/mocks and file touchpoints. Add a smoke harness plan for `project/tests/ui_snapshot_smoke.gd`. Ask the user to pick the fixture for the canonical demo path.”

## JSON Import Spike (Reference Panel)
- Prompt: “Timebox a JSON import spike for `docs/data-definition/exports/ui_reference.json` into Godot reference/glossary panel. Capture steps, blockers, and resulting conventions in `docs/plans/plan-stage-01.md` (and `docs/data-definition/exports/README.md` if needed). Ask the user about preferred formatting for glossary entries (plain text vs styled RichText) and any size limits.”

## LoS/Cover Visualization Spike
- Prompt: “Prototype line rendering + cover indicators driven by preview data. Compare Bresenham highlight overlays vs bounding-box raycast sampling (per `project/src/ui/scenes/los_test_slice.*` and `los_bbox_slice.*`). Record chosen approach, performance notes, and UI cues in `docs/plans/plan-stage-01.md`; note any updates needed in `battlefield_view` scenes/scripts. Ask the user to confirm the preferred visualization (e.g., rays, shaded tiles, icons).”

## Validation Checklist & Acceptance
- Prompt: “Fill the Stage 1 validation checklist in `docs/plans/plan-stage-01.md`: DTO/data export alignment, scene wiring, input map, integration slice, LoS/cover, Godot headless checks (`godot --headless --editor --import/check-only`). Mark acceptance gates and evidence. Ask the user to confirm any tolerated warnings (e.g., known GodotTools sockets) before sign-off.”

## Documentation & Handoff
- Prompt: “Document ownership for each Stage 1 task (REQ/ARCH/DATA/AUDITOR/ENG/PLAYTEST) and record Stage 2 prerequisites in `docs/plans/plan-stage-01.md`. Summarize what was completed, what remains, and any follow-ups required before Stage 2 entry. Ask the user to confirm handoff readiness and highlight any unresolved dependencies.”
