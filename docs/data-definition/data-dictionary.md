# Data Dictionary

This dictionary is the agentic map for Crossfire Sector data: use it to align JSON schemas with rules/architecture, keep migrations traceable, and sanity-check Godot sync points before edits. Update entities here first, then mirror changes in engine resources to preserve deterministic saves and replay integrity.

## Linked Table of Contents
- [BoardLayout](#boardlayout)
- [TerrainTemplate](#terraintemplate)
- [MissionDefinition](#missiondefinition)
- [FactionDefinition](#factiondefinition)
- [UnitTemplate](#unittemplate)
- [PlayerState](#playerstate)
- [UnitState](#unitstate)
- [RoundState](#roundstate)
- [Command](#command)
- [CommandLog](#commandlog)
- [RNGSeed](#rngseed)
- [MatchState](#matchstate)
- [CampaignState](#campaignstate)
- [AdvantageOption](#advantageoption)
- [CommanderTrait](#commandertrait)
- [BattleEvent](#battleevent)
- [OptionalRulesConfig](#optionalrulesconfig)
- [SaveSlot](#saveslot)
- [MapPreset](#mappreset)
- [Loadout](#loadout)
- [AIProfile](#aiprofile)
- [NetworkingSession](#networkingsession)
- [CosmeticSkin](#cosmeticskin)
- [TelemetryEvent](#telemetryevent)
- [Validation & Gap Analysis](#validation--gap-analysis)
- [Summary & Evaluation](#summary--evaluation)

---

## BoardLayout
[Back to TOC](#linked-table-of-contents)
**Purpose:** Defines the battlefield grid, deployment/home zones, and bounds enforcement for movement and placement validation.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique layout id. |
| name | string | yes | Standard 15x9 | Human-readable label. |
| columns | int | yes | 15 | Must be >0. |
| rows | int | yes | 9 | Must be >0. |
| home_zones | array\<HomeZone\> | yes | P1 cols 1-2, rows 1-9; P2 cols 14-15, rows 1-9 | Each zone has `player_id`, `col_start`, `col_end`, `row_start`, `row_end`. |
| deployment_row_min | int | yes | 2 | Enforces row distribution (>=2 distinct rows). |
| bounds_policy | string | yes | strict | Enum: strict (no out-of-bounds). |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Referenced by [MatchState](#matchstate) as the active board.
- Home zones used by [PlayerState](#playerstate) and deployment validation via [Command](#command).

**Versioning & Migration**
- v1.0.0 initial grid definition for 15x9 with two home zones.
- Migration skeleton: add new layouts by new ids; avoid in-place mutation; provide mapping for legacy ids if resized.

**Traceability**
- Requirements: GR-001, GR-012, GR-032, GR-032.1, DA-001.
- Architecture: State Model, Validator (Deployment/Bounds), LoS/Range Calculator (bounds), Persistence Service.

**Sync Strategy**
- JSON is authoritative; Godot resource generated as `.tres` or `.res` baked grid settings; cache in Data Layer.

**Open Questions / TODOs**
- None currently; future: support asymmetric or scenario-specific zones.

**Example JSON**
```json
{
  "id": "standard_15x9",
  "name": "Standard 15x9",
  "columns": 15,
  "rows": 9,
  "home_zones": [
    {"player_id": "P1", "col_start": 1, "col_end": 2, "row_start": 1, "row_end": 9},
    {"player_id": "P2", "col_start": 14, "col_end": 15, "row_start": 1, "row_end": 9}
  ],
  "deployment_row_min": 2,
  "bounds_policy": "strict",
  "version": "1.0.0"
}
```

---

## TerrainTemplate
[Back to TOC](#linked-table-of-contents)
**Purpose:** Configures terrain piece generation and rules flags for LoS, cover, and movement.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique terrain template id. |
| name | string | yes | - | Human-readable label. |
| size_range | object | yes | {"min":1,"max":4} | Square count; aligns to grid cells. |
| blocks_los | bool | yes | true | Default from GR-003. |
| provides_cover | bool | yes | true | Default from GR-003. |
| impassable | bool | yes | true | Default from GR-003. |
| placement_weight | int | yes | 1 | Relative weight for random placement counts 3–5. |
| flags | object | no | {} | Future per-piece flags (e.g., climbable). |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Instances embedded within [MatchState](#matchstate) terrain placements.
- Used by Validator for movement/LoS checks referenced in [Command](#command).

**Versioning & Migration**
- v1.0.0 baseline flags; adding new flags is additive; changes to defaults require migration rule to preserve behavior.

**Traceability**
- Requirements: GR-002, GR-003, GR-004, GR-018, GR-031, DA-004, DA-005, DA-021.
- Architecture: Data Layer (terrain configs), Validator (movement/LoS), LoS/Range Calculator.

**Sync Strategy**
- JSON authoritative; generate Godot `Resource` for terrain presets; ensure flags map to collision/occlusion layers.

**Open Questions / TODOs**
- Specify corner-cutting rule tuning per template? Currently uniform.

**Example JSON**
```json
{
  "id": "blocking_rock",
  "name": "Blocking Rock",
  "size_range": {"min": 1, "max": 3},
  "blocks_los": true,
  "provides_cover": true,
  "impassable": true,
  "placement_weight": 2,
  "flags": {},
  "version": "1.0.0"
}
```

---

## MissionDefinition
[Back to TOC](#linked-table-of-contents)
**Purpose:** Encodes mission objectives, control zones, scoring cadence, and uniqueness constraints. Center-band missions (Control Center, Dead Zone) use the full vertical band: columns 7–9, rows 1–9.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique mission id. |
| name | string | yes | - | Mission label. |
| mission_type | string | yes | - | Enum: crossfire_clash, control_center, break_through, dead_center, dead_zone, occupy. |
| control_zones | array\<Zone\> | no | [] | Column/row ranges; empty for kill missions. |
| scoring_rules | object | yes | - | Contains `timing` (per_round_end), `points` map, bonuses. |
| round_limit | int | yes | 6 | Base limit before tie extension. |
| max_extra_rounds | int | yes | 1 | Single 7th round per GR-035/GR-043; cap total rounds at 7. |
| unique_per_campaign | bool | yes | true | Enforces GR-039/DA-015. |
| notes | string | no | "" | Bonuses (sector B +1, nearest sector +3). |
| version | string | yes | 1.1.0 | Semantic per-entity version. |

**Relationships**
- Referenced by [MatchState](#matchstate); scored by Mission/Scoring Engine.
- [CampaignState](#campaignstate) tracks used missions to enforce uniqueness.

**Versioning & Migration**
- v1.1.0 caps extra rounds at one (maximum 7 total rounds) to align with GR-035/GR-043; migrate by clamping `max_extra_rounds` to 1.
- v1.0.0 includes six missions; adding missions is additive; changing scoring requires migration rule to preserve legacy saves.

**Traceability**
- Requirements: GR-033–GR-035.1, DA-008, DA-009, DA-015, DA-016, DA-017.
- Architecture: Mission/Scoring Engine, Validator (control evaluation), Persistence Service.

**Sync Strategy**
- JSON authoritative; Godot resource mirrors zones/labels for UI; ensure control zones map to grid coordinates.

**Open Questions / TODOs**
- None; future campaign-specific variants may need additional fields.

**Example JSON**
```json
{
  "id": "occupy",
  "name": "Occupy",
  "mission_type": "occupy",
  "control_zones": [
    {"id": "A", "col_start": 3, "col_end": 6, "row_start": 1, "row_end": 9, "bonus_points": 0},
    {"id": "B", "col_start": 7, "col_end": 9, "row_start": 1, "row_end": 9, "bonus_points": 1},
    {"id": "C", "col_start": 10, "col_end": 13, "row_start": 1, "row_end": 9, "bonus_points": 0}
  ],
  "scoring_rules": {
    "timing": "per_round_end",
    "points": {"control": 1, "nearest_opponent_bonus": 3}
  },
  "round_limit": 6,
  "max_extra_rounds": 1,
  "unique_per_campaign": true,
  "notes": "Sector nearest opponent grants +3 (A for P2, C for P1); sector B +1.",
  "version": "1.1.0"
}
```

---

## FactionDefinition
[Back to TOC](#linked-table-of-contents)
**Purpose:** Declares faction-level stats, roster limits, and special rules that apply to all of its units.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique faction id. |
| name | string | yes | - | Display label. |
| roster_limit | int | yes | 5 | Solar Wardens override to 4 (GR-006). |
| base_stats | object | yes | - | `{move, range, aq, defense}` integers or dice spec. |
| movement_mode | string | yes | "fixed" | "fixed" or "roll_per_move" (Solar). |
| traits | array\<string\> | no | [] | e.g., "azure_melee_aq_bonus", "grey_reroll", "solar_deadly_rounds". |
| notes | string | no | "" | Narrative or edge-case description. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Referenced by [PlayerState](#playerstate) and [UnitTemplate](#unittemplate).
- Impacts Validator/Resolver behavior per faction rules.

**Versioning & Migration**
- v1.0.0 covers five factions; add new factions additively; stat changes require migration guidance for saved rosters.

**Traceability**
- Requirements: GR-005–GR-011, GR-008–GR-011 specifics, DA-011, DA-018.
- Architecture: Data Layer, Validator (faction rules), Resolver (attack/melee modifiers).

**Sync Strategy**
- JSON authoritative; Godot resource per faction for UI/selection; ensure traits map to rule handlers.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "solar_wardens",
  "name": "Solar Wardens",
  "roster_limit": 4,
  "base_stats": {"move": "1d6", "range": 4, "aq": 1, "defense": 9},
  "movement_mode": "roll_per_move",
  "traits": ["solar_deadly_rounds", "random_move"],
  "notes": "Deadly rounds on natural 11/12; move is rolled each Move action.",
  "version": "1.0.0"
}
```

---

## UnitTemplate
[Back to TOC](#linked-table-of-contents)
**Purpose:** Defines unit archetypes linked to factions, enabling future variants while reusing faction rules.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique template id. |
| name | string | yes | - | Display label. |
| faction_id | string | yes | - | References [FactionDefinition](#factiondefinition). |
| stats | object | no | null | Optional overrides to faction `base_stats`. |
| abilities | array\<string\> | no | [] | Specific unit abilities; empty now. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Used by [PlayerState](#playerstate) to assemble rosters.
- Instances produce [UnitState](#unitstate).

**Versioning & Migration**
- v1.0.0 generic archetype; adding variants is additive; changing stats should include migration advice for existing rosters.

**Traceability**
- Requirements: GR-005–GR-011 (via faction mapping), DA-011.
- Architecture: Data Layer, State Model (unit roster), Validator/Resolver (stats).

**Sync Strategy**
- JSON authoritative; Godot resource per unit archetype for UI icons/names; stats resolved in engine from JSON.

**Open Questions / TODOs**
- None; future: dedicated commander units if rules expand.

**Example JSON**
```json
{
  "id": "ve_rifle",
  "name": "Verdant Rifle",
  "faction_id": "verdant_eye",
  "stats": null,
  "abilities": [],
  "version": "1.0.0"
}
```

---

## PlayerState
[Back to TOC](#linked-table-of-contents)
**Purpose:** Captures per-player match setup, roster, advantages, and toggles impacting validation and resolution.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| player_id | string | yes | - | "P1"/"P2". |
| faction_id | string | yes | - | References [FactionDefinition](#factiondefinition). |
| roster | array\<string\> | yes | - | List of [UnitState](#unitstate) ids. |
| activation_limit | int | yes | 4 | From GR-016. |
| advantages | array\<string\> | no | [] | Selected [AdvantageOption](#advantageoption) ids. |
| commander_trait | string | no | null | Optional [CommanderTrait](#commandertrait) id. |
| optional_rules_enabled | object | yes | {"commander":false,"events":false,"campaign":false} | Mirrors [OptionalRulesConfig](#optionalrulesconfig). |
| campaign_score | int | no | 0 | Used in campaigns. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Contains roster of [UnitState](#unitstate).
- References [FactionDefinition](#factiondefinition), [AdvantageOption](#advantageoption), [CommanderTrait](#commandertrait).
- Included within [MatchState](#matchstate).

**Versioning & Migration**
- v1.0.0 initial; adding fields (e.g., loadouts) is additive; changes to activation limits require migration rule to preserve historical battles.

**Traceability**
- Requirements: GR-006, GR-012, GR-015–GR-017, GR-040, GR-041, DA-010, DA-017, DA-019.
- Architecture: State Model (player state), Campaign Manager, Validator (activation limits).

**Sync Strategy**
- JSON authoritative; Godot resource for menu binding; activation limits enforced in Rules Engine from JSON values.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "player_id": "P1",
  "faction_id": "azure_blades",
  "roster": ["unit_p1_1", "unit_p1_2", "unit_p1_3", "unit_p1_4", "unit_p1_5"],
  "activation_limit": 4,
  "advantages": [],
  "commander_trait": null,
  "optional_rules_enabled": {"commander": false, "events": false, "campaign": false},
  "campaign_score": 0,
  "version": "1.0.0"
}
```

---

## UnitState
[Back to TOC](#linked-table-of-contents)
**Purpose:** Represents an individual unit instance on the board, including position, status, and activation tracking.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique unit instance id. |
| template_id | string | yes | - | References [UnitTemplate](#unittemplate). |
| owner_id | string | yes | - | References [PlayerState](#playerstate). |
| position | object | yes | - | `{col,row}`; must be within [BoardLayout](#boardlayout) bounds. |
| status | string | yes | alive | Enum: alive, down, destroyed. |
| activations_used | int | yes | 0 | Max 1 per round; tracked per round. |
| has_moved_this_activation | bool | yes | false | Supports half-move rules. |
| cover_state | string | yes | none | Enum: none, cover. |
| rerolls_available | int | yes | 0 | For Grey Cloaks and bonuses. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Instantiated within [MatchState](#matchstate); owned by [PlayerState](#playerstate).
- Targeted by [Command](#command) actions; status affects Validator/Resolver.

**Versioning & Migration**
- v1.0.0 baseline; adding wounds or equipment would be additive; status enum changes require migration mapping.

**Traceability**
- Requirements: GR-015–GR-030, GR-032, GR-032.1, GR-045, DA-003, DA-007, DA-012, DA-018, DA-021.
- Architecture: State Model, Validator (activation/down checks), Resolver (combat outcomes).

**Sync Strategy**
- JSON authoritative; Godot resource for runtime state mirrors but reconstructed from JSON on load; deterministic snapshotting.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "unit_p1_1",
  "template_id": "azure_blades_basic",
  "owner_id": "P1",
  "position": {"col": 2, "row": 5},
  "status": "alive",
  "activations_used": 0,
  "has_moved_this_activation": false,
  "cover_state": "cover",
  "rerolls_available": 1,
  "version": "1.0.0"
}
```

---

## RoundState
[Back to TOC](#linked-table-of-contents)
**Purpose:** Tracks round progression, initiative outcomes, activation batches, and mission scoring state.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| round_number | int | yes | 1 | 1–7 per rules; the 7th occurs only when tied after round 6. |
| initiative_rolls | object | yes | - | `{P1: int, P2: int}` last rolled values. |
| initiative_winner | string | yes | - | "P1"/"P2". |
| first_activation_choice | string | yes | first | "first" or "pass" (opponent activates). |
| remaining_batches | array\<object\> | yes | [] | Batches of two activations alternating after first. |
| extra_rounds_remaining | int | yes | 1 | Tracks whether the single tie-triggered 7th round remains. |
| mission_points_this_round | object | yes | {"P1": 0, "P2": 0} | Per-player mission points earned in the current round; must match UI display. |
| battle_points_total | object | yes | {"P1": 0, "P2": 0} | Running per-battle mission totals feeding campaign calculations. |
| version | string | yes | 1.2.0 | Semantic per-entity version. |

**Relationships**
- Embedded in [MatchState](#matchstate); referenced by Validator to enforce activation flow.
- Mission and battle points are surfaced to UI overlays and campaign calculators.

**Versioning & Migration**
- v1.2.0 caps rounds at a single extra 7th round; migrate by clamping `round_number` to a maximum of 7 and setting `extra_rounds_remaining` to `min(existing, 1)`.
- v1.1.0 adds mission and cumulative battle point tracking; migrate by defaulting missing objects to `{P1: 0, P2: 0}` when loading older saves.

**Traceability**
- Requirements: GR-013–GR-016, GR-033–GR-035.1, GR-038, GR-043–GR-044, DA-002, DA-003, DA-009, DA-016, DA-017.
- Architecture: Command Bus & Game Loop, Validator (activation order).

**Sync Strategy**
- JSON authoritative; UI reads snapshots from Rules Engine; Godot resource optional for save visuals.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "round_number": 3,
  "initiative_rolls": {"P1": 4, "P2": 6},
  "initiative_winner": "P2",
  "first_activation_choice": "first",
  "remaining_batches": [
    {"player_id": "P2", "remaining": 2},
    {"player_id": "P1", "remaining": 2}
  ],
  "extra_rounds_remaining": 1,
  "mission_points_this_round": {"P1": 1, "P2": 2},
  "battle_points_total": {"P1": 5, "P2": 6},
  "version": "1.2.0"
}
```

---

## Command
[Back to TOC](#linked-table-of-contents)
**Purpose:** Serialisable player action used for validation, resolution, replay, and future networking.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique command id. |
| sequence | int | yes | - | Strictly increasing order. |
| type | string | yes | - | Enum: deploy, move, attack, melee, first_aid, hold, reroll, advantage_use, event_use, quick_start_move. |
| actor_unit_id | string | no | null | Required for unit actions. |
| target_unit_id | string | no | null | Optional. |
| payload | object | no | {} | E.g., path for move, target cell, reroll die selection. |
| rng_offset_before | int | yes | 0 | Offset snapshot before executing command. |
| timestamp | string | no | null | ISO8601 for logs; not used for determinism. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Stored in [CommandLog](#commandlog).
- Applied to [MatchState](#matchstate); validated by Validator and resolved by Rules Engine.

**Versioning & Migration**
- v1.0.0 supports current command set; future commands added with new enum values; old commands remain valid. Migrations map deprecated types to new payloads if needed.

**Traceability**
- Requirements: GR-012–GR-031, GR-040–GR-045, DA-001–DA-021, MP-001–MP-005.
- Architecture: Command Bus, Validator, Resolver, Networking Adapter (future).

**Sync Strategy**
- JSON authoritative; Godot command DTOs generated from JSON; used for replay and MP replication.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "cmd_102",
  "sequence": 102,
  "type": "attack",
  "actor_unit_id": "unit_p1_1",
  "target_unit_id": "unit_p2_3",
  "payload": {"target_cell": {"col": 8, "row": 5}, "half_move_used": true},
  "rng_offset_before": 235,
  "timestamp": "2025-11-25T12:34:56Z",
  "version": "1.0.0"
}
```

---

## CommandLog
[Back to TOC](#linked-table-of-contents)
**Purpose:** Ordered collection of commands with integrity data for replay and saves.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique log id. |
| commands | array\<Command\> | yes | [] | Ordered by `sequence`. |
| hash | string | no | null | Optional checksum for tamper detection. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Referenced by [MatchState](#matchstate); supports Persistence Service and replay.
- Uses [Command](#command) items.

**Versioning & Migration**
- v1.0.0 baseline; adding compression or chunking is additive; maintain backward-compatible command list.

**Traceability**
- Requirements: DA-013, MP-001–MP-006, AQ-003, AQ-004.
- Architecture: Command Bus, Persistence Service, Networking Adapter.

**Sync Strategy**
- JSON authoritative; Godot may store as external `.json` for large logs; hash validated on load.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "log_match_12",
  "commands": [
    {"id": "cmd_1", "sequence": 1, "type": "deploy", "actor_unit_id": "unit_p1_1", "payload": {"position": {"col": 1, "row": 3}}, "rng_offset_before": 0, "version": "1.0.0"},
    {"id": "cmd_2", "sequence": 2, "type": "deploy", "actor_unit_id": "unit_p2_1", "payload": {"position": {"col": 15, "row": 3}}, "rng_offset_before": 0, "version": "1.0.0"}
  ],
  "hash": "sha256:abc123",
  "version": "1.0.0"
}
```

---

## RNGSeed
[Back to TOC](#linked-table-of-contents)
**Purpose:** Stores deterministic random seed and offset snapshot for reproducible simulations and replays.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| seed | string | yes | - | Seed string or int; persisted. |
| offset | int | yes | 0 | Number of RNG calls consumed. |
| last_roll | object | no | null | Optional last roll snapshot for debugging. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Embedded in [MatchState](#matchstate) and [CampaignState](#campaignstate) (per battle).
- Referenced by [Command](#command) via `rng_offset_before`.

**Versioning & Migration**
- v1.0.0 baseline; additional RNG streams (e.g., UI-only) would add fields.

**Traceability**
- Requirements: AQ-004, MP-005, DA-006 (logs), MP-006.
- Architecture: RNG Service, Persistence Service.

**Sync Strategy**
- JSON authoritative; Godot RNG initialized from JSON seed/offset before replay.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "seed": "match_seed_2025_11_25",
  "offset": 42,
  "last_roll": {"type": "2d6", "values": [5, 3]},
  "version": "1.0.0"
}
```

---

## MatchState
[Back to TOC](#linked-table-of-contents)
**Purpose:** Complete snapshot of a single battle, combining board, terrain, mission, players, units, round, RNG, and command log.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique match id. |
| board_layout_id | string | yes | standard_15x9 | References [BoardLayout](#boardlayout). |
| terrain | array\<object\> | yes | [] | Each instance: `template_id`, `cells` list. |
| mission_id | string | yes | - | References [MissionDefinition](#missiondefinition). |
| optional_rules | object | yes | {"commander":false,"events":false,"campaign":false} | Mirrors [OptionalRulesConfig](#optionalrulesconfig). |
| battle_event_id | string | no | null | References [BattleEvent](#battleevent) when enabled. |
| player_states | array\<PlayerState\> | yes | [] | Two entries. |
| unit_states | array\<UnitState\> | yes | [] | All units on board. |
| round_state | object | yes | - | [RoundState](#roundstate). |
| rng | object | yes | - | [RNGSeed](#rngseed). |
| command_log_id | string | yes | - | References [CommandLog](#commandlog). |
| status | string | yes | active | Enum: active, completed. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Aggregates [BoardLayout](#boardlayout), [TerrainTemplate](#terraintemplate) instances, [MissionDefinition](#missiondefinition), [PlayerState](#playerstate), [UnitState](#unitstate), [RoundState](#roundstate), [CommandLog](#commandlog), [RNGSeed](#rngseed), [BattleEvent](#battleevent), [OptionalRulesConfig](#optionalrulesconfig).
- Linked to [SaveSlot](#saveslot) for persistence.

**Versioning & Migration**
- v1.0.0 baseline; migration strategy: add fields additively; when removing/changing enums, supply mapping; store per-field defaults to allow forward/backward compatibility.

**Traceability**
- Requirements: GR-001–GR-045, DA-001–DA-021, CP-005, MP-001–MP-006, AQ-001–AQ-007.
- Architecture: State Model, Persistence Service, Command Bus, Networking Adapter (future).

**Sync Strategy**
- JSON authoritative save; Godot runtime state reconstructed from JSON; `.tres` mirrors for editor previews optional.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "match_12",
  "board_layout_id": "standard_15x9",
  "terrain": [
    {"template_id": "blocking_rock", "cells": [{"col": 5, "row": 4}, {"col": 5, "row": 5}]}
  ],
  "mission_id": "occupy",
  "optional_rules": {"commander": false, "events": false, "campaign": true},
  "battle_event_id": null,
  "player_states": [
    {"player_id": "P1", "faction_id": "azure_blades", "roster": ["unit_p1_1"], "activation_limit": 4, "advantages": [], "commander_trait": null, "optional_rules_enabled": {"commander": false, "events": false, "campaign": true}, "campaign_score": 3, "version": "1.0.0"},
    {"player_id": "P2", "faction_id": "ember_guard", "roster": ["unit_p2_1"], "activation_limit": 4, "advantages": [], "commander_trait": null, "optional_rules_enabled": {"commander": false, "events": false, "campaign": true}, "campaign_score": 4, "version": "1.0.0"}
  ],
  "unit_states": [
    {"id": "unit_p1_1", "template_id": "azure_blades_basic", "owner_id": "P1", "position": {"col": 2, "row": 3}, "status": "alive", "activations_used": 0, "has_moved_this_activation": false, "cover_state": "none", "rerolls_available": 1, "version": "1.0.0"}
  ],
  "round_state": {"round_number": 1, "initiative_rolls": {"P1": 6, "P2": 3}, "initiative_winner": "P1", "first_activation_choice": "first", "remaining_batches": [{"player_id": "P1", "remaining": 2}, {"player_id": "P2", "remaining": 2}], "extra_rounds_remaining": 1, "mission_points_this_round": {"P1": 1, "P2": 0}, "battle_points_total": {"P1": 1, "P2": 0}, "version": "1.2.0"},
  "rng": {"seed": "match_seed_2025_11_25", "offset": 5, "last_roll": {"type": "d6", "values": [6]}, "version": "1.0.0"},
  "command_log_id": "log_match_12",
  "status": "active",
  "version": "1.0.0"
}
```

---

## CampaignState
[Back to TOC](#linked-table-of-contents)
**Purpose:** Tracks campaign lifecycle, scores, missions used, and selected advantages across battles.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique campaign id. |
| length | int | yes | 3 | 3–5 (1d3 + 2). |
| current_battle | int | yes | 1 | 1-based index. |
| missions_used | array\<string\> | yes | [] | References [MissionDefinition](#missiondefinition) ids. |
| cumulative_scores | object | yes | {"P1":0,"P2":0} | Per player. |
| advantages_history | array\<object\> | yes | [] | Each entry: battle index, player_id, advantage_id. |
| current_match_id | string | no | null | References active [MatchState](#matchstate). |
| rng | object | yes | - | [RNGSeed](#rngseed) for campaign-level rolls. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- References [MissionDefinition](#missiondefinition), [AdvantageOption](#advantageoption), [MatchState](#matchstate), [RNGSeed](#rngseed).
- Used by Persistence Service and Campaign Manager.

**Versioning & Migration**
- v1.0.0 baseline; adding campaign modifiers is additive; mission uniqueness rules should remain stable to avoid migration complexity.

**Traceability**
- Requirements: GR-036–GR-040, DA-009, DA-015, DA-016, DA-017.
- Architecture: Campaign Manager, Persistence Service, Command Bus (for battle selection), RNG Service.

**Sync Strategy**
- JSON authoritative; Godot campaign save resource mirrors JSON; mission uniqueness validated on load.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "campaign_5",
  "length": 4,
  "current_battle": 2,
  "missions_used": ["occupy"],
  "cumulative_scores": {"P1": 3, "P2": 4},
  "advantages_history": [
    {"battle": 2, "player_id": "P2", "advantage_id": "tactical_edge"}
  ],
  "current_match_id": "match_12",
  "rng": {"seed": "campaign_seed_2025_11_25", "offset": 7, "last_roll": null, "version": "1.0.0"},
  "version": "1.0.0"
}
```

---

## AdvantageOption
[Back to TOC](#linked-table-of-contents)
**Purpose:** Defines Winner’s Advantage options and their usage constraints.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique advantage id. |
| name | string | yes | - | Display label. |
| effect | string | yes | - | Description of rules effect. |
| usage_timing | string | yes | pre_round | Timing: pre_round, per_round, once_per_battle. |
| limits | object | yes | {"per_battle":1} | Enforces single selection per winner. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Selected in [CampaignState](#campaignstate); referenced in [PlayerState](#playerstate) advantages list.

**Versioning & Migration**
- v1.0.0 includes Tactical Edge, Quick Start, Focused Orders; adding new advantages is additive.

**Traceability**
- Requirements: GR-040, DA-017, DA-019, DA-020, DA-018.
- Architecture: Campaign Manager, Validator (usage enforcement), Resolver (effects).

**Sync Strategy**
- JSON authoritative; Godot resource for UI selection; effect mapping handled in rules engine.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "quick_start",
  "name": "Quick Start",
  "effect": "Before round 1, move two units up to full Move; cannot attack.",
  "usage_timing": "pre_round",
  "limits": {"per_battle": 1},
  "version": "1.0.0"
}
```

---

## CommanderTrait
[Back to TOC](#linked-table-of-contents)
**Purpose:** Optional commander traits that modify targeting or survivability.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique trait id. |
| name | string | yes | - | Display label. |
| effect | string | yes | - | Rules effect text. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Referenced by [PlayerState](#playerstate) when commander rules enabled.

**Versioning & Migration**
- v1.0.0 includes Resilient, Sniper, Stealth; new traits additively added; keep legacy ids stable.

**Traceability**
- Requirements: GR-041, DA-010, DA-020.
- Architecture: Optional Rules Toggles, Validator/Resolver effect hooks.

**Sync Strategy**
- JSON authoritative; Godot resource for UI; effect mapping handled in rules engine.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "stealth",
  "name": "Stealth",
  "effect": "Cannot be targeted if in cover.",
  "version": "1.0.0"
}
```

---

## BattleEvent
[Back to TOC](#linked-table-of-contents)
**Purpose:** Optional pre-game events that modify rules for the battle.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique event id. |
| name | string | yes | - | Display label. |
| effect | string | yes | - | Rules effect text. |
| trigger | string | yes | pre_game | Timing enum. |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Referenced in [MatchState](#matchstate) when events enabled.

**Versioning & Migration**
- v1.0.0 includes six events; new events additive; keep existing ids stable.

**Traceability**
- Requirements: GR-042, DA-010, DA-019, DA-020.
- Architecture: Optional Rules Toggles, Validator/Resolver effect hooks.

**Sync Strategy**
- JSON authoritative; Godot resource for UI selection; rules engine applies effect by id.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "fog_of_war",
  "name": "Fog of War",
  "effect": "Max shoot range 3.",
  "trigger": "pre_game",
  "version": "1.0.0"
}
```

---

## OptionalRulesConfig
[Back to TOC](#linked-table-of-contents)
**Purpose:** Toggles optional systems to keep core deterministic engine modular.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| commander | bool | yes | false | Enables [CommanderTrait](#commandertrait). |
| events | bool | yes | false | Enables [BattleEvent](#battleevent). |
| campaign | bool | yes | false | Enables [CampaignState](#campaignstate). |
| version | string | yes | 1.0.0 | Semantic per-entity version. |

**Relationships**
- Embedded in [MatchState](#matchstate) and [PlayerState](#playerstate).

**Versioning & Migration**
- v1.0.0 baseline; adding future toggles is additive.

**Traceability**
- Requirements: GR-041–GR-042, GR-036–GR-040, DA-010, AQ-006.
- Architecture: Optional Rules module, Validator gating logic.

**Sync Strategy**
- JSON authoritative; Godot UI binds to toggles; rules engine respects flags at load.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "commander": false,
  "events": true,
  "campaign": true,
  "version": "1.0.0"
}
```

---

## SaveSlot
[Back to TOC](#linked-table-of-contents)
**Purpose:** Metadata for local save files to enforce size, integrity, and slot policies.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique slot id. |
| slot_name | string | yes | - | Display name. |
| slot_type | string | yes | match | Enum: match, campaign. |
| linked_id | string | yes | - | References [MatchState](#matchstate) or [CampaignState](#campaignstate). |
| version | string | yes | 1.0.0 | Save schema version. |
| checksum | string | no | null | Integrity check. |
| size_bytes | int | no | 0 | For size budgeting. |
| updated_at | string | yes | - | ISO8601 timestamp. |
| storage_path | string | yes | - | Local path. |

**Relationships**
- Points to [MatchState](#matchstate) or [CampaignState](#campaignstate).
- Managed by Persistence Service.

**Versioning & Migration**
- v1.0.0 baseline; adding cloud sync metadata is additive.

**Traceability**
- Requirements: CP-005, CP-007, DA-009, MP-006; Architecture Persistence policies.

**Sync Strategy**
- JSON metadata authoritative; Godot filesystem mirrors path; checksum validated on load.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "slot_01",
  "slot_name": "Campaign Slot 1",
  "slot_type": "campaign",
  "linked_id": "campaign_5",
  "version": "1.0.0",
  "checksum": "sha256:def456",
  "size_bytes": 15234,
  "updated_at": "2025-11-25T12:40:00Z",
  "storage_path": "saves/campaign_5.json"
}
```

---

## MapPreset
[Back to TOC](#linked-table-of-contents)
**Purpose:** (Future) Named terrain layouts or constraints beyond random placement.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique preset id. |
| name | string | yes | - | Display label. |
| board_layout_id | string | yes | standard_15x9 | References [BoardLayout](#boardlayout). |
| terrain_instances | array\<object\> | yes | [] | Fixed placements referencing [TerrainTemplate](#terraintemplate). |
| version | string | yes | 0.1.0 | Pre-release optional entity. |

**Relationships**
- Alternative to random terrain in [MatchState](#matchstate).

**Versioning & Migration**
- 0.1.0 experimental; formalize when adopted.

**Traceability**
- Requirements: GR-002 (optional customization), DA-004 (previews).
- Architecture: Data Layer extension.

**Sync Strategy**
- JSON authoritative; Godot `.tres` for editor convenience.

**Open Questions / TODOs**
- Not in scope now; confirm inclusion later.

**Example JSON**
```json
{
  "id": "dense_center",
  "name": "Dense Center",
  "board_layout_id": "standard_15x9",
  "terrain_instances": [
    {"template_id": "blocking_rock", "cells": [{"col": 7, "row": 5}, {"col": 8, "row": 5}]}
  ],
  "version": "0.1.0"
}
```

---

## Loadout
[Back to TOC](#linked-table-of-contents)
**Purpose:** (Future) Unit equipment/customization without altering core faction stats.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique loadout id. |
| name | string | yes | - | Display label. |
| stat_modifiers | object | no | {} | Optional adjustments to stats. |
| abilities | array\<string\> | no | [] | Additional abilities. |
| version | string | yes | 0.1.0 | Pre-release optional entity. |

**Relationships**
- Would attach to [UnitTemplate](#unittemplate) or [UnitState](#unitstate).

**Versioning & Migration**
- 0.1.0 placeholder; not enabled yet.

**Traceability**
- Requirements: None current; future expansion.
- Architecture: Data Layer extensibility.

**Sync Strategy**
- JSON authoritative; not used yet.

**Open Questions / TODOs**
- Await design approval before enabling.

**Example JSON**
```json
{
  "id": "scope_upgrade",
  "name": "Scoped Optics",
  "stat_modifiers": {"range": 1},
  "abilities": ["improved_los"],
  "version": "0.1.0"
}
```

---

## AIProfile
[Back to TOC](#linked-table-of-contents)
**Purpose:** (Future) Bot behavior parameters using the same command stream as players.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique profile id. |
| name | string | yes | - | Display label. |
| priorities | object | yes | {} | Weights for objectives (kill, control, survive). |
| risk_tolerance | string | yes | medium | Enum low/medium/high. |
| version | string | yes | 0.1.0 | Pre-release optional entity. |

**Relationships**
- Could be referenced by [PlayerState](#playerstate) when AI-controlled.

**Versioning & Migration**
- 0.1.0 placeholder; expand when AI is added.

**Traceability**
- Requirements: None current; aligns with architecture Command Bus compatibility.

**Sync Strategy**
- JSON authoritative; not used yet.

**Open Questions / TODOs**
- Define when AI is prioritized.

**Example JSON**
```json
{
  "id": "balanced_ai",
  "name": "Balanced AI",
  "priorities": {"kill": 1, "control": 1, "survive": 1},
  "risk_tolerance": "medium",
  "version": "0.1.0"
}
```

---

## NetworkingSession
[Back to TOC](#linked-table-of-contents)
**Purpose:** (Future) Metadata for multiplayer sessions to align command replication and state sync.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| session_id | string | yes | - | Unique session id. |
| match_id | string | yes | - | References [MatchState](#matchstate). |
| host | string | yes | - | Host peer id/address. |
| peers | array\<string\> | yes | [] | Connected peer ids. |
| state_hash | string | yes | - | Latest authoritative hash. |
| version | string | yes | 0.1.0 | Pre-release optional entity. |

**Relationships**
- Wraps [MatchState](#matchstate) for networking adapter.

**Versioning & Migration**
- 0.1.0 placeholder; extend when MP built.

**Traceability**
- Requirements: MP-001–MP-006.
- Architecture: Networking Adapter (future).

**Sync Strategy**
- JSON authoritative for session metadata; not persisted locally until MP enabled.

**Open Questions / TODOs**
- None until MP is greenlit.

**Example JSON**
```json
{
  "session_id": "net_001",
  "match_id": "match_12",
  "host": "peer_host",
  "peers": ["peer_host", "peer_client"],
  "state_hash": "hash123",
  "version": "0.1.0"
}
```

---

## CosmeticSkin
[Back to TOC](#linked-table-of-contents)
**Purpose:** (Future) Visual customization decoupled from rules.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique skin id. |
| name | string | yes | - | Display label. |
| resource_path | string | yes | - | Godot path to visuals. |
| version | string | yes | 0.1.0 | Pre-release optional entity. |

**Relationships**
- Could attach to [UnitTemplate](#unittemplate) or UI only.

**Versioning & Migration**
- 0.1.0 placeholder; safe to ignore in logic.

**Traceability**
- Requirements: None; UI polish only.

**Sync Strategy**
- JSON authoritative; Godot resources supply visuals; no rules impact.

**Open Questions / TODOs**
- None.

**Example JSON**
```json
{
  "id": "azure_skin_01",
  "name": "Azure Heroic",
  "resource_path": "res://skins/azure_heroic.tres",
  "version": "0.1.0"
}
```

---

## TelemetryEvent
[Back to TOC](#linked-table-of-contents)
**Purpose:** (Future) Structured analytics/log export beyond mandatory rules logging.

**Schema**
| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| id | string | yes | - | Unique event id. |
| event_type | string | yes | - | Enum of telemetry categories. |
| payload | object | yes | {} | Arbitrary telemetry data. |
| anonymized | bool | yes | true | Must avoid PII. |
| version | string | yes | 0.1.0 | Pre-release optional entity. |

**Relationships**
- Optional export from [CommandLog](#commandlog) or game sessions.

**Versioning & Migration**
- 0.1.0 placeholder; only used if telemetry is added.

**Traceability**
- Requirements: None; optional analytics.
- Architecture: Cross-Cutting Services (Logging/Telemetry).

**Sync Strategy**
- JSON authoritative; off by default.

**Open Questions / TODOs**
- Remains disabled unless telemetry approved.

**Example JSON**
```json
{
  "id": "telemetry_match_start",
  "event_type": "match_start",
  "payload": {"factions": ["azure_blades", "ember_guard"], "mission": "occupy"},
  "anonymized": true,
  "version": "0.1.0"
}
```

---

## Validation & Gap Analysis
[Back to TOC](#linked-table-of-contents)
- Coverage: Required entities back all rule-bearing requirements (GR-001–GR-045), digital UX (DA-001–DA-021), campaign/advantages (GR-036–GR-040), optional commander/events (GR-041–GR-042), persistence (CP-005–CP-007), determinism/replay (AQ-003–AQ-004, MP-001–MP-006). Command/RNGSeed/CommandLog ensure replay and MP readiness; MatchState/CampaignState/SaveSlot ensure save/resume.
- Normalization: Shared flags centralized in OptionalRulesConfig; advantages, commanders, and events separated to avoid coupling; faction stats and unit templates split for future variants; terrain templates reused across maps.
- No redundancies detected; optional entities remain dormant until needed.
- Gaps: None blocking; MapPreset/Loadout/AIProfile/NetworkingSession/TelemetryEvent marked optional for future; LoS masks treated as derived/cache (not stored).

---

## Summary & Evaluation
[Back to TOC](#linked-table-of-contents)
- Overall model: Data-driven configs for factions, missions, terrain, advantages, optional rules, and deterministic match/campaign state with command/RNG logging; JSON is source of truth with Godot resources mirrored for runtime/UI.
- Strengths: Full requirement/architecture alignment; deterministic replay via Command+RNGSeed+CommandLog; modular toggles keep core clean; clear versioning per entity; migration guidance preserves compatibility; examples provided for all entities.
- Weaknesses: Optional/future entities are placeholders until designed; MapPreset/loadouts need design before activation; no persisted LoS caches (derived only) may require compute on load.
- Coverage: Entities cover GR/DA/CP/AQ/MP mappings; campaign uniqueness and Winner’s Advantage encoded; save-slot metadata honors size/integrity guidance.
- Testability: Deterministic seeds and command logs support golden tests; schemas map cleanly to Validator/Resolver seams described in architecture.
- Maintainability & migration readiness: Per-entity semantic versions enable targeted updates; additive patterns recommended; anchors stable for agentic updates. Unspecified items: finalize any future map presets and equipment before enabling; confirm telemetry policy before emitting events.
