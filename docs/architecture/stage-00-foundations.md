# Stage 0 – Foundations & Architecture/Data Alignment Outputs
- Stage: 00
- Version: 1.0.0
- Last Updated: 2025-11-27
- Owner/Agent: Developer (per Stage 0 plan)
- Inputs: `docs/plans/plan-stage-00.md`, `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/data-definition/data-dictionary.md`, `docs/architecture/tech-stack.md`

## Command DTOs, Validation, and Resolver Hooks
- Command types: `deploy`, `move`, `attack`, `melee`, `first_aid`, `hold`, `reroll`, `advantage_use`, `event_use`, `quick_start_move`.
- DTO fields (aligns with `Command` in data dictionary):
  - `id` (string), `sequence` (int), `type` (enum above), `actor_unit_id` (string, nullable), `target_unit_id` (string, nullable), `payload` (object), `rng_offset_before` (int), `timestamp` (ISO8601, nullable), `version` (string).
  - Payload expectations per type:
    - `deploy`: `position {col,row}`, `unit_id`, `hidden` bool flag for UI concealment during alternating placement, `rows_used` tracker for row distribution.
    - `move`: `path` array of `{col,row}` with half-move flag (`half_move_used`) and `source_position`.
    - `attack`: `target_cell`, `move_path` (optional half-move), `los_trace` cache id, `range_used`, `cover_expected` bool, `reroll_available` bool.
    - `melee`: `target_cell`, `move_path` (adjacency), `reroll_available` bool.
    - `first_aid`: `target_unit_id`, `move_path` (adjacent), `half_move_used`.
    - `hold`: `reason` (text), `activation_id`.
    - `reroll`: `source` enum (`faction_trait`, `advantage`, `event`, `commander`), `roll_id`, `die_index`.
    - `advantage_use`: `advantage_id` (tactical_edge, quick_start, focused_orders), `context` (e.g., initiative, pre_round_move).
    - `event_use`: `event_id` (revive, etc.), `context`.
    - `quick_start_move`: `unit_ids` array of up to two, each with `path`.
- Validator contract:
  - `validate(command, state, data_config) -> {ok: bool, errors: [ValidationError], preview: Preview}`
  - `ValidationError`: `{code, message, field?, requirement_id?}`; tie `requirement_id` to GR/DA for traceability.
  - `Preview` contains per-command hints without mutating state:
    - `reachable_tiles` (for move/attack/first_aid), `valid_targets`, `los_lines`, `cover_state`, `range_cost`, `activation_budget_remaining`, `reroll_options`.
  - Validator responsibilities per type:
    - Deployment bounds/home zones (GR-012, DA-001), row distribution check, no visibility leak during alternating input.
    - Movement bounds/impassable/diagonal corner blocking with pass-through allowance but no end-on-occupied (GR-018, GR-032, GR-032.1).
    - Attack half-move allowance and adjacency for melee (GR-019, GR-027), LoS/corner checks, range enforcement, cover calculation (GR-031, GR-021.1, GR-004, DA-005).
    - First Aid adjacency and down-state gating (GR-020, GR-029–GR-030, DA-007).
    - Activation limits (GR-015–GR-017, DA-003) and round cap (GR-043–GR-044).
    - Reroll single-use enforcement with die selection (GR-045, DA-018), Quick Start no-attack restriction (DA-017), Winner’s Advantage selection (GR-040).
    - Optional commander/event toggles (GR-041–GR-042, DA-010, DA-019–DA-020).
- Resolver hooks (pure functions per type, consume validated commands):
  - `resolve_deploy`, `resolve_move`, `resolve_attack`, `resolve_melee`, `resolve_first_aid`, `resolve_hold`, `resolve_reroll`, `resolve_advantage_use`, `resolve_event_use`, `resolve_quick_start_move`.
  - Each resolver consumes `RngService` for rolls, emits `Event` stream entries (`dice_roll`, `hit`, `down`, `destroyed`, `initiative_result`, `mission_score_change`, `revive_used`, etc.) and returns updated immutable `MatchState`.
  - Resolver must write `rng_offset_after` implicitly via service offset and append command to `CommandLog` with `rng_offset_before` captured.

## RNG Service Design
- API surface (centralised, deterministic):
  - `init(seed: string|int, offset: int = 0) -> RngService`
  - `roll_d6() -> {total:int, rolls:[int], offset:int}`
  - `roll_2d6() -> {total:int, rolls:[int], offset:int}`
  - `advance(steps:int) -> offset` (skips ahead without returning rolls).
  - `snapshot() -> {seed, offset}`; `restore(snapshot)` resets service.
  - `get_offset() -> int`; `get_seed() -> seed`.
- Storage: `{seed, offset, last_roll?}` persisted in `MatchState.rng` and `CampaignState.rng` matching `RNGSeed` schema. Offset increments per die rolled to support replay and integrity checks.
- Determinism rules:
  - All randomness (terrain placement counts/locations, initiative, moves for Solar Wardens, attacks, melee, events, mission selection, campaign length) must call this service exclusively.
  - Snapshot on save, restore on load before processing next command; command log stores `rng_offset_before` for replay assertions.
