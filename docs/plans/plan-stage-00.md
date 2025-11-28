# Stage 0 – Foundations & Architecture/Data Alignment
- Stage ID: 00
- Version: 1.0.0
- Last Updated: 2025-11-27
- Author/Agent: Planning & Roadmap Agent ([PLANNER])

## Context & Goals
- Establish deterministic core seams, schema alignment, and persistence integrity to de-risk all downstream stages.
- Align command DTOs, validator/resolver scaffolding, RNG service, and save/load format with `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/data-definition/data-dictionary.md`, and `docs/architecture/tech-stack.md`.
- Produce perf micro-bench plan for LoS/cover before heavy assets.
- Exit criteria (from roadmap): deterministic replay proof (identical seeds → identical outcomes); schema validation passes against data dictionary; save/load integrity (checksum + atomic writes) verified; perf micro-bench plan drafted with target budgets.

## Step-by-Step Implementation Plan (with Agent Mapping)
1) Scope check and inputs load (ARCH, REQ, DATA ENG)
   - Read requirements, architecture, data dictionary, tech stack, and latest audit to confirm no deltas.
2) Define command DTOs and validation interfaces (ARCH, REQ)
   - Draft `Command` types and payload shapes covering deploy/move/attack/melee/first_aid/hold/reroll/advantage/event/quick_start per requirements.
   - Define validator interface (`validate(command, state, data_config) -> result{ok, errors, preview}`) and resolver hooks.
3) Align schemas with data dictionary (DATA ENG, ARCH)
   - Generate/validate schema definitions for factions, missions, terrain, optional rules, match/campaign state, RNGSeed, Command, CommandLog against `docs/data-definition/data-dictionary.md`.
   - Create a schema parity checklist/script stub to re-run in later stages.
4) RNG service design (ARCH)
   - Specify seeded RNG API (`roll_d6`, `roll_2d6`, `advance`, `snapshot/restore`) and seed/offset storage aligned to persistence format.
5) Persistence format & integrity (ARCH)
   - Define save/load JSON layout for match/campaign, including seed, command log, state hash/checksum, atomic write protocol (temp + rename).
   - Choose state-hash algorithm: use xxHash64 for fast, deterministic hashing of state snapshots; pair with checksum for file integrity.
   - Set target size budgets per architecture guidance (≤256 KB match, ≤512 KB campaign) and note gzip threshold.
6) Deterministic replay harness (ARCH, ENGINEERING)
   - Build a minimal harness to load a seed + command list and assert identical outcomes (state hash/events) on replays.
7) Performance micro-bench plan for LoS/cover (ARCH)
   - Define benchmark scenarios, device targets (desktop first), and budget thresholds for LoS/cover calculations to run later (target ≤500 ms per computation path under test on desktop).
8) Documentation and traceability (ARCH, REQ)
   - Record interface definitions, schema validation notes, and RNG/persistence decisions for downstream stages.
9) Internal review/audit readiness (AUDITOR prep)
   - Prepare checklist and artifacts for the planned audit gate after Stage 2; ensure Stage 0 outputs are stored and referenced.

## Test Plan
- Unit tests (ARCH/ENGINEERING): seed/offset consistency for RNG; command DTO validation shape tests.
- Integration tests (ARCH/ENGINEERING): deterministic replay harness comparing state hashes/events given same seed + commands.
- Schema validation (DATA ENG): run schema checks against data dictionary for core entities (factions, missions, terrain, match/campaign state, command/RNG).
- Persistence integrity (ARCH/ENGINEERING): save/load round-trip with checksum and atomic write simulation.
- Benchmark plan (ARCH): define, but not execute heavy perf tests yet; ensure scripts/templates exist.

## Success Metrics & Acceptance Criteria
- Determinism: identical seeds + command list yield identical state hashes/events in replay harness.
- Schema: validation passes with no mismatches between DTOs/persistence and data dictionary.
- Persistence: save/load round-trip retains seed, command log, and state hash; checksum and atomic write workflow validated.
- Benchmarks: LoS/cover micro-bench plan with target budgets documented (≤500 ms per computation path on desktop).
- Hashing: State hash uses xxHash64 and is reproducible across platforms given identical snapshots.

## Dependencies, Assumptions, Risks
- Dependencies: current requirements/architecture/data dictionary/tech stack; audit-004 context.
- Assumptions: PC desktop first; no network/multiplayer implementation yet; placeholder assets acceptable.
- Risks: RNG drift if multiple RNG sources appear later → enforce single RNG service; schema drift → keep parity checks reusable; save corruption → rely on atomic writes + checksum.

## Open Questions / Follow-ups
- None currently.
