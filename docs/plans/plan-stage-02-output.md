# Stage 2 Output Notes (in progress)
- Stage: 02 – Core Rules Engine & Validation Complete (Local)
- Version: 1.0.0
- Last Updated: 2025-12-12
- Owner/Agent: Developer / PLANNER

## Traceability & Coverage
- Added `docs/requirements/traceability-stage-02.md` mapping GR/DA/AQ/MP requirements to code/test evidence; optional rules default-off enforced in fixtures and validator gates.
- Current gaps: faction trait/advantage behavior (GR-005–GR-009) not yet directly tested; mission scoring/campaign totals to be covered in S2.8 with golden scenarios.

## Validator/Resolver Alignment
- Validator extended to gate campaign/events/advantage/quick_start when optional rules are off by default; attack requires target unit/cell; reroll requires actor/source; LoS/cover/range/half-move previews remain Stage 1 DTO-compatible.
- Resolver emits audit-lite events/logs with seed/offset/event_seq/timestamp/requirements; hashes synced into state.

## Data & Fixtures
- Optional rules config defaults set to false for campaign/events/commander. Schema/parity checks cover factions, missions, terrain, advantages, commander traits, battle events, optional rules, RNG seed, match_state variants, and UI export.
- Fixtures regenerated (`save_match`, `commands`, `command_log`, `match_state*`) with current resolver/hashes.

## Tests & Checks
- Deterministic replay/tests passing (`project/tests/test_runner.gd`), schema/parity checks passing (`tools/schema_validate.js`, `tools/schema_parity_check.sh`).

## LoS/Cover & Evidence
- Validator now uses raycast-style LoS (`_raycast_los`) with DTO-friendly `los` previews; micro-benchmark updated to exercise the ray path against terrain densities.
- Action logs/events carry seed/offset/event_seq/timestamp and hash evidence (hash_before/hash_after) through UI adapter; golden expectations refreshed.

## Stage Completion Summary
- Core resolver/validator: deterministic hashes/events/logs with requirement tags; mission/campaign scoring populated; optional rules default-off enforced.
- Data/fixtures: schemas validated/parity-checked; fixtures and goldens regenerated with hashes/evidence; optional_rules defaults false.
- LoS/Cover: raycast implementation is authoritative; benchmark (godot --headless --script project/tools/los_cover_benchmark.gd) results: open_field 1 ms, dense_urban 2 ms, elevation_mixed 2 ms, smoke_obscured 1 ms, unit_dense 2 ms (all ≤ 500 ms).
- Tests: `project/tests/test_runner.gd` PASS (12/12) unsandboxed; schema/parity checks PASS.
- Traceability: `docs/requirements/traceability-stage-02.md` updated with coverage; scoring/logging/optional-rule gates mapped.

## Stage 3 Audit Checklist (ready)
- All Stage 2 tests green: `godot --headless --path . --script res://project/tests/test_runner.gd`.
- Schema/parity: `node tools/schema_validate.js` and `bash tools/schema_parity_check.sh` PASS.
- Goldens current: `project/tests/golden/*` regenerated via `project/tools/update_golden.gd`; replay harness covers save_match + goldens.
- LoS/cover performance within budget (≤500 ms per scenario) confirmed by benchmark.
- Optional rules default-off enforced across validator/fixtures; DTO compatibility preserved (no schema breaks).
- Evidence fields present: events/logs carry seed/offset/event_seq/timestamp/requirements and hash_before/hash_after; fixtures include hashes.
