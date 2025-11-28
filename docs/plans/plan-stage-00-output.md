# Stage 0 Output Summary
- Stage: 00
- Version: 1.0.0
- Last Updated: 2025-11-28
- Owner/Agent: Developer

## Completed Deliverables
- Command DTOs and Validation
  - Command types (deploy, move, attack, melee, first_aid, hold, reroll, advantage_use, event_use, quick_start_move) documented with payload expectations.
  - Validator interface implemented (`validate(command, state, data_config) -> {ok, errors, preview}`) with rule-aware checks: bounds/home zones, movement adjacency and impassable terrain, half-move enforcement for attack/melee/first aid, range/LoS/cover heuristics, reroll availability, optional rule gates, Quick Start timing.
  - Resolver hooks scaffolded in replay harness; previews include reachable tiles, LoS/cover flags, and range cost.

- RNG Service and Determinism
  - Seeded RNG service (`roll_d6`, `roll_2d6`, `advance`, `snapshot/restore`, seed/offset getters) with offset tracking for persistence and replay.
  - Deterministic state hashing (canonical JSON + SHA-256) via `StateHasher` to align with current engine capabilities; fixtures carry matching hashes.

- Schema Alignment and Fixtures
  - Core fixtures for factions, missions, terrain, advantages, commander traits, battle events, optional rules config, match state, campaign state, RNG seed, commands, command log, and save payloads.
  - Schema validation script (`tools/schema_validate.js`) covers match/save/command logs and runs in CI; parity checklist stub (`tools/schema_parity_check.sh`) remains available for quick shape checks.

- Persistence & Replay
  - Persistence service stamps SHA-256 checksums on command logs and meta payloads, writes via temp+rename atomic flow, and verifies checksums on load.
  - Save match/campaign JSON examples including seed, command log, state hash, size meta, and checksum fields updated to SHA-256 prefixes.
  - Deterministic replay harness with expected hash checks; updated to compare `state_hash_after` per command using a production-oriented resolver that mutates state and advances RNG.
  - CI workflow runs the replay fixture, schema validation, and the headless test suite (including persistence round-trips) via `godot --headless --path project -s res://tests/test_runner.gd`.

- Tests
  - RNG unit tests (seed/offset consistency, snapshot/restore, advance offset).
  - Validator shape test.
  - Replay tests for determinism and offset mismatch detection with real state mutations.
  - Fixture replay test for Stage 0 save/log integrity.
  - Persistence save/load round-trip tests (checksum verification) and simulated partial write failure to confirm atomicity.
  - LoS/cover micro-benchmark runner using deterministic LoS/cover calculation for timing harness (production calculator pending).
  - Schema validation script (`tools/schema_validate.js`) runs in CI.

## Scope Check (Requirements/Architecture/Data/Tech Stack)
- Date: 2025-11-28 (pre-Stage-0 sign-off).
- Inputs reviewed: `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/data-definition/data-dictionary.md`, `docs/architecture/tech-stack.md`.
- Outcome: no blocking deltas or conflicts detected for Stage 0; checksum/atomic-write expectations and deterministic replay seams remain aligned across documents. Hashing choice is SHA-256 in Stage 0 outputs (architecture earlier suggested xxHash64; will revisit only if performance requires).

## Stage 0 Interfaces & Decisions
- RNG API: `roll_d6`, `roll_2d6`, `advance`, `snapshot/restore`, seed/offset getters; single service of record (see `project/src/services/rng_service.gd`).
- Hashing: canonical JSON + SHA-256 (`state_hash`, `checksum` prefixes `sha256:`) via `project/src/core/state_hasher.gd`.
- Persistence workflow: checksum stamp (command log + meta), temp+rename atomic save, checksum verification on load (`project/src/services/persistence_service.gd`); round-trip + partial-write tests in `project/tests/test_persistence.gd`.
- Replay harness/resolver: production-oriented resolver in `project/src/core/sample_resolver.gd` (class `ProductionResolver`) mutates state and advances RNG; harness compares `state_hash_after` per command and final hash (`project/src/core/replay_harness.gd`); fixture runner `project/tests/replay_fixture_runner.gd` plus regeneration tool `project/tools/regenerate_fixture_hashes.gd`.
- Schema validation: `tools/schema_validate.js` enforces required fields/prefixes for save/match/log/commands (CI step); `tools/schema_parity_check.sh` remains available for quick shape checks; fixtures refreshed in `docs/data-definition/fixtures/`.

## Audit-Readiness Checklist for Stage 2 Gate
- Replay determinism: CI runs `tools/run_replay_fixture.sh` and `res://tests/test_runner.gd`; fixtures in `docs/data-definition/fixtures/` kept in sync via `project/tools/regenerate_fixture_hashes.gd`.
- Persistence integrity: atomic save/load with checksum tests in `project/tests/test_persistence.gd`; workflow documented above.
- Data/schema alignment: schema validation in CI (`tools/schema_validate.js`) plus parity stub `tools/schema_parity_check.sh`; rerun after data dictionary updates.
- Hash/offset evidence: `state_hash_after` values and RNG offsets stored in fixtures (`docs/data-definition/fixtures/command_log.json`, `save_match.json`).
- Performance plan: LoS/cover benchmark template `project/tools/los_cover_benchmark.gd`; budget and scenarios recorded in this doc.

## LoS/Cover Micro-Benchmark Plan
- Device target: desktop (mid-tier CPU); future mobile pass optional.
- Budget: ≤500 ms per attacker/target computation path (LoS + cover) including cache lookups.
- Data sizes: 15×9 board; 5–10 terrain pieces; 10–20 units; up to 50 sampled attacker/target pairs per scenario.
- Scenarios:
  - Open field: no blocking terrain; baseline cache warm/cold runs.
  - Dense/urban: clustered blocking terrain across center columns; diagonal corner cases.
  - Elevation: elevated cells for attacker/target; mixed high/low cover.
  - Smoke/obscured: temporary obscurants toggled on/off to measure mask invalidation.
  - Unit-dense: 10 units per side to stress unit-blocking and cache keying.
- Template runner: `project/tools/los_cover_benchmark.gd` (invoke with `godot --headless --path project -s res://tools/los_cover_benchmark.gd`).
  - Inputs: inline scenario definitions with terrain density, sample pairs, and budget target.
  - Outputs: per-scenario timing summary and budget pass/fail; current implementation uses deterministic LoS/cover calculator for harness timing; swap in production calculator when ready.

## Risks / Gaps
- Resolver covers current fixture flows; full production state model/resolver still needed to cover the complete ruleset and regenerate hashes/events accordingly.
- Validator coverage remains partial (commander/event effects, mission scoring hooks not fully enforced).
- LoS/cover benchmark runner uses simplified calculator; production implementation and recorded timings are pending.
- Benchmarks for LoS/cover not yet executed with the production calculator; plan/template ready.

## Required Future Work
1) Implement full resolver/state updates to cover the complete ruleset and rerun hash generation so replay integrity reflects real game state changes.
2) Expand validator coverage to final rules (commander/event effects, mission scoring hooks) as state model and data mature.
3) Execute and record LoS/cover micro-benchmarks using the production calculator; document timings vs the ≤500 ms budget.
