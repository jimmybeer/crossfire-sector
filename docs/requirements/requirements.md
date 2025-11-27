# Scope & Assumptions
- Digital adaptation of “Crossfire Sector” for two-player local play on computer and mobile; architecture prepared for online multiplayer later. Faithful adaptation means all tabletop rules in `rules.md` are enforced with identical probabilities, sequencing, and constraints.
- Assumptions: terrain defaults (blocking LoS, providing cover, impassable) are applied uniformly unless future per-piece flags are configured; simultaneous decisions (deployment, initiative choices) are captured via sequential confirmations; optional rules (Commander, Battle Events, Campaign) are off unless chosen.

# Definitions
- Unit: A single model with stats Move, Range, Attack Quality (AQ), Defense, and faction traits.
- Home zone: Player 1 deploys in columns 1–2, rows 1–9; Player 2 in columns 14–15, rows 1–9.
- Down: State where a unit is incapacitated but not destroyed.
- Mission: Win condition chosen/rolled at battle start.
- Cover: Terrain that hides ≥50% of a unit, granting +1 Defense.
- LoS: Straight line between shooter and target squares, blocked by any unit or blocking terrain.
- Round: One cycle of initiative, alternating activations, up to four activations per player.
- Activation: A unit taking one action.
- Action: One of Move, Attack, First Aid, Hold Position.
- d6, 2d6: One six-sided die; two six-sided dice summed.
- Digital terms: Validation (rules engine checks legality), Preview (UI shows result before commit), Command (serialisable player action).

# Game Rule Requirements (Physical Rules → Digital Rules)
Setup & Terrain (from Basics, Terrain & Cover)
- GR-001: The system shall create a battlefield of 15 columns by 9 rows.
- GR-002: The system shall randomly place 3–5 terrain pieces sized 1–4 squares before deployment.
- GR-003: The system shall treat terrain as blocking LoS, providing cover, and impassable by default, with provision for future per-piece flags.
- GR-004: The system shall apply +1 Defense to units in cover (≥50% obscured).

Factions & Units (from Factions, Faction notes)
- GR-005: The system shall offer five factions: Verdant Eye, Azure Blades, Ember Guard, Grey Cloaks, Solar Wardens.
- GR-006: The system shall set default roster size to five units, except Solar Wardens limited to four.
- GR-007: The system shall assign base stats per faction: Verdant Eye (Move 4, Range 5, AQ +1, Defense 7); Azure Blades (Move 5, Range 2, AQ +1, Defense 8); Ember Guard (Move 2, Range 3, AQ +2, Defense 9); Grey Cloaks (Move 4, Range 3, AQ +0, Defense 8); Solar Wardens (Move d6 random each move, Range 4, AQ +1, Defense 9).
- GR-008: The system shall apply Azure Blades melee AQ as +2 (replacing +1) in melee.
- GR-009: The system shall allow Grey Cloaks to reroll one attack die in ranged attacks and the die in melee, keeping chosen result.
- GR-010: The system shall treat Solar Wardens’ ranged attacks as Deadly Rounds that instant kill on natural 11 or 12 (before AQ).
- GR-011: The system shall support Solar Wardens’ random Move by rolling 1d6 per Move action.

Deployment & Initiative (from Deployment & Activation System)
- GR-012: The system shall enforce deployment into home zones (P1 columns 1–2, rows 1–9; P2 columns 14–15, rows 1–9), requiring each player to place units across at least two distinct rows within their home zone; deployment is performed without visibility into the opponent’s placements, and sequence is irrelevant. Rationale: the tabletop intent is simultaneous deployment, but with local alternating inputs on a single device true simultaneity is impractical; hidden, order-agnostic placement preserves the fairness goal.
- GR-013: The system shall, at each round start, have both players roll 1d6 for initiative and reroll ties.
- GR-014: The system shall let the initiative winner choose to (a) activate first with one unit or (b) allow the opponent to activate first with one unit.

Turn Structure & Activations (from Deployment & Activation System)
- GR-015: After the first activation of a round, the system shall alternate activation batches of two units per side.
- GR-016: The system shall limit each player to a maximum of four unit activations per round; if a player has fewer than five units remaining, all may activate once.

Actions (from Unit Actions)
- GR-017: The system shall allow exactly one action per activation.
- GR-018: Move action shall allow movement up to the unit’s Move stat (Solar Wardens use rolled value); diagonal moves are allowed except when movement would pass a blocked corner of impassable terrain; terrain squares are impassable.
- GR-019: Attack action shall allow moving up to half Move (rounded up) and then performing Shoot or Melee.
- GR-020: First Aid action shall allow moving up to half Move (rounded up) and then aiding an adjacent Down unit.
- GR-021: Hold Position shall do nothing; if a Down unit receives First Aid, it shall be allowed to activate immediately after, consuming one of the player’s remaining activations if any remain.
- GR-021.1: Range for attacks shall be measured in squares from the attacker to the target, excluding the attacker’s square and including the target square.

