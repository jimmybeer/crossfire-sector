# Crossfire Sector Planning Roadmap
- Version: 1.0.0
- Last Updated: 2025-11-27
- Author/Agent: Planning & Roadmap Agent ([PLANNER])

## Project Goals & Constraints
- Deliver a deterministic, data-driven digital adaptation of Crossfire Sector that fully enforces `docs/requirements/requirements.md` for local hotseat play first.
- Build on the selected Godot 4 stack with a clean separation between rules engine, UI, and data layers to enable replay, save/resume, and future multiplayer.
- Minimize risk via staged delivery, early validation of determinism and performance, and strong alignment with architecture/data definitions.
- MVP: stable, fully tested local 2-player hotseat implementing the complete ruleset; placeholder visuals/audio acceptable; no multiplayer or AI.

## Stage Summary
| Stage | Objective | Dependencies | Expected Outputs |
| --- | --- | --- | --- |
| 0 | Foundations & architecture/data alignment | None | Validator/Resolver scaffolding, RNG/replay harness, save format/checksums, schema parity checks, exit metrics defined |
| 1 | UI contracts & reference data feeds | 0 | UI scene contracts, state snapshot DTOs, desktop input mapping, rules reference feed, exit metrics defined |
| 2 | Core rules engine & validation complete (local) | 0–1 | Full rules validation/resolution, mission scoring, campaign toggles, golden tests, action log, audit gate planned |
| 3 | MVP gameplay loop (hotseat) | 0–2 | Playable loop with setup/deployment/rounds/actions, previews, save/resume, smoke audit gate |
| 4 | MVP complete & stability | 3 | Full test pass, perf checks (LoS/cover), integrity checks, MVP acceptance criteria met, audit gate |
| 5 | UX/UI polish & visual/audio direction | 4 | Improved visuals/animations/audio, UI refinement, accessibility/perf tuning with asset/perf budgets |
| 6 | AI opponents (offline) | 4 (parallel with 5) | AI profiles activated, baseline bot behavior via command stream, deterministic AI tests, AI acceptance metrics |
| 7 | Content & optional systems expansion | 5–6 | New data packs (missions/maps/events/commanders), migration notes, balance checks, updated reference |
| 8 | Online enablement foundations (sync & persistence) | 4, 0 | Networking session schema, command replication prototype, state hash/reconnect, matchmaking stub, MP mode decision |
| 9 | Asynchronous multiplayer (1v1) | 8 | Async turn submission with validation, resume, integrity checks, MP tests/audits, security reviews |
| 10 | Final product & live readiness | 5–9 | Final QA, perf/load baselines, crash/bug SLOs, release packaging, optional telemetry plan |

## Detailed Stage Descriptions

### Stage 0 – Foundations & Architecture/Data Alignment
- Objectives: Lock deterministic seams, schema alignment, and persistence integrity to de-risk all later work.
- Dependencies: None.
- Inputs: `docs/requirements/requirements.md`, `docs/architecture/architecture.md`, `docs/data-definition/data-dictionary.md`, `docs/architecture/tech-stack.md`, `docs/audits/audit-004.md`.
- Expected Outputs: Validator/Resolver scaffolding, seeded RNG service with replay harness, command DTOs, save/load format with checksum and SHA-256 state hash, schema parity checks against data dictionary, perf micro-bench plan for LoS/cover.
- Risks & Mitigations: RNG drift → seed/offset tests; schema mismatch → automated schema validation; save corruption → checksum and atomic writes.
- Exit Criteria: Command replay proves determinism (identical seeds → identical outcomes); schema validation passes against data dictionary; save/load integrity verified (checksum + atomic write); perf micro-bench plan drafted with target budgets.
- Agents: ARCH, REQ, DATA ENG, AUDITOR.
- Links: stage plan to be created at `docs/plans/plan-stage-00.md`.

### Stage 1 – UI Contracts & Reference Data Feeds
- Objectives: Establish UI contracts and scenes skeleton with data-driven rules reference; desktop input adapters.
- Dependencies: Stage 0.
- Inputs: State snapshot DTOs, command/event schema, rules/data exports.
- Expected Outputs: Battlefield/action/log/reference UI contracts, rules reference fed from structured data, pointer/keyboard input mapping, DTOs for rendering previews and logs.
- Risks & Mitigations: UI-rule drift → consume generated reference data; contract instability → freeze interfaces before implementation.
- Exit Criteria: UI contracts frozen with DTO snapshots; rules reference pulls from generated data; input mapping verified on desktop; no blocking gaps for Stage 2/3; metrics defined (UI responsiveness target, load time target).
- Agents: ARCH, DATA ENG, REQ, AUDITOR.
- Links: stage plan to be created at `docs/plans/plan-stage-01.md`.

