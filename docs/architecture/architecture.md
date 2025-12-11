# Architecture

## Title & Revision Block
- Summary: Comprehensive architecture for Crossfire Sector digital adaptation with deterministic rules engine, modular UI/game loop, and extensible data-driven content mapped to GR/DA/CP/AQ/MP requirements.
- Last Updated: 2025-11-25
- Reason: Clarify validator traceability for LoS/cover, half-move attacks, movement through units, and mandatory Winner's Advantage enforcement.
- Agent: Software Architecture Agent

## 1. Architectural Overview (High-Level)
- Goal: Deliver a deterministic, data-driven tactical game that enforces tabletop rules (GR-001–GR-045), digital UX needs (DA-001–DA-021), cross-platform responsiveness (CP-001–CP-007), architecture quality (AQ-001–AQ-007), and multiplayer enablement (MP-001–MP-006).
- Constraints & principles: Deterministic core (AQ-003, MP-005), strict validation before mutation (AQ-007, DA-001–DA-007), data-driven faction/mission/rule parameters (AQ-002), testable seams (AQ-001, AQ-004), offline-first (CP-007), zero-cost stack (tech-stack.md).
- Candidate Architectures (evaluated):
  - **A. Modular Rule Engine + Scene Graph UI (selected)** – Core Engine isolates state, validation, and resolution; Godot scenes for UI/visuals; Command Bus mediates inputs; Persistence/Logging as services. Pros: strong determinism/testing (AQ-001, AQ-003), clean validation (AQ-007), easy content swaps (AQ-002), aligns with Godot stack, straightforward multiplayer commands (MP-001–MP-006). Cons: Requires disciplined separation and data schema design.
  - **B. UI-Driven Game Loop with Embedded Rules** – Godot scenes own flow, rules embedded in controllers. Pros: faster initial implementation. Cons: weaker isolation (AQ-001), harder deterministic replay (MP-003), more UI coupling, higher regression risk; rejected.
- Selected Approach: Architecture A due to superior testability, deterministic replay, modular growth for online play, and clearer traceability.

## 2. System Architecture (High-Level Modules)
- **Rules Engine** (GR-001–GR-045, DA-001–DA-021, AQ-001–AQ-007, MP-001–MP-006)
  - Subsystems: Command Validator, Resolver, State Model, RNG Service (seeded), LoS/Range/Cover Calculator, Mission/Scoring Engine, Campaign Manager, Optional Rules Toggles, Reroll Manager.
  - Responsibilities: Validate commands, simulate outcomes deterministically, emit state deltas/events.
- **Command Bus & Game Loop** (AQ-001, AQ-003, DA-002, DA-006, MP-001–MP-003)
  - Queues commands from UI/AI/network, sequences phases (setup → rounds → activations → scoring), routes to Rules Engine, applies state updates.
- **Data Layer** (AQ-002, GR-005–GR-011, GR-033–GR-042)
  - Config assets for factions, missions, events, commanders, terrain presets. Schema versioned, JSON/tres. Supplies data to Rules Engine at load time.
- **Persistence Service** (DA-009, CP-005, CP-007, MP-006)
  - Save/load matches and campaigns; stores serialized state, command history, RNG seed, and used missions. Supports resume and replay.
- **UI Layer** (CP-001–CP-004, DA-004–DA-014, DA-017–DA-021)
  - Scenes: Main Menu, Match Setup, Battlefield View, Action Picker, Dice/Result Panel, Logs/History, Rules Reference/Glossary, Campaign Screen. Consumes state snapshots and events; never mutates state directly. Rules Reference/Glossary consumes structured data from rules/requirements/data dictionary exports (e.g., JSON for stats, actions, missions, optional rules) to keep in-game reference aligned with source documents.
- **Input Layer** (CP-001)
  - Adapters for pointer, touch, controller; maps gestures/buttons to abstract commands.
- **Networking Adapter (future)** (MP-001–MP-006)
  - Optional authoritative/session module to send/receive commands, synchronize seeds/state; built on Godot Multiplayer API.
- **Cross-Cutting Services** (DA-006, AQ-004, AQ-007)
  - Logging, Telemetry, Error Handling, Diagnostics Overlay; all invoked via lightweight interfaces to avoid UI coupling.
- **Rendering & Scene Composition**
  - Visual layer for board, units, effects; subscribes to state events, does not own rules.

