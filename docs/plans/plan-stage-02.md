# Stage 2 – Core Rules Engine & Validation Complete (Local)
- Stage ID: 02
- Version: 1.0.0
- Last Updated: 2025-12-12
- Author/Agent: Planning & Roadmap Agent ([PLANNER])

## Context & Goals
- Purpose: deliver full validator/resolver coverage for the Crossfire Sector ruleset with campaign/optional toggles default-off, producing deterministic, traceable outcomes ready for Stage 3 gameplay loop integration.
- Dependencies: Stage 0 determinism/persistence/resolver scaffolds and schema validation; Stage 1 frozen UI snapshot/event DTOs, reference feed, and input contracts confirmed in `docs/plans/plan-stage-01-output.md`.
- Scope emphasis (traceability): GR-001–GR-045 core rules, DA-001–DA-021 data alignment, AQ-001–AQ-006 determinism/quality gates, MP-003–MP-005 logging/replay. Optional rules (commander/events/campaign advantages) remain gated and off by default.
- Constraints: preserve Stage 1 DTO contracts; avoid UI contract churn; no multiplayer; keep seeded RNG/hash pipeline intact; desktop-focused verification.

## Artefacts & Touchpoints
- Engine/state: `project/src/core/sample_resolver.gd` (ProductionResolver), `project/src/validation/command_validator.gd`, `project/src/core/replay_harness.gd`, `project/src/services/rng_service.gd`, `project/src/core/state_hasher.gd`.
- Data: `docs/data-definition/fixtures/*.json`, `docs/data-definition/exports/ui_reference.json`, `tools/schema_validate.js`, `tools/schema_parity_check.sh`.
- Tests/benchmarks: `project/tests/test_runner.gd`, `project/tests/replay_fixture_runner.gd`, `project/tools/regenerate_fixture_hashes.gd`, `project/tools/los_cover_benchmark.gd`, golden test assets under `project/tests/golden/` (to add).
- Docs/outputs: this plan, `docs/plans/plan-stage-02-output.md` (to produce), `docs/plans/plan-stage-02-goals.md`, traceability matrix file (to add, e.g., `docs/requirements/traceability-stage-02.md`), updates to `docs/architecture/architecture.md` only via ARCH agent if contract notes need addenda.

## Step-by-Step Implementation Plan (with Agent Mapping)
- **S2.1 Context reload & scope confirmation (ARCH lead; REQ/AUDITOR support):** Re-read requirements, architecture, data dictionary, tech stack, roadmap, and Stage 0/1 outputs; restate Stage 2 scope, frozen DTOs, and toggles policy; log any deltas requiring upstream agent involvement.
- **S2.2 State model and resolver completion (ARCH/ENG lead; REQ support):** Finalize production state model (units, statuses, terrain effects, mission/campaign fields, RNG/hash tracking) and implement resolver paths for move/attack/melee/first_aid/hold/reroll/advantage_use/event_use/quick_start_move; enforce default-off optional rules; emit structured events/logs per Stage 1 DTOs.
- **S2.3 Validator coverage finish (ARCH lead; REQ/AUDITOR review):** Extend validator to cover full legality (bounds, adjacency, half-move, LoS/cover per DA-005/DA-021, reroll gates, optional rule flags, mission preconditions); normalize error codes/messages with requirement IDs; keep preview payloads aligned to frozen DTOs.
- **S2.4 Data loaders and schema enforcement (DATA ENG lead; ARCH/REQ review):** Implement/complete loaders for factions, missions (with per-round scoring), terrain, commander traits, battle events, optional rules; refresh `tools/schema_validate.js` and parity checks; regenerate fixtures and `ui_reference.json` from data dictionary and rules.
- **S2.5 UI contract alignment and adapters (ARCH/ENG lead):** Ensure resolver/validator outputs map cleanly to Stage 1 UI contracts (`UIAdapter`, snapshot/event DTOs); add adapter shims if new engine fields are needed without breaking frozen UI schema; document any required contract change requests for future stages.
- **S2.6 Traceability matrix and coverage (REQ lead; AUDITOR support):** Build GR/DA/AQ/MP-to-code/test traceability matrix for Stage 2 (file to add under docs/requirements); mark coverage status per command/rule and per test; highlight gaps requiring follow-up.
- **S2.7 Golden deterministic scenarios (ENG lead; AUDITOR support):** Create golden test suites with fixed seeds covering command sequences, optional rule toggles (off/on when allowed), mission scoring cases, and error paths; wire into replay harness with expected hashes/events/logs.
- **S2.8 Mission scoring and campaign toggles (ENG/REQ lead):** Implement mission scoring calculators and campaign total/advantage handling; verify toggles default-off but can be enabled via data/config; ensure scoring events/logs carry requirement tags and hash updates.
- **S2.9 Action log and determinism evidence (ENG lead; AUDITOR review):** Standardize action/dice logs to include RNG seed/offset, roll details, requirement tags, and hashes; ensure persistence writes checksums; update fixtures and snapshot/event logs to carry evidence fields.
- **S2.10 LoS/Cover production calculator and micro-bench (ARCH/ENG lead):** Replace prototype with production LoS/cover calculator; run `project/tools/los_cover_benchmark.gd` across scenarios and record timings against ≤500 ms budget; cache or optimize as needed without breaking determinism.
- **S2.11 Audit prep and stage closure (AUDITOR lead; ARCH/REQ/DATA support):** Compile execution evidence (test reports, traceability matrix, micro-bench results, schema validation results, updated fixtures), update `plan-stage-02-output.md`, and prepare checklist for Stage 3 entry audit gate.

