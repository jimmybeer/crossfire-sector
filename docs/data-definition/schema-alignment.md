# Stage 0 Schema Alignment & Parity Checklist
- Version: 1.0.0
- Last Updated: 2025-11-27
- Inputs: `docs/data-definition/data-dictionary.md`, `docs/requirements/requirements.md`, `docs/architecture/architecture.md`
- Purpose: lock schema expectations for core entities and provide a reusable parity checklist/script stub for future validation.

## Entity Alignment Notes
- FactionDefinition
  - Fields: `id`, `name`, `roster_limit` (Solar 4), `base_stats{move,range,aq,defense}`, `movement_mode` (`fixed`|`roll_per_move`), `traits[]`, `version`.
  - Requirements trace: GR-005–GR-011 (factions/stats), GR-008–GR-011 traits, DA-011 reroll/application.
  - Parity check: ensure trait ids match resolver hooks (`azure_melee_aq_bonus`, `grey_reroll`, `solar_deadly_rounds`, `random_move`); roster limit enforced in PlayerState validator.
- MissionDefinition
  - Fields: `id`, `name`, `mission_type` enum (six missions), `control_zones[]`, `scoring_rules{timing,points,bonuses}`, `round_limit` 6, `max_extra_rounds` 1, `unique_per_campaign` true, `notes`, `version`.
  - Requirements trace: GR-033–GR-035.1, GR-039 (uniqueness), DA-008–DA-009, DA-015–DA-017.
  - Parity check: Occupy bonuses (sector B +1, nearest opponent +3) encoded; round cap fixed at 7 via `max_extra_rounds:1`.
- TerrainTemplate
  - Fields: `id`, `name`, `size_range{min,max}`, `blocks_los`, `provides_cover`, `impassable`, `placement_weight`, `flags{}`, `version`.
  - Requirements trace: GR-002–GR-004, GR-018, GR-031, DA-004–DA-005, DA-021.
  - Parity check: defaults true for LoS blocking, cover, and impassable; diagonal corner blocking handled in validator logic, not schema.
- Optional Rules & Toggles
  - AdvantageOption (`id`, `name`, `effect`, `usage_timing`, `limits`, `version`) → GR-040, DA-017, DA-018, DA-019.
  - CommanderTrait (`id`, `name`, `effect`, `version`) → GR-041, DA-020.
  - BattleEvent (`id`, `name`, `effect`, `trigger`, `version`) → GR-042, DA-019–DA-020.
  - OptionalRulesConfig (`commander`, `events`, `campaign`, `version`) → AQ-006; ensure MatchState and PlayerState embed same flags.
- MatchState
  - Fields: `id`, `board_layout_id`, `terrain[]` instances, `mission_id`, `optional_rules`, `battle_event_id`, `player_states[]`, `unit_states[]`, `round_state`, `rng`, `command_log_id`, `status`, `version`.
  - Requirements trace: GR-001–GR-045, DA-001–DA-021, CP-005–CP-007, MP-001–MP-006.
  - Parity check: `round_state.extra_rounds_remaining` <=1; `unit_states` include `has_moved_this_activation` and `rerolls_available`; `status` enum stays `active|completed`.
- CampaignState
  - Fields: `id`, `length` (3–5), `current_battle`, `missions_used[]`, `cumulative_scores{P1,P2}`, `advantages_history[]`, `current_match_id`, `rng`, `version`.
  - Requirements trace: GR-036–GR-040, DA-009, DA-015–DA-017.
  - Parity check: enforce unique missions list matches MissionDefinition ids; Winner’s Advantage per battle recorded once.
- RNGSeed
  - Fields: `seed`, `offset`, `last_roll` (nullable), `version`.
  - Requirements trace: AQ-004, MP-005, DA-006 logging needs.
  - Parity check: `offset` integer monotonic; include in MatchState/CampaignState.
- Command
  - Fields: `id`, `sequence`, `type` enum (deploy, move, attack, melee, first_aid, hold, reroll, advantage_use, event_use, quick_start_move), `actor_unit_id`, `target_unit_id`, `payload`, `rng_offset_before`, `timestamp`, `version`.
  - Requirements trace: GR-012–GR-032.1, GR-040–GR-045, DA-001–DA-021, MP-001–MP-005.
  - Parity check: payload keys per type captured in `docs/architecture/stage-00-foundations.md`; ensure enums stay in sync with validator/resolver tables.
- CommandLog
  - Fields: `id`, `entries[]` (Command), `checksum` (xxHash64), `version`.
  - Requirements trace: DA-013 logging, MP-001–MP-006 replay, CP-005 persistence.
  - Parity check: entries sorted by `sequence`; checksum recomputed on save; `rng_offset_before` preserved per entry.

## Schema Parity Checklist
- When data dictionary updates:
  - [ ] Reconfirm enums and field names for core entities above; update DTO payload expectations where needed.
  - [ ] Regenerate schema fixtures or JSON samples for factions, missions, terrain, optional rules, MatchState, CampaignState, RNGSeed, Command, CommandLog.
  - [ ] Run `tools/schema_parity_check.sh` against JSON fixtures and data dictionary to catch drift.
  - [ ] Update version fields per entity and note migration guidance in data dictionary if breaking.
  - [ ] Rerun deterministic replay harness using latest schemas to ensure hashes remain stable or migrated.
- When adding new optional systems:
  - [ ] Add new schemas additively; avoid mutating existing enums unless accompanied by migration mapping.
  - [ ] Extend validator/resolver hooks and DTO payload docs; keep parity checklist coverage current.

## Script Stub
- Script path: `tools/schema_parity_check.sh`
- Intent: automate parity checks by loading JSON fixtures for core entities, validating presence/shape of required fields, enums, and version expectations against `docs/data-definition/data-dictionary.md`.
- Current status: stub only; populate with JSON validation once fixtures and runtime schema tooling are added in Stage 1–2.