### Stage 2 – Core Rules Engine & Validation Complete (Local)
- Objectives: Implement full ruleset validation/resolution per GR/DA with campaign toggles off by default.
- Dependencies: Stages 0–1.
- Inputs: Requirements IDs GR-001–GR-045, DA-001–DA-021; data schemas for factions/missions/terrain/optional rules.
- Expected Outputs: Complete validator/resolver, mission scoring, campaign toggles, unit/faction/terrain loaders, golden tests, action log with dice, reroll enforcement, optional rules hooks.
- Risks & Mitigations: Coverage gaps → traceability matrix to requirements; performance → early LoS/cover benchmarks; regression → golden tests with seeds.
- Exit Criteria: Requirement traceability matrix green; golden tests pass; LoS/cover micro-bench meets targets; action log includes dice/RNG offsets; planned audit gate ready (invoke AUDITOR after completion).
- Agents: ARCH, REQ, DATA ENG, AUDITOR.
- Links: stage plan to be created at `docs/plans/plan-stage-02.md`.

### Stage 3 – MVP Gameplay Loop (Hotseat)
- Objectives: Deliver playable 2-player hotseat with setup, deployment, full round/activation loop, previews, and save/resume.
- Dependencies: Stages 0–2.
- Inputs: Validator/resolver, UI contracts, state snapshots, save format.
- Expected Outputs: Match setup (mission select/roll, optional toggles), hidden/order-agnostic deployment, initiative/activation flow, movement/attack/first-aid/hold actions with previews, save/load of matches/campaigns, basic logs visible in UI.
- Risks & Mitigations: UX confusion → clear prompts and previews; save failures → reuse checksum/atomic writes; rule fidelity → regression tests and smoke audit.
- Exit Criteria: End-to-end hotseat match completes with full rules; saves/resumes work; smoke audit executed with no critical/major findings; usability sanity check on desktop.
- Agents: ARCH/UI, REQ, DATA ENG, AUDITOR.
- Links: stage plan to be created at `docs/plans/plan-stage-03.md`.

### Stage 4 – MVP Complete & Stability
- Objectives: Harden MVP and confirm acceptance (stable, fully tested, full rules).
- Dependencies: Stage 3.
- Inputs: Full test suite, perf micro-bench results, audit findings if any.
- Expected Outputs: Test pass report, perf checks for LoS/cover, save/command log integrity checks, bug fixes, MVP acceptance checklist.
- Risks & Mitigations: Hidden defects → broaden test coverage; perf regressions → targeted profiling; data drift → resync reference data.
- Exit Criteria: All tests green; LoS/cover perf within budget; integrity checks pass; MVP acceptance checklist signed; audit completed with no critical/major issues.
- Agents: ARCH, AUDITOR, REQ.
- Links: stage plan to be created at `docs/plans/plan-stage-04.md`.

### Stage 5 – UX/UI Polish & Visual/Audio Direction
- Objectives: Improve visuals, animations, sound baseline, UI polish without altering rules.
- Dependencies: Stage 4.
- Inputs: MVP UI, asset pipeline, performance budgets.
- Expected Outputs: Upgraded visuals/animations/audio, refined UI readability/responsiveness, accessibility pass, performance tuning for new assets.
- Risks & Mitigations: Perf hits → asset budgets and profiling; scope creep → keep rules untouched and UI minimal-risk changes.
- Exit Criteria: UI responsiveness meets targets; accessibility checklist complete; asset/perf budgets enforced (draw calls, texture sizes, lights/material limits) with perf verified; no regressions in rules/UI contracts.
- Agents: ARCH/UI, REQ, AUDITOR.
- Links: stage plan to be created at `docs/plans/plan-stage-05.md`.

### Stage 6 – AI Opponents (Offline)
- Objectives: Add AI using the same command stream; keep determinism.
- Dependencies: Stage 4 (can proceed in parallel with Stage 5 via branching).
- Inputs: Command bus, validator/resolver, AIProfile schema.
- Expected Outputs: AI profiles activated, baseline bot behaviors, AI-vs-human hotseat, deterministic AI tests tied to seeds.
- Risks & Mitigations: AI breaking rules → enforce validation; unpredictability → seed-based determinism; UX frustration → difficulty knobs.
- Exit Criteria: AI uses validated commands only; deterministic AI tests pass with fixed seeds; basic difficulty tuning documented; no rule violations in smoke audit.
- Agents: ARCH, DATA ENG, AUDITOR, REQ.
- Links: stage plan to be created at `docs/plans/plan-stage-06.md`.