Module Interactions:
- UI/Input → Command Bus → Rules Engine (validate/resolve) → State Model → UI renders snapshot; Persistence subscribes to state/commands; Logging observes all steps; Networking Adapter mirrors command stream and state hashes.

## 3. Low-Level System Details
- State Model (AQ-001, AQ-003, GR-001–GR-045): Immutable snapshots per tick with board grid, units, statuses (Down, activation counts), missions, campaign meta, event toggles, RNG seed/offset, command history. Supports diffing for replay/undo (where allowed).
- Command Lifecycle (DA-002, DA-003, MP-001–MP-005):
  1. Input Layer builds `Command` (type, actor, targets, payload).
  2. Command Bus timestamps, orders, and passes to Validator.
  3. Validator checks legality (zones, LoS, range, activation limits, reroll availability).
  4. Resolver executes deterministic simulation using RNG Service; produces `Event`s (hit, Down, kill, initiative outcome, mission score).
  5. State updated; Persistence logs command + seed offset; UI renders events; Networking broadcasts if enabled.
- Validator rules coverage:
  - Deployment (GR-012, DA-001), movement bounds/impassable with pass-through allowance (GR-018, GR-032, GR-032.1, DA-004), action limits (GR-015–GR-017), attack half-move allowance before Shoot/Melee (GR-019), LoS/Range/Cover (GR-031, GR-004, GR-021.1, DA-005), reroll caps (GR-045, DA-018), campaign Winner's Advantage enforcement (GR-040), optional commander/events toggles (GR-041–GR-042).
- Resolver capabilities:
  - Initiative/round loop (GR-013–GR-016, GR-043–GR-044), attack resolution (GR-022–GR-026, DA-006), melee (GR-027–GR-028), down/first aid flow (GR-020, GR-029–GR-030, DA-007), mission scoring each round (GR-033–GR-035.1, DA-009), campaign scoring (GR-036–GR-040), Quick Start/Revive handling (DA-017, DA-019), commander effects (GR-041, DA-020), events (GR-042).
- Data Schemas (AQ-002):
  - Faction data: base stats, traits, movement mode, reroll rules.
  - Mission data: control zones, scoring timing, special point modifiers.
  - Terrain templates: size ranges, blocking/cover flags.
  - Optional rules flags: commander, events, campaign length.
