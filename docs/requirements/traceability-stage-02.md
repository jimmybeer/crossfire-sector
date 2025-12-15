# Stage 2 Traceability Matrix
- Stage: 02 – Core Rules Engine & Validation Complete (Local)
- Version: 1.0.0
- Last Updated: 2025-12-12
- Author/Agent: Data Definition & Traceability ([DATA ENG])

| Requirement ID | Code/Assets | Tests | Status | Notes |
| --- | --- | --- | --- | --- |
| GR-001, GR-002, GR-002.1, GR-003, GR-004 | tools/schema_parity_check.sh; docs/data-definition/fixtures/terrain_templates.json; project/src/validation/command_validator.gd (path/impassable/cover checks) | project/tests/test_replay_and_validation.gd (validator shape/gates); tools/schema_validate.js | Covered | Board size default 15x9; terrain templates enforce bounds/impassable/cover; LoS/cover flags present. |
| GR-005–GR-009 | docs/data-definition/fixtures/factions.json; tools/schema_parity_check.sh; tools/schema_validate.js | (data-only; no explicit test) | Partial | Faction stats/schema validated; gameplay trait application deferred to resolver/validator trait support. |
| GR-010 | project/src/core/sample_resolver.gd (hold event/log) | project/tests/test_replay_and_validation.gd (replay_determinism) | Covered | Hold resolves with event_seq/timestamp/hash evidence. |
| GR-012 | project/src/validation/command_validator.gd (_validate_deploy) | project/tests/test_replay_and_validation.gd (validator_shape_move covers deploy path indirectly) | Covered | Deploy checks actor, position, bounds, home zone. |
| GR-017, GR-018 | project/src/validation/command_validator.gd (_validate_move) | project/tests/test_replay_and_validation.gd (validator_shape_move) | Covered | Move allowance, path adjacency, bounds, occupied destination checks. |
| GR-019, GR-031 | project/src/validation/command_validator.gd (_validate_attack) | project/tests/test_replay_and_validation.gd (validator_attack_requires_target_unit) | Covered | Attack requires actor/target unit/cell, half-move, range, LoS/cover preview. |
| GR-020 | project/src/validation/command_validator.gd (_validate_first_aid) | project/tests/test_replay_and_validation.gd (suite) | Covered | First Aid requires target unit, adjacency after half-move. |
| GR-022 | project/src/core/sample_resolver.gd (_apply_attack) | project/tests/test_replay_and_validation.gd (resolver_event_metadata) | Covered | Resolver computes attack totals with AQ/cover/defense; logs events with requirements. |
| GR-027 | project/src/validation/command_validator.gd (_validate_melee) | project/tests/test_replay_and_validation.gd (suite) | Covered | Melee adjacency after half-move enforced. |
| GR-032.1 | project/src/validation/command_validator.gd (_validate_move end-cell) | project/tests/test_replay_and_validation.gd (suite) | Covered | Occupied destination blocked. |
| GR-040 | project/src/validation/command_validator.gd (_gates advantage) | project/tests/test_replay_and_validation.gd (validator_optional_rules_default_off) | Covered | Advantages gated by campaign flag (default-off). |
| GR-042 | project/src/validation/command_validator.gd (_validate_event) | project/tests/test_replay_and_validation.gd (validator_optional_rules_default_off) | Covered | Events gated by events flag (default-off) and require id. |
| GR-045 | project/src/validation/command_validator.gd (_validate_reroll) | project/tests/test_replay_and_validation.gd (suite) | Covered | Reroll requires source, availability, actor. |
| DA-004, DA-006, DA-012 | project/src/validation/command_validator.gd (move/attack/melee LoS/cover) | project/tests/test_replay_and_validation.gd (suite) | Covered | Reachability/LoS/cover previews emitted. |
| DA-017 | project/src/validation/command_validator.gd (_validate_quick_start) | project/tests/test_replay_and_validation.gd (suite) | Covered | Quick start requires unit_ids, round 1, campaign gating. |
| DA-018 | project/src/validation/command_validator.gd (_validate_reroll) | project/tests/test_replay_and_validation.gd (suite) | Covered | Reroll source and availability enforced. |
| DA-021 | project/src/validation/command_validator.gd (LoS/cover helpers) | project/tests/test_replay_and_validation.gd (suite) | Covered | Bresenham LoS and cover heuristic active. |
| AQ-003, AQ-004, MP-003, MP-005 | project/src/core/replay_harness.gd; project/src/core/state_hasher.gd; project/src/services/rng_service.gd | project/tests/test_replay_and_validation.gd (replay_determinism/offset mismatch); project/tests/test_rng.gd | Covered | Deterministic seed/offset, state hashing, replay verification. |
| AQ-007 | project/src/validation/command_validator.gd | project/tests/test_replay_and_validation.gd | Covered | Validation runs before resolution; errors carry requirement codes. |
| Data parity & schema | tools/schema_validate.js; tools/schema_parity_check.sh; docs/data-definition/fixtures/*.json | node tools/schema_validate.js; bash tools/schema_parity_check.sh | Covered | Fixtures validated for shape/defaults; optional rules default-off enforced. |

Open gaps / follow-ups
- GR-005–GR-009 traits/advantages application not directly tested; relies on data schema only. Consider targeted resolver/validator tests for faction traits and advantages in Stage 3.
- Mission scoring and campaign totals (GR/DA overlap) to be exercised more deeply in Stage 2 mission-scoring work (S2.8) with golden scenarios.

Notes
- Optional rules default-off enforced across fixtures and validator gates (campaign/events/commander).
- Events/logs carry audit-lite evidence (seed/offset/event_seq/timestamp/requirements). Hashes present in resolver state for determinism.***