### Stage 7 – Content & Optional Systems Expansion
- Objectives: Add data-driven content (missions/maps/terrain variants/events/commanders) and optional systems safely.
- Dependencies: Stages 5–6.
- Inputs: Data dictionary, content creation pipeline, migration guidance.
- Expected Outputs: New data packs with migration notes, updated rules reference, optional systems toggles verified.
- Risks & Mitigations: Data drift → validation scripts; balance issues → REQ review; save compatibility → migration paths.
- Exit Criteria: Migration notes provided for new content; validation scripts updated; balance review completed; saves remain compatible (with migrations if needed); reference data regenerated and verified.
- Agents: DATA ENG, REQ, ARCH, AUDITOR.
- Links: stage plan to be created at `docs/plans/plan-stage-07.md`.

### Stage 8 – Online Enablement Foundations (Sync & Persistence)
- Objectives: Prepare for async 1v1 with matchmaking/campaign continuity; choose sync mode aligned to cost efficiency.
- Dependencies: Stage 4 and Stage 0 replay foundation; coordinate with Stage 6 if AI shares pipelines.
- Inputs: Command/replay pipeline, RNG seed handling, persistence format, NetworkingSession schema (draft).
- Expected Outputs: Networking session schema, command replication prototype (loopback), state hash verification, reconnect/resume from serialized data, matchmaking flow stub, storage choice documented.
- Risks & Mitigations: Protocol drift → strict schema/versioning; determinism → seed/hash checks; cost risk → pick low-cost hosting option.
- Exit Criteria: Sync mode decision recorded (authoritative vs lockstep/relay) with rationale and cost note; loopback replication passes determinism/hash checks; reconnect/resume proven; matchmaking/storage assumptions documented; no critical issues in MP-focused audit prep.
- Agents: ARCH, DATA ENG, AUDITOR, REQ.
- Links: stage plan to be created at `docs/plans/plan-stage-08.md`.

### Stage 9 – Asynchronous Multiplayer (1v1)
- Objectives: Deliver async matches with server-side validation and reconnection.
- Dependencies: Stage 8.
- Inputs: Networking prototype, persistence, command validation services.
- Expected Outputs: Queue/matchmaking, turn submission with validation, conflict resolution, resume from saves, integrity checks, MP-focused tests and audits.
- Risks & Mitigations: Security/cheating → authoritative validation; sync errors → hash/state reconciliation; UX delays → turn notifications/budgets.
- Exit Criteria: Async 1v1 flow completes with authoritative validation; reconnection works from serialized data; integrity/state-hash checks pass; MP audit run with no critical findings; basic security review documented.
- Agents: ARCH, DATA ENG, AUDITOR, REQ.
- Links: stage plan to be created at `docs/plans/plan-stage-09.md`.

### Stage 10 – Final Product & Live Readiness
- Objectives: Consolidate features, performance, and release hardening.
- Dependencies: Stages 5–9.
- Inputs: Full feature set, perf/load results, crash/bug data.
- Expected Outputs: Final QA sweep, load/perf baselines, crash/bug SLOs, documentation, release packaging, optional telemetry plan (if constraints allow).
- Risks & Mitigations: Late regressions → freeze and fix; load surprises → pre-release load tests; telemetry concerns → opt-in, no PII.
- Exit Criteria: Load/perf baselines met; crash/bug SLOs set and met; release checklist complete; telemetry plan (if enabled) meets privacy constraints; final audit completed with no critical issues.
- Agents: ARCH, AUDITOR, REQ, DATA ENG.
- Links: stage plan to be created at `docs/plans/plan-stage-10.md`.

## Global Risks & Mitigations
- Determinism drift across stages: enforce seeded RNG and command replay tests per release.
- Schema/UI divergence: automate data export to UI reference and contract checks.
- Performance on LoS/cover: keep micro-benchmarks and budget enforcement; optimize before heavy assets.
- Save integrity: checksums and atomic writes required from Stage 0 onward; regression tests after asset changes.

## Stage Plan Links
- Stage plans will be added as `docs/plans/plan-stage-XX.md` when detailed planning is requested for each stage.