- RNG Service (AQ-004, MP-005): Central seeded RNG; all random ops (terrain placement, initiative, attacks) pull sequential values; exposes seed/offset for replay.
- Persistence Format (CP-005, MP-006): JSON/tres save containing seed, command list, current state hash, mission/event selection, campaign standings, advantages chosen (GR-040), used missions list (GR-039, DA-015).
- Persistence Policies (CP-005, CP-007): 5–10 campaign slots per profile; 3–5 quick slots for single matches. Save targets ≤256 KB per match; ≤512 KB per campaign; gzip only if above target and keep version hashes. One active loaded match at a time; optional support for up to 2–3 concurrently loaded sessions with background pause. Atomic writes (temp + rename), checksum per save, and free-space checks before write.
- UI Contracts (DA-004–DA-012):
  - UI Snapshot DTO (Stage 1 frozen; GR-001–GR-045, DA-001–DA-021, AQ-001–AQ-004):
    | Field | Type | Required | Notes | Requirements |
    | --- | --- | --- | --- | --- |
    | version | string | yes | Snapshot schema version | AQ-003–AQ-004 |
    | board | object | yes | `{columns:int, rows:int}` | GR-001, DA-004 |
    | units | array | yes | `[{id, owner_id, position{col,row}, status, cover?, in_range?, activated?}]` | GR-005–GR-030, GR-045, DA-003–DA-007, DA-012, DA-018 |
    | terrain | array | yes | `[{template_id, cells:[{col,row}]}]` | GR-002–GR-004, GR-018, GR-031, DA-004–DA-005 |
    | reachability | array | no | `[{col,row,color?,name?}]` (includes half-move labels) | GR-018–GR-020, DA-004 |
    | los | array | no | `[{from,to,visible,path?,blocker?,rays?}]`; `rays[]` present by default for diagnostics | GR-004, GR-031, DA-005, DA-021 |
    | cover_sources | array | no | `[{col,row,kind}]` | GR-004, DA-005 |
    | activation | object | yes | `{round:int, active_player:string, remaining:int}` | GR-013–GR-017, GR-043–GR-044, DA-003 |
    | mission | object | yes | `{mission_id:string, scores:{p1:int,p2:int}, round:int}` | GR-033–GR-035.1, DA-008–DA-009, DA-016 |
    | campaign | object | yes | `{battle_index:int, total_battles:int, scores:{p1:int,p2:int}, advantages:[string]}` | GR-036–GR-040, DA-009, DA-015–DA-017 |
    | options | object | yes | `{commander:bool, events:bool, quick_start_used:bool, revive_used:bool}` | GR-041–GR-042, DA-010, DA-017, DA-019–DA-020, AQ-006 |
    | rng | object | yes | `{seed:string, offset:int}` | AQ-003–AQ-004, MP-005 |
    | logs | array | yes | Strings or structured entries `{type,message,requirements?,timestamp?,severity?}` | DA-013, MP-004 |
    | errors | array | no | `[{code:string,message:string,requirement_id?:string}]` | DA-001–DA-007 |
    | hash | string | no | State hash for determinism evidence | AQ-003, MP-005 |
  - UI Event DTO (Stage 1 frozen; GR-022–GR-028, GR-031, GR-033–GR-035.1, DA-006, DA-013):
    | Field | Type | Required | Notes | Requirements |
    | --- | --- | --- | --- | --- |
    | type | string | yes | Event kind (dice_roll, attack_resolved, melee_resolved, mission_score, campaign_score, error, log_line, etc.) | DA-006, DA-013 |
    | payload | object | yes | Event-specific data (dice, attacker/target ids, damage, hashes) | GR-022–GR-028, GR-033–GR-035.1 |
    | requirements | array\<string> | yes | Traceability IDs | GR/DA coverage |
    | severity | string | yes | Enum: info/warning/error | DA-006, DA-013 |
    | timestamp | int | no | Optional epoch ms for logs/telemetry | DA-013 |
    | event_seq | int | no | Optional monotonic sequence for ordering | AQ-003, MP-003 |
  - Preview API: Validator exposes `preview.reachable_tiles` and valid targets without committing state; adapters map validation errors to UI error DTOs. For LoS raycast diagnostics (preferred bounding-box approach), preview payload MAY include `rays:[{from:Vector2,to:Vector2,blocked:bool,blocker?:{col,row,kind}}]` (GR-031, DA-005).
  - Rules Reference/Glossary feed: `docs/data-definition/exports/ui_reference.json` (version, factions[], actions[], missions[], optional_rules) generated via `tools/build_ui_reference.js`; UI panels consume read-only content so gameplay logic stays centralized.

  - Mapping guide (Validator/Resolver → UI DTOs):
    - `reachable_tiles` → `reachability`; add `name` (e.g., `"half-move"`) if needed for half-move previews (GR-019/020).
    - `valid_targets`/range checks → `units[].in_range` and/or a `targets` helper list in the action picker (GR-021.1).
    - LoS/cover preview → `los[...]`, `cover_sources[...]`, `units[].cover`; optional `rays[...]` for raycast debug (GR-031, GR-004, DA-005).
    - Activation legality → `activation.remaining`, `units[].activated` (GR-015–GR-017).
    - Errors → `errors[{code,message,requirement_id?}]` and `event{type:"error"}` (DA-001–DA-007).
    - Dice/attack/melee outcomes → `event{type:"dice_roll"/"attack_resolved"/"melee_resolved"}` and `units[].status` updates (GR-022–GR-028).
    - Mission/campaign scoring → `mission{scores,round}`, `campaign{scores,advantages}` with `event{type:"mission_score"/"campaign_score"}` (GR-033–GR-040).
    - Optional rules usage → `options{commander,events,quick_start_used,revive_used}` (GR-041–GR-042, DA-017/019/020).
    - Determinism → `rng{seed,offset}` and optional `hash`; consider `event_seq` if telemetry/replay needs ordering (AQ-003/004, MP-003/005).
- Cross-Cutting:
  - Logging (DA-006, DA-013): Structured logs per command with dice rolls, RNG offsets, validation decisions.
  - Error handling: Validator returns typed errors for illegal commands; UI surfaces messages.
  - Performance: Grid computations optimized via cached LoS masks; batching UI updates per tick.
  - Performance Budgets & Optimizations (CP-006): Targets 60 FPS desktop, 45–60 FPS mid-tier mobile; input-to-visual latency ≤100 ms; turn processing ≤150 ms for initiative + two activations; working set ≤500 MB desktop and ≤250 MB mobile; per-match save ≤256 KB (state + command log). Rendering caps draw calls via instancing, limits dynamic lights on mobile, prefers baked lighting/material simplicity; LOD for units as needed. LoS/cover uses Bresenham/DDA with early exit, cached per attacker/state hash, invalidated only on blocking changes. Movement uses BFS with obstacle map and diagonal corner checks; reuse reachable-tile caches per activation. Logging batched; RNG seed/offset flushed with saves to avoid I/O jitter. Perf micro-benchmarks cover LoS caching and activation timing on target devices.