## S2.1 Context Notes (2025-12-12)
- Sources refreshed: `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/architecture/tech-stack.md`, `docs/data-definition/data-dictionary.md`, `docs/plans/roadmap.md`, `docs/plans/plan-stage-00-output.md`, `docs/plans/plan-stage-01-output.md`, and this plan.
- Contracts locked: UI snapshot/event DTOs remain frozen; only additive, backward-compatible fields allowed with ARCH/REQ approval. Audit-lite telemetry fields (`source`, `command_id`, `player_id`, `latency_ms`) enabled by default for Stage 2 fixtures/tests. Optional rules stay default-off.
- Fixtures/seeds: Coverage trio fixed (`crossfire_clash`, `dead_zone`, `occupy`) with hashed layouts and occupy save baseline; `low_cover` + `blocking_rock` templates in use. Commander trait `inspire` and event `smoke_screen` available for limited optional-rule tests.
- Follow-ups detected: none new for S2.1; proceed to S2.2+ with current constraints.

## Test Plan
- Unit/logic (ENG/ARCH): Resolver rule cases, validator legality checks, mission scoring functions, LoS/cover calculator edge cases.
- Integration/replay (ENG/AUDITOR): Replay harness with golden seeds and expected hashes/events/logs; regression on persistence round-trips with checksum verification.
- Schema/data (DATA ENG): `tools/schema_validate.js` and parity scripts on fixtures/exports; loader round-trips (load → hash → save).
- Determinism (ARCH/ENG): Seed/offset invariance across runs; hash stability before/after commands; RNG snapshot/restore during resolver paths.
- Performance (ARCH/ENG): LoS/cover micro-bench across scenarios against ≤500 ms budget; monitor allocations to keep deterministic outputs.
- Audit/readiness (AUDITOR/REQ): Traceability matrix completeness; requirement coverage spot checks; Stage 2 checklist completion; UI contract compatibility checks.

## Success Metrics & Acceptance Criteria
- 100% GR-001–GR-045, DA-001–DA-021 coverage mapped in traceability matrix with passing tests where applicable; gaps explicitly tracked.
- Golden test suite passes with deterministic hashes/logs identical across runs and environments (seed/offset evidence present).
- Validator blocks illegal commands and surfaces requirement-tagged errors; previews align to resolver outcomes and Stage 1 DTO schema.
- Mission scoring and campaign totals match rules/data across scenarios; toggles default-off unless explicitly enabled.
- LoS/cover micro-bench meets ≤500 ms per scenario target with production calculator; no determinism drift introduced.
- Action log/event stream contains dice/RNG offsets and requirement tags; persistence writes maintain checksum/hash integrity.
- All schema validations and parity checks pass; fixtures and exports regenerated without shape drift.

## Dependencies, Assumptions, Risks
- Dependencies: Stage 0 determinism/persistence scaffolds and schema tools; Stage 1 frozen UI contracts/reference feed/input map; current data dictionary and rules content.
- Assumptions: Optional rules remain off by default; UI schema stays frozen through Stage 2; no new asset-heavy features affecting performance; desktop execution environment for tests/benchmarks.
- Risks: Contract drift vs Stage 1 UI DTOs (mitigate via S2.5 adapters/change-control); LoS/cover perf shortfall (mitigate via benchmarking and caching); data drift between fixtures and dictionary (mitigate via regeneration and schema checks); scope creep into UI/UX (mitigate by enforcing Stage 2 boundary).

## Open Questions & Follow-Up
- Are any Stage 1 DTO adjustments permitted if resolver outputs require minor fields, or must all changes be deferred to Stage 3? Decision: allow additive, backward-compatible fields only (optional/nullable, no renames/removals) with explicit ARCH/REQ approval and traceability notes; prefer shims/adapters first to avoid contract churn.
- Which missions/terrain sets should seed the Stage 2 golden scenarios and scoring tests? Decision: use a coverage trio—(1) open/control mission on sparse terrain (`crossfire_clash`), (2) cover/LoS-heavy mission on dense terrain (`dead_zone`), (3) campaign-flavored mission with per-round deltas/advantages (`occupy`, toggles default-off). Prefer reusing/extending existing fixtures (e.g., `save_match.json` variants) for hash stability.
- Should campaign advantages/events be tested in Stage 2 with limited fixtures or deferred until Stage 3 gameplay loop? Decision: include limited fixtures and deterministic tests now with toggles default-off; cover gating in validator/resolver and add goldens for both disabled and explicitly enabled paths without changing the UI loop.
- Confirm whether additional telemetry fields are needed in logs/events for audit readiness beyond seed/offset/hash (AUDITOR to advise). Decision: adopt audit-lite optional fields—`source` (validator/resolver), `command_id`, `player_id`, `latency_ms`—kept optional/nullable and enabled by default in Stage 2 fixtures/tests; retain seed/offset/hash, event_seq, timestamps, and requirement tags as mandatory for determinism/audit.
