# Crossfire Sector Project

## Purpose
- Digital adaptation of the tabletop Crossfire Sector skirmish game for two-player local play on desktop and mobile, with rules identical to `rules.md`.
- Builds a deterministic, data-driven engine that keeps saves/replays consistent and prepares for future online multiplayer without changing core rules.

## Goals
- Enforce all gameplay requirements (GR-001–GR-045) with clear UX validation and previews (DA-001–DA-021).
- Support responsive input and layouts across devices (CP-001–CP-007) while keeping performance and battery budgets in check.
- Maintain modular, testable architecture (AQ-001–AQ-007) with serialised commands and seeded RNG ready for multiplayer enablement (MP-001–MP-006).
- Keep faction/mission/terrain/optional rule data configurable so balance updates avoid code changes.

## Requirements Summary (`docs/requirements/requirements.md`)
- Game rules: 15×9 board, random terrain 3–5 pieces, cover grants +1 Defense, five factions with defined stats and traits, deployment in home zones across ≥2 rows, initiative choice then alternating activations (4 max per player), half-move attacks, LoS/Range/Cover enforcement, crit/crit-fail handling, Down/First Aid flow, six missions with per-round scoring and single 7th-round tie-breaker, campaigns of 3–5 battles with Winner’s Advantage and optional commander/events toggles.
- Digital UX: validation and previews for deployment/move/attacks, LoS and cover indicators, action logs, mission/campaign score tracking, toggles for optional rules, reroll selection with single-reroll limit, Quick Start/Revive handling, in-game glossary.
- Cross-platform: unified input (pointer/touch/controller), responsive UI, zoom/pan, offline-friendly saves/resume, battery-aware.
- Architecture quality: isolated rules engine, data-driven configs, deterministic state/RNG, modular optional rules, validator exposure for all commands.
- Multiplayer readiness: all actions as serialisable commands, authoritative state with deterministic RNG, command logs for replay/spectator, reconnection support.

## Architecture Snapshot (`docs/architecture/architecture.md`)
- Chosen approach: Modular Rules Engine + Scene Graph UI. Core modules: Rules Engine (validator/resolver, LoS/Range/Cover calculator, mission/campaign scoring, optional toggles), Command Bus/Game Loop, Data Layer, Persistence, UI/Input, cross-cutting logging/telemetry, future Networking Adapter.
- State model: immutable snapshots with board/units/status, mission/campaign meta, RNG seed/offset, command history; diff-friendly for replay and saves.
- Validator/Resolver coverage: deployment bounds and row distribution, movement with diagonal corner checks and pass-through units, half-move attack allowance, LoS/range/cover legality, reroll caps, mandatory Winner’s Advantage, optional commander/events, mission scoring per round with single extra 7th round.
- Performance and testing: cached LoS/movement reachability, target 60 FPS desktop/45–60 FPS mobile, save size budgets, interfaces for validator/RNG/mission scoring with unit, integration, golden, and perf micro-benchmarks.

## Tech Stack (`docs/architecture/tech-stack.md`)
- Engine/UI: Godot 4.x with Control/Theme system for responsive layouts; scenes for UI/rendering separated from rules modules.
- Data/Persistence: JSON/`.tres` configs for factions/missions/terrain/events; saves via Godot `FileAccess` with JSON (optional gzip); local slots for matches/campaigns.
- Logging: Godot logging (`print_rich`, per-category Logger) with rotating text logs for replay/debug.
- Networking (future): Godot Multiplayer API (ENet/WebSocket) for authoritative or lockstep replication; compatible with open-source backends; zero-cost stack maintained.

## Data Dictionary Snapshot (`docs/data-definition/data-dictionary.md`)
- Core configs: `BoardLayout` (15×9 grid, home zones, bounds), `TerrainTemplate` (blocking/cover/impassable defaults), `MissionDefinition` (six missions, control zones, single extra round), `FactionDefinition` with traits, `UnitTemplate` variants.
- Runtime state: `PlayerState` (roster, activation limits, advantages/traits toggles), `UnitState` (position/status/activations/rerolls/cover), `RoundState` (initiative, activation batches, per-round mission points, single extra round cap), `MatchState` (full battle snapshot with terrain placements, optional rule flags, RNG, command log link).
- Determinism & replay: `Command` and `CommandLog` with ordered sequences and RNG offsets; `RNGSeed` per match/campaign; `CampaignState` tracks mission uniqueness, scores, advantages history.
- Optional/future entities: `AdvantageOption`, `CommanderTrait`, `BattleEvent`, `OptionalRulesConfig`, plus placeholders for map presets, loadouts, AI profiles, networking sessions, cosmetics, telemetry—kept additive and versioned for migration safety.