- Testing Strategy (AQ-001, AQ-003, AQ-004, AQ-007):
  - Unit tests for validators (deployment, LoS, activation counts).
  - Property tests for deterministic RNG replay.
  - Integration tests for round loops, mission scoring.
  - Golden-record tests for faction traits and optional commander/event toggles.
  - Interfaces & Test Seams: Validator interface `validate(command, state, data_config) -> ValidationResult {ok, errors[], preview{reachable_tiles, valid_targets}}` with unit tests for deployment zones/row distribution (GR-012, DA-001), movement/impassable/diagonal corner checks plus pass-through occupied squares (GR-018, GR-032, GR-032.1, DA-004), activation limits (GR-015–GR-017, DA-003), attack half-move enforcement before Shoot/Melee (GR-019), LoS/range/cover legality (GR-031, GR-004, GR-021.1, DA-005), reroll caps (GR-045, DA-018), mandatory campaign Winner's Advantage selection (GR-040), optional commander/events toggles (GR-041–GR-042). RNG interface `Rng(seed, offset=0)` with `roll_d6`, `roll_2d6`, `advance(n)`, `snapshot/restore`; property tests ensure identical seeds + commands produce identical rolls (AQ-003, MP-005), offsets track calls, and snapshot/restore serialize in saves. Mission/Scoring interface `score_round(state, mission_config)` and `evaluate_control(state)`; tests for mission objectives and no-point ties (GR-033, GR-035.1), Occupy bonuses, tie-triggered extra rounds (GR-035), mission uniqueness (GR-039), advantages persistence (GR-040), per-battle points (GR-038). Integration tests cover round loop (GR-013–GR-016, GR-043–GR-044), Down/First Aid immediate activation (GR-029–GR-030, DA-007), commander/events effects (GR-041–GR-042, DA-019–DA-020). Perf micro-benchmarks for LoS caching and activation timing on target devices.

## UI Scenes & Input Map (Stage 1)
- Scenes under `project/src/ui/scenes/`:
  - `battlefield_view.tscn` (`battlefield_view.gd`): grid layers (tiles/reachability/LoS rays/units), status/log labels; consumes snapshot `board`, `units`, `terrain`, `reachability`, `los` (with `rays`), `cover_sources`, `activation`, `mission`, `campaign`, `options`, `rng`, `logs`, `errors`. Signals: `cell_selected(col,row)`, `unit_selected(unit_id)`, `command_requested(command_dict)`.
  - `action_picker.tscn` (`action_picker.gd`): OptionButton for actions; consumes `units[].status/in_range`, `activation.remaining`, `options`; signals `action_chosen(action_id)`, `target_requested`.
  - `dice_panel.tscn` (`dice_panel.gd`): RichTextLabel for dice/result events; consumes event stream entries; no signals.
  - `log_viewer` (panel within battlefield/log): consumes `logs`, `errors`, event stream; optional `log_scrolled` signal.
  - `reference_panel.tscn` (`reference_panel.gd`): loads `docs/data-definition/exports/ui_reference.json` (`factions`, `actions`, `missions` with `per_round_deltas`, `optional_rules`, `glossary`, `localizations`); signals `reference_loaded`, `reference_failed`.
  - `stage01_slice.tscn` (`stage01_slice.gd`): composes the above, uses `UISliceLoader` to load canonical fixture `docs/data-definition/fixtures/save_match.json`.
  - Prototypes: `los_test_slice.tscn`/`.gd` and `los_bbox_slice.tscn`/`.gd` for LoS/cover visualization using `los.rays`, `reachability`.
  - Placeholder assets: colored sprites/tiles for units/terrain, Line2D for rays, basic icons for actions; no binary assets required.