- Test focus (unit):
  - Same seed/offset → identical roll outputs; `advance` changes offset without returning dice; `snapshot/restore` round-trips; offset increments match dice count (1 for `roll_d6`, 2 for `roll_2d6`).

## Persistence JSON Layout
- Match save payload (≤256 KB target; gzip if >256 KB, store flag):
```json
{
  "match": {
    "id": "match_01",
    "board_layout_id": "standard_15x9",
    "terrain": [...],
    "mission_id": "control_center",
    "optional_rules": {"commander": false, "events": false, "campaign": true},
    "battle_event_id": null,
    "player_states": [...],
    "unit_states": [...],
    "round_state": {...},
    "rng": {"seed": "seed_match_01", "offset": 42, "version": "1.0.0"},
    "command_log": {"id": "log_match_01", "entries": [...], "checksum": "xxhash64:...", "version": "1.0.0"},
    "state_hash": "xxhash64:...",
    "version": "1.0.0"
  },
  "meta": {
    "created_at": "2025-11-27T12:00:00Z",
    "updated_at": "2025-11-27T12:05:00Z",
    "checksum": "xxhash64:...",
    "compressed": false
  }
}
```
- Campaign save payload (≤512 KB target; gzip if >512 KB, flag in meta) mirrors `CampaignState` plus linked current `match_id`.
- State hash: xxHash64 over canonicalised `MatchState` (excluding meta, checksums, timestamps) to detect drift; recompute after each resolver step and before persistence flush.
- Atomic write protocol:
  - Write JSON to temp file in same directory (`<path>.tmp`), flush (`FileAccess.flush()`), fsync when available, then `rename`/`move_replace` to final path.
  - Verify checksum of written file (xxHash64) matches calculated value; if mismatch, keep temp and surface error.
  - Keep `size_bytes` meta to enforce budgets before writing; warn and compress when approaching thresholds.

## Deterministic Replay Harness
- Purpose: prove identical seeds + command list reproduce identical state hashes and event streams (AQ-003, MP-005).
- Flow:
  - Load save payload: extract `rng.seed`, `rng.offset`, `command_log.entries`, initial `MatchState`.
  - For each command in order: assert `rng_offset_before` matches service offset; run `validate`; run resolver; capture emitted events; recompute state hash with xxHash64; compare to stored hash/log expectation.
  - On completion: compare final state hash and event digest to baseline; surface mismatch with offending command id.
- Integration test scenario:
  - Synthetic match with known terrain/mission; execute scripted sequence covering deploy → move → attack (with cover) → melee → first aid → reroll → advantage/event usage; assert hash parity on replay with same seed.
  - Negative test: mutate a command in log and assert harness detects hash divergence.

## LoS/Cover Micro-Benchmark Plan
- Goals: desktop-first budget ≤500 ms per computation path (LoS/cover per attacker/target pair) before optimizations; inform later perf work.
- Scenarios:
  - Open field 15×9 (baseline).
  - Dense center (5 terrain pieces blocking LoS across center columns 7–9).
  - Edge clutter (terrain near home zones to stress diagonal corner rules).
  - Unit-dense (10 units per side) to measure unit-blocking impact.
- Metrics:
  - Time per LoS call (Bresenham/DDA with corner check), cache hit vs miss ratio.
  - Cover computation time (visibility/obscured area heuristic), percent coverage flagged.
  - Memory footprint of cached masks keyed by attacker position/state hash.
- Device targets: desktop baseline (mid-tier CPU), note expected uplift for mobile later; capture Godot profiler script path and commands when implemented.
- Output: record mean/median/p95 for each scenario; fail budget if any path exceeds 500 ms on desktop baseline; store results in future `perf/los_cover/*.md`.

## Documentation, Traceability, and Audit Prep
- Traceability:
  - Tie validator errors to GR/DA IDs; keep command DTO payload fields referenced in data dictionary.
  - State hash + command log stored with versions to aid migrations.
- Test coverage commitments (to be implemented as code arrives):
  - Unit: RNG seed/offset, command DTO validation shape tests (deploy bounds, move/attack half-move, LoS/cover legality, reroll cap).
  - Integration: deterministic replay harness hash comparison; persistence round-trip with checksum/atomic write simulation.
  - Schema validation: leverage parity checklist/script stub (`tools/schema_parity_check.sh`) against data dictionary definitions.
  - Persistence integrity: simulate save/load with temp+rename; verify xxHash64 hash round-trips and gzip flag handling.
  - Benchmark plan: record runs only; no execution until assets/logic exist.
- Audit-prep checklist for post-Stage-2 gate:
  - Ensure replay harness part of CI; attach sample seed/log pair.
  - Keep schema parity checklist updated when data dictionary changes.
  - Confirm save size budgets enforced in tests; gzip threshold documented.
  - Provide validator coverage map to GR/DA IDs; include reroll/advantage/optional rule toggles.
