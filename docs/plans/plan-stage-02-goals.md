# Stage 2 Goals & Rationale
- Stage: 02 – Core Rules Engine & Validation Complete (Local)
- Version: 1.0.0
- Last Updated: 2025-12-12
- Author/Agent: Planning & Roadmap Agent ([PLANNER])

## S2.1 Context reload & scope confirmation
- Goal: Reaffirm Stage 2 boundaries, dependencies on Stage 0/1, and the frozen UI contracts before any engine changes.
- Rationale: Prevent scope drift and accidental UI contract breaks by grounding work in latest requirements/architecture/data and Stage 1 outputs.
- Supports: Keeps Stage 2 focused on rules fidelity while preserving Stage 1 interfaces needed for Stage 3 gameplay loop.

## S2.2 State model and resolver completion
- Goal: Implement the full production state model and resolver paths for all commands with deterministic RNG/hash handling.
- Rationale: A complete resolver is the core enabler for correct gameplay outcomes, mission scoring, and later UI integration.
- Supports: Provides the authoritative engine Stage 3 will call, ensuring actions produce validated, deterministic outcomes.

## S2.3 Validator coverage finish
- Goal: Extend legality checks to cover every rule edge case, optional rule gate, and LoS/cover condition.
- Rationale: Strong validation blocks illegal commands early, reducing downstream bugs and ensuring resolver inputs stay safe.
- Supports: Guarantees Stage 3 interactions remain rule-compliant, minimizing regressions in the gameplay loop.

## S2.4 Data loaders and schema enforcement
- Goal: Load factions/missions/terrain/optional rules from the data dictionary with schema validation and refreshed fixtures/exports.
- Rationale: Reliable data ingestion keeps engine logic aligned to authoritative definitions and prevents drift between code and content.
- Supports: Ensures Stage 3 uses accurate stats/mission data and that UI reference feeds stay synchronized.

## S2.5 UI contract alignment and adapters
- Goal: Keep resolver/validator outputs compatible with Stage 1 UI snapshot/event DTOs, adding adapters instead of schema changes when possible.
- Rationale: Preserving frozen contracts avoids rework for UI slices and maintains the integration slice built in Stage 1.
- Supports: Allows Stage 3 to consume engine outputs without UI rewrites, speeding integration.

## S2.6 Traceability matrix and coverage
- Goal: Map each GR/DA/AQ/MP requirement to engine code and tests, marking coverage and gaps.
- Rationale: Traceability proves completeness, guides testing, and prepares for audits with explicit coverage status.
- Supports: Provides a checklist for Stage 3 readiness and future audits, ensuring nothing critical is missed.

## S2.7 Golden deterministic scenarios
- Goal: Create replayable, seeded golden tests covering command sequences, optional rules, and error paths with expected hashes/logs.
- Rationale: Golden tests catch regressions fast and enforce determinism by comparing hashes and logs across runs.
- Supports: Forms the regression backbone for Stage 3 and later stages, keeping the engine stable as features grow.

## S2.8 Mission scoring and campaign toggles
- Goal: Implement scoring calculators and campaign advantage handling with toggles default-off but configurable.
- Rationale: Accurate scoring and toggle handling are required for campaign progression and integrity of match results.
- Supports: Enables Stage 3 to display correct scores and handle campaign states without reworking core logic.

## S2.9 Action log and determinism evidence
- Goal: Standardize logs/events to include dice, RNG seed/offset, hashes, and requirement tags, with checksummed persistence.
- Rationale: Rich logs provide audit trails and debugging evidence while proving determinism and data integrity.
- Supports: Gives Stage 3 and auditors trustworthy telemetry for gameplay and replay validation.

## S2.10 LoS/Cover production calculator and micro-bench
- Goal: Ship the production LoS/cover calculator and record benchmark results against the performance budget.
- Rationale: LoS/cover accuracy and speed are high-risk areas; benchmarking ensures readiness before UI and gameplay scaling.
- Supports: Reduces performance risk for Stage 3’s interactive loops and guards against determinism/perf regressions.

## S2.11 Audit prep and stage closure
- Goal: Assemble evidence (tests, benchmarks, traceability, fixtures) and publish the Stage 2 output summary for the Stage 3 gate.
- Rationale: Closing the stage with a clear record simplifies audits and ensures all acceptance criteria are met before proceeding.
- Supports: Delivers a clean handoff into Stage 3 with verified artefacts and documented readiness.