- Desktop input map → Command DTOs (Stage 1):
  - Pointer LMB select: select unit/cell (UI-only selection).
  - Pointer LMB confirm on highlighted target: emit command `{type:"move"/"attack"/"melee"/"first_aid"/"hold", payload:{...}}` via command bus.
  - Right-click or ESC: cancel selection (UI-only).
  - Keyboard bindings (`ui_input_map.gd`):
    - `A`/`1`: Move
    - `S`/`2`: Attack
    - `D`/`3`: Melee
    - `F`/`4`: First Aid
    - `H`/`0`: Hold
    - `R`: Reroll (with die selection in payload)
    - `Q`: Quick Start Move (when available)
    - `Ctrl+Z`: undo UI selection (no game-state undo in Stage 1)
- Touch/mobile bindings deferred unless CP-001 parity is requested now.
## 4. Technology Alignment
- Engine: Godot 4.x scenes for UI/rendering; rules engine and command bus in GDScript/C# modules separated from scene tree (AQ-001).
- Data: JSON/tres configs for factions/missions/terrain/events (AQ-002); loaded at startup and cached.
- Persistence: Godot `FileAccess` with JSON + gzip optional; save slots stored locally (CP-005, CP-007).
- Networking (future): Godot Multiplayer API (ENet/WebSocket) for command replication and state sync (MP-001–MP-006).
- Logging: `print_rich` plus rotating text logs; optional on-disk per session; compatible with CI text parsing (DA-013).
- Input/UX: Godot Control system; responsive layouts for desktop/mobile (CP-001–CP-004); zoom/pan via camera controls (CP-003); performance tuned via Forward+/Mobile renderer (CP-006).

## 5. Architectural Rationale
- Separation of concerns: Isolating Rules Engine from UI enables deterministic replay (AQ-003, MP-005) and easier testing (AQ-001).
- Data-driven content: JSON/tres allows balancing and modding without code changes (AQ-002) and supports faction/mission expansion (GR-005–GR-011, GR-033–GR-042).
- Command pattern: Serializes all actions for offline/online parity (MP-001–MP-003) and redo/replay needs (DA-013).
- Seeded RNG: Centralized randomness for reproducibility and debugging (AQ-004, MP-005).
- Cross-platform UI: Godot Control layouts meet mobile/desktop needs (CP-001–CP-004) while keeping performance manageable (CP-006).
- Optional networking adapter: Keeps offline-first while preparing for authoritative or lockstep modes without changing core rules (MP-002–MP-006).

## 6. Change Log
- 2025-06-02: Clarified validator/test coverage for LoS/cover IDs, GR-019 half-move enforcement, GR-032.1 pass-through movement, and mandatory GR-040 campaign advantage handling.
- 2025-11-25: Added interfaces and test seams for Validator, RNG, mission/scoring, and integration/perf testing (AQ-001–AQ-007, MP-005).
- 2025-11-25: Added persistence slot/size/concurrency policies and integrity guidance (CP-005, CP-007).
- 2025-11-25: Added performance budgets and LoS/cover optimization guidance (CP-006).
- 2025-11-25: Replaced placeholder with full architecture, candidate comparison, module breakdown, data flows, and traceability coverage.
- 2025-11-25: Created placeholder architecture document.

## 7. Summary & Evaluation
- Strengths: Deterministic, testable core; clear module boundaries; data-driven content; command/replay pipeline supports MP and offline save/resume; explicit validator/resolver coverage of GR/DA/CP/AQ/MP; cross-cutting logging and error handling.
- Weaknesses: Requires discipline to keep UI separate from rules; RNG offset tracking must stay consistent; LoS/cover computation complexity may need optimization on mobile (CP-006).
- Requirement coverage: Rules Engine + Validator/Resolver cover GR-001–GR-045; Data/toggles cover GR-005–GR-042 with GR-040 enforced in campaigns and GR-041–GR-042 as optional; Command Bus/Seeded RNG/replay address DA-001–DA-021 and MP-001–MP-006; UI/Input/Rendering handle CP-001–CP-007; AQ-001–AQ-007 met via isolation, data-driven configs, deterministic state, centralized RNG, and validation APIs.
- Testability: Command pattern, pure validation functions, seeded RNG, and snapshot/state hashing enable unit/integration/golden tests; UI contracts allow view-model testing without rendering.
- Maintainability: Data schemas and modular services simplify balance changes and optional commander/event toggles; networking adapter remains pluggable. Remaining gap: finalize device matrix for performance targets (CP-006); core behaviors, saves, concurrency limits, and sizing are specified.