Combat: Ranged (from Combat Rules)
- GR-022: The system shall resolve ranged attacks with 2d6 plus attacker AQ; cover adds +1 Defense to target.
- GR-023: A ranged hit shall set the target to Down if total > target Defense.
- GR-024: A ranged critical hit shall instant kill on double sixes before AQ modifiers.
- GR-025: A ranged critical failure shall, on double ones when targeting an enemy in base contact with a friendly unit, hit that friendly instead.
- GR-026: A Down unit hit by a ranged attack a second time shall be destroyed.

Combat: Melee (from Combat Rules)
- GR-027: The system shall resolve melee when attacker is adjacent to target: both roll 1d6 simultaneously, add AQ (including Azure Blades bonus), and Down the unit with the lower total; ties have no effect.
- GR-028: Destroying a Down unit in melee shall require a melee attack action that auto-kills with no roll.

Down, First Aid, and Removal (from Combat Rules, Unit Actions)
- GR-029: A Down unit cannot activate unless first aided by an adjacent friendly unit using First Aid.
- GR-030: Upon receiving First Aid, a Down unit shall stand up (no Down state) and may activate immediately afterward if within remaining activation limits.

Line of Sight (from Combat Rules)
- GR-031: The system shall define LoS from the center of the shooter’s square to the center of the target’s square, blocked by any friendly or enemy unit and blocking terrain; LoS may not cut terrain corners and shall use visible area to determine cover (≥50% obscured grants cover).

Placement & Bounds
- GR-032: The system shall enforce that placement and movement occur within the board bounds, within the unit’s permitted range, and only onto allowable squares (unoccupied and not impassable terrain).
- GR-032.1: The system shall allow movement through squares occupied by other units but shall prohibit ending movement on any occupied square.

Missions & Victory (from Mission Types)
- GR-033: The system shall support six mission types with stated objectives: Crossfire Clash (1 point per kill, most points wins); Control Center (most units in the center band, columns 7–9, rows 1–9); Break Through (more units in the opponent’s home zone—P1’s home zone is columns 1–2, rows 1–9; P2’s is columns 14–15, rows 1–9); Dead Center (control the single central square at column 8, row 5); Dead Zone (prevent enemy units in the center band, columns 7–9, rows 1–9); Occupy (control the most of three sectors across columns 3–13 and rows 1–9: sector A columns 3–6, sector B columns 7–9, sector C columns 10–13; control is having the most units; +1 point for controlling sector B; +3 points for controlling the sector nearest the opponent’s home zone—P1 gains +3 for sector C, P2 gains +3 for sector A). Rationale: the tabletop Occupy rule calls for four equal areas, but the 15×9 grid cannot be evenly divided into four, so the digital adaptation uses three sectors with bonus points toward the opponent’s side to preserve balance.
- GR-034: The system shall allow mission selection by choice or random roll at battle start; no repeats in campaigns.
- GR-035: At end of round 6, ties shall trigger a single 7th round; if still tied after the 7th, the battle is recorded as a tie.
- GR-035.1: The system shall evaluate mission control and award mission points at the end of each round; ties in unit counts for control shall award no points. A tied battle after the 7th round shall award 1 victory point to each player for campaign scoring.

Campaign Mode & Scoring (from Campaign Mode)
- GR-036: The system shall support campaigns of length 1d3 + 2 battles (3–5).
- GR-037: The system shall require players to keep the same faction throughout a campaign.
- GR-038: The system shall track per-battle points (mission completion within 7 rounds: +2; kill all enemies: +1; survive with 3+ units: +1; battle ends in a tie after the 7th round: +1 to each player) and add each battle’s total to a cumulative campaign score; per-battle points do not carry over individually outside the cumulative total. The tie VP defined in GR-035.1 shall be included in both the per-battle total and the cumulative campaign score.
- GR-039: The system shall ensure each campaign mission is unique (no repeats).

Winner’s Advantage (from Winner’s Advantage)
- GR-040: After each battle, the player with the higher cumulative campaign score shall select one advantage for the next battle: Tactical Edge (reroll initiative die before opponent each round, keep second); Quick Start (before round 1, move two units up to full Move, no attacks); Focused Orders (gain two rerolls usable on attack, melee, initiative, etc.).

Optional Commander Rules (from Optional Commander Rules)
- GR-041: If enabled, each side shall select one commander trait: Resilient (ignore first Down in battle), Sniper (ignore cover when shooting), or Stealth (cannot be targeted if in cover).

Optional Battle Events (from Optional Battle Events)
- GR-042: If enabled, pre-game 1d6 roll shall apply one event: (1) Fog of War: max shoot range 3; (2) Deadly Rounds: natural 11/12 (Solar Wardens also 10) instant kill; (3) Fast Assault: all units +1 Move; (4) Focused Fire: shoot without move gains +1 AQ; (5) Revive: revive a Down unit at end of a round once per game; (6) No events.

Timing & Rounds (from Basics, Deployment & Activation)
- GR-043: The system shall limit battles to 6 rounds, adding a single 7th round only when tied after round 6 and recording the battle as a tie if still tied afterward; no 8th round shall be played.
- GR-044: The system shall ensure activation order follows initiative choice then alternating batches until activation limits reached.

Rerolls (from faction/event advantages)
- GR-045: The system shall allow at most one reroll per roll even if multiple reroll sources are available; once rerolled, the second result must be kept when specified.

# Digital Adaptation Requirements
- DA-001: The system shall validate and block illegal deployments outside home zones or row distribution constraints.
- DA-002: The system shall present initiative rolls and winner choice clearly, requiring explicit confirmation.
- DA-003: The system shall enforce activation limits per round and per unit, preventing multiple activations beyond rules.
- DA-004: The system shall provide movement previews showing reachable squares (including diagonal where not blocked by terrain corners) and half-move limits, excluding impassable terrain.
- DA-005: The system shall prevent attacks without LoS or beyond Range; it shall show LoS indicators and valid targets respecting terrain corner blocking and cover visibility.
- DA-006: The system shall display attack resolution steps and outcomes (hit, Down, kill, crit, crit fail) with dice results.
- DA-007: The system shall prevent actions by Down units until aided, and auto-enable immediate activation after First Aid if allowed and if activation budget remains.
- DA-008: The system shall allow mission selection/rolling with visible objectives and scoring rules in-game.
- DA-009: The system shall track and display mission points and campaign cumulative scores throughout battle and campaign.
- DA-010: The system shall support enabling/disabling optional rules (Commander traits, Battle Events, Campaign) per match setup.
- DA-011: The system shall apply faction-specific rules automatically (e.g., Azure melee AQ, Grey rerolls, Solar movement/damage).
- DA-012: The system shall preview melee odds (AQ totals) and ranged outcomes (Defense with cover) before confirmation.
- DA-013: The system shall log all actions and dice rolls for review and troubleshooting.
- DA-014: The system shall provide an in-game rules reference/glossary for stats, actions, missions, events, and optional rules.
- DA-015: The system shall prevent selection of the same mission twice within a campaign.
- DA-016: The system shall manage tie detection, trigger a single automatic 7th round when tied after round 6, and record the battle as a tie if still tied afterward; no 8th round shall be played.
- DA-017: The system shall surface when Quick Start moves occur pre-round and block attacks during them.
- DA-018: The system shall allow reroll effects with explicit selection of which die to reroll and enforce the single-reroll limit with “must keep second result” where stated.
- DA-019: The system shall ensure Revive event can be used only once per game at end of a round.
- DA-020: The system shall ensure Stealth makes units untargetable when in cover; Sniper ignores cover modifiers; Resilient ignores first Down for that side.
- DA-021: The system shall preview cover status for an attacker/target pair based on LoS visibility (≥50% obscured grants cover) before attack confirmation.

# Cross-Platform Requirements
- CP-001: The system shall support equivalent interactions via pointer, touch, or controller-style inputs for all core actions (select, move, attack, confirm).
- CP-002: The system shall scale and reflow UI for varying screen sizes/orientations, keeping grid visibility and readable text.
- CP-003: The system shall provide zoom/pan controls suitable for small and large displays.
- CP-004: The system shall offer concise feedback (icons, text) that remains legible on mobile resolutions.
- CP-005: The system shall support saving and resuming local matches/campaigns across sessions.
- CP-006: The system shall minimize unnecessary background processing to preserve battery/thermal limits on mobile.
- CP-007: The system shall support offline local play without requiring network connectivity.

# Architecture-Quality Requirements
- AQ-001: Core rules logic shall be isolated from presentation and input handling.
- AQ-002: Unit, faction, mission, event, and commander data shall be configurable via external data definitions without code changes.
- AQ-003: The game state update logic shall be deterministic given an identical sequence of validated player commands.
- AQ-004: Randomness sources shall be centralised to allow seeding for reproducibility.
- AQ-005: Campaign progression (missions used, scores, advantages) shall be stored independently from UI.
- AQ-006: Optional rules (Commander, Battle Events, Campaign) shall be modular toggles that do not alter core engine when disabled.
- AQ-007: The rules engine shall expose validation for all commands (deployment, movement, attack, first aid, rerolls).

# Future Multiplayer Enablement Requirements
- MP-001: All player actions shall be represented as discrete, serialisable commands with sufficient data to replay deterministically.
- MP-002: The rules engine shall validate commands independently of the client UI.
- MP-003: The system shall maintain an authoritative game state that can be synchronised between peers/clients.
- MP-004: The system shall log action history to enable spectator/replay features.
- MP-005: The system shall support deterministic resolution of random events from a shared seed and sequence.
- MP-006: The system shall allow reconnection to restore full game state from serialised data.
