###############################################################
# project/src/core/sample_resolver.gd
# Key Classes      • ProductionResolver – deterministic command resolver
# Key Functions    • resolve() – public entry to apply commands to state
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • rng_service.gd
# Last Major Rev   • 25-01-07 – Documented resolver flow
###############################################################
class_name ProductionResolver
extends RefCounted

const StateHasher = preload("res://project/src/core/state_hasher.gd")

# Requirement trace mapping for quick tagging on events/logs.
const EVENT_REQUIREMENTS := {
    "deploy": ["GR-012", "DA-001"],
    "move": ["GR-018", "DA-004"],
    "attack": ["GR-022", "DA-006"],
    "melee": ["GR-027", "DA-012"],
    "first_aid": ["GR-020", "DA-007"],
    "hold": ["GR-010"],
    "reroll": ["GR-045", "DA-018"],
    "advantage_use": ["GR-040"],
    "event_use": ["GR-042"],
    "quick_start_move": ["DA-017"]
}

const MISSION_TEMPLATES := {
    "crossfire_clash": {
        "mission_type": "crossfire_clash",
        "control_zones": []
    },
    "dead_zone": {
        "mission_type": "dead_zone",
        "control_zones": [
            {"col_start": 7, "col_end": 9, "row_start": 1, "row_end": 9}
        ]
    },
    "occupy": {
        "mission_type": "occupy",
        "control_zones": [
            {"col_start": 3, "col_end": 6, "row_start": 1, "row_end": 9, "bonus_points": 0},
            {"col_start": 7, "col_end": 9, "row_start": 1, "row_end": 9, "bonus_points": 1},
            {"col_start": 10, "col_end": 13, "row_start": 1, "row_end": 9, "bonus_points": 0}
        ]
    }
}

const DEFAULT_HOME_ZONES := {
    "P1": {"col_start": 1, "col_end": 2, "row_start": 1, "row_end": 9},
    "P2": {"col_start": 14, "col_end": 15, "row_start": 1, "row_end": 9}
}

## Public API: Deterministic resolver applying real state mutations for replay and
## fixture generation. Public entry point that mutates a duplicated state based on
## the incoming command and records emitted events.
static func resolve(
        command_data: Dictionary,
        state: Dictionary,
        rng_service,
        _data_config: Dictionary = {}
) -> Dictionary:
    var data_config: Dictionary = _data_config.duplicate(true)
    var new_state: Dictionary = _hydrate_state(state, data_config)
    var events: Array = []
    var cmd_type: String = command_data.get("type", "")
    var payload: Dictionary = command_data.get("payload", {})
    var optional_rules: Dictionary = _resolve_optional_rules(new_state, data_config)
    new_state["optional_rules"] = optional_rules

    var block_reason: String = _blocked_by_optional_rules(cmd_type, optional_rules)
    if block_reason != "":
        events.append(
            _build_event(
                "command_blocked",
                command_data,
                rng_service,
                new_state,
                {"reason": block_reason},
                "error"
            )
        )
        return _finalize(new_state, rng_service, events, false)

    match cmd_type:
        "deploy":
            var deploy_payload: Dictionary = _apply_deploy(new_state, command_data)
            events.append(
                _build_event("deploy", command_data, rng_service, new_state, deploy_payload)
            )
        "move":
            var roll_move: Dictionary = rng_service.roll_d6()
            var move_payload: Dictionary = _apply_move(
                new_state,
                command_data,
                data_config,
                roll_move
            )
            move_payload.merge(roll_move)
            events.append(
                _build_event("move", command_data, rng_service, new_state, move_payload)
            )
        "attack":
            var roll_attack: Dictionary = rng_service.roll_2d6()
            var attack_payload: Dictionary = _apply_attack(
                new_state,
                command_data,
                roll_attack,
                data_config
            )
            attack_payload.merge(roll_attack)
            events.append(
                _build_event("attack", command_data, rng_service, new_state, attack_payload)
            )
        "melee":
            var roll_melee: Dictionary = rng_service.roll_d6()
            var melee_payload: Dictionary = _apply_melee(
                new_state,
                command_data,
                roll_melee,
                data_config
            )
            melee_payload.merge(roll_melee)
            events.append(
                _build_event("melee", command_data, rng_service, new_state, melee_payload)
            )
        "first_aid":
            var first_aid_payload: Dictionary = _apply_first_aid(new_state, command_data)
            events.append(
                _build_event("first_aid", command_data, rng_service, new_state, first_aid_payload)
            )
        "hold":
            var hold_payload: Dictionary = _apply_hold(new_state, command_data)
            events.append(
                _build_event("hold", command_data, rng_service, new_state, hold_payload)
            )
        "reroll":
            var reroll_payload: Dictionary = _apply_reroll(new_state, command_data)
            events.append(
                _build_event("reroll", command_data, rng_service, new_state, reroll_payload)
            )
        "advantage_use":
            var roll_advantage: Dictionary = rng_service.roll_d6()
            var advantage_payload: Dictionary = _apply_advantage(new_state, command_data)
            advantage_payload.merge(roll_advantage)
            events.append(
                _build_event(
                    "advantage_use", command_data, rng_service, new_state, advantage_payload
                )
            )
        "event_use":
            var event_payload: Dictionary = _apply_event(new_state, command_data)
            events.append(
                _build_event("event_use", command_data, rng_service, new_state, event_payload)
            )
        "quick_start_move":
            var quick_payload: Dictionary = _apply_quick_start_move(new_state, command_data)
            events.append(
                _build_event(
                    "quick_start_move", command_data, rng_service, new_state, quick_payload
                )
            )
        _:
            events.append(_build_event("noop", command_data, rng_service, new_state, {}))

    return _finalize(new_state, rng_service, events, true)

## Private: Persist RNG seed/offset into state after mutations to keep replay deterministic.
static func _sync_rng(state: Dictionary, rng_service) -> void:
    var rng_block: Dictionary = state.get("rng", {})
    rng_block["seed"] = rng_service.get_seed()
    rng_block["offset"] = rng_service.get_offset()
    state["rng"] = rng_block

## Private: Initialize state with defaults and normalized blocks.
static func _hydrate_state(state: Dictionary, data_config: Dictionary) -> Dictionary:
    var hydrated: Dictionary = state.duplicate(true)
    if not hydrated.has("unit_states"):
        hydrated["unit_states"] = []
    if not hydrated.has("player_states"):
        hydrated["player_states"] = []
    if not hydrated.has("terrain"):
        hydrated["terrain"] = data_config.get("terrain", [])
    if not hydrated.has("optional_rules"):
        hydrated["optional_rules"] = data_config.get(
            "optional_rules", {"campaign": false, "events": false, "commander": false}
        )
    if not hydrated.has("applied_commands"):
        hydrated["applied_commands"] = 0
    if not hydrated.has("event_seq"):
        hydrated["event_seq"] = 0
    var logs: Array = hydrated.get("log", hydrated.get("logs", []))
    hydrated["log"] = logs
    hydrated["logs"] = logs
    _sync_rng(hydrated, _create_passthrough_rng(hydrated))
    return hydrated

## Private: Build a lightweight RNG proxy when none provided in state to preserve offsets.
static func _create_passthrough_rng(state: Dictionary):
    var rng = preload("res://project/src/services/rng_service.gd").new(
        state.get("rng", {}).get("seed", 0), int(state.get("rng", {}).get("offset", 0))
    )
    return rng

## Private: Compute optional rule flags with defaults (campaign/events off by default).
static func _resolve_optional_rules(state: Dictionary, data_config: Dictionary) -> Dictionary:
    var optional_rules: Dictionary = {"campaign": false, "events": false, "commander": false}
    optional_rules.merge(data_config.get("optional_rules", {}), true)
    optional_rules.merge(state.get("optional_rules", {}), true)
    return optional_rules

## Private: Gate resolver mutations if optional rules are disabled.
static func _blocked_by_optional_rules(cmd_type: String, optional_rules: Dictionary) -> String:
    if (
        cmd_type in ["advantage_use", "quick_start_move"]
        and not optional_rules.get("campaign", false)
    ):
        return "campaign_disabled"
    if cmd_type == "event_use" and not optional_rules.get("events", false):
        return "events_disabled"
    return ""

## Private: Prepare an event payload with audit-lite metadata and requirement tags.
static func _build_event(
    event_type: String,
    command_data: Dictionary,
    rng_service,
    state: Dictionary,
    extra_payload: Dictionary = {},
    severity: String = "info"
) -> Dictionary:
    var event_seq: int = _next_event_seq(state)
    var timestamp_ms: int = int(command_data.get("timestamp_ms", event_seq))
    state["clock_ms"] = timestamp_ms
    var hash_before: String = StateHasher.hash_state(state)
    var event_data: Dictionary = {
        "type": event_type,
        "severity": severity,
        "event_seq": event_seq,
        "timestamp_ms": timestamp_ms,
        "command_id": command_data.get("id", ""),
        "sequence": command_data.get("sequence", 0),
        "actor_unit_id": command_data.get("actor_unit_id", ""),
        "player_id": command_data.get("player_id", command_data.get("actor_player_id", "")),
        "seed": rng_service.get_seed(),
        "offset": rng_service.get_offset(),
        "requirements": EVENT_REQUIREMENTS.get(event_type, []),
        "hash_before": hash_before
    }
    for key in extra_payload.keys():
        event_data[key] = extra_payload[key]
    _append_log(
        state,
        "%s resolved (seq %s)" % [event_type, str(event_seq)],
        severity,
        EVENT_REQUIREMENTS.get(event_type, []),
        event_seq,
        timestamp_ms
    )
    return event_data

## Private: Allocate a monotonic event sequence counter.
static func _next_event_seq(state: Dictionary) -> int:
    var seq: int = int(state.get("event_seq", 0)) + 1
    state["event_seq"] = seq
    return seq

## Private: Append a structured log entry with requirements and severity.
static func _append_log(
    state: Dictionary,
    message: String,
    severity: String,
    requirements: Array,
    event_seq: int,
    timestamp_ms: int
) -> void:
    var logs: Array = state.get("log", state.get("logs", []))
    logs.append({
        "message": message,
        "severity": severity,
        "requirements": requirements,
        "event_seq": event_seq,
        "timestamp_ms": timestamp_ms,
        "seed": state.get("rng", {}).get("seed", null),
        "offset": state.get("rng", {}).get("offset", null),
        "hash": state.get("hash", null)
    })
    state["log"] = logs
    state["logs"] = logs

## Private: Finalize state after command application: sync RNG, hash, and counters.
static func _finalize(
    state: Dictionary, rng_service, events: Array, count_applied: bool
) -> Dictionary:
    _sync_rng(state, rng_service)
    _update_scoring(state)
    state["applied_commands"] = int(state.get("applied_commands", 0)) + (1 if count_applied else 0)
    state["units"] = state.get("unit_states", [])
    var hash_state: Dictionary = state.duplicate(true)
    hash_state.erase("hash")
    state["hash"] = StateHasher.hash_state(hash_state)
    for idx in range(events.size()):
        var ev: Dictionary = events[idx]
        ev["hash_after"] = state["hash"]
        events[idx] = ev
    return {"state": state, "events": events}

## Private: Ensure mission/campaign scoring blocks are populated for UI and hashing.
static func _update_scoring(state: Dictionary) -> void:
    var player_states: Array = state.get("player_states", [])
    if player_states.is_empty():
        return
    var mission: Dictionary = state.get("mission", {})
    var mission_scores: Dictionary = mission.get("scores", {})
    var round_state: Dictionary = state.get("round_state", {})
    var round_scores: Dictionary = round_state.get("mission_points_this_round", {})
    for ps in player_states:
        var pid: String = ps.get("player_id", "")
        if pid == "":
            continue
        var base_score: int = int(mission_scores.get(pid, round_scores.get(pid, 0)))
        mission_scores[pid] = base_score
    var mission_id: String = mission.get("mission_id", state.get("mission_id", ""))
    mission_scores = _apply_mission_scoring(mission_id, state, mission_scores)
    mission["mission_id"] = mission_id
    mission["scores"] = mission_scores
    state["mission"] = mission

    var optional_rules: Dictionary = state.get("optional_rules", {})
    var campaign: Dictionary = state.get("campaign", {})
    if optional_rules.get("campaign", false) or not campaign.is_empty():
        var camp_scores: Dictionary = campaign.get("scores", {})
        for ps in player_states:
            var pid: String = ps.get("player_id", "")
            if pid == "":
                continue
            var current: int = int(ps.get("campaign_score", camp_scores.get(pid, 0)))
            camp_scores[pid] = current
        campaign["scores"] = camp_scores
        campaign["total_battles"] = campaign.get(
            "total_battles", state.get("campaign_total_battles", 0)
        )
        state["campaign"] = campaign

## Private: Apply mission-specific scoring based on control zones and unit presence.
static func _apply_mission_scoring(
    mission_id: String, state: Dictionary, existing_scores: Dictionary
) -> Dictionary:
    var scores: Dictionary = existing_scores.duplicate(true)
    var mission_block: Dictionary = state.get("mission", {})
    var template: Dictionary = mission_block.duplicate(true)
    if template.is_empty():
        template = MISSION_TEMPLATES.get(mission_id, {})
    if template.is_empty():
        return scores
    var mission_type: String = template.get("mission_type", mission_id)
    match mission_type:
        "crossfire_clash":
            return _score_crossfire_clash(state, scores)
        "control_center":
            return _score_control_center(template, state, scores)
        "break_through":
            return _score_break_through(state, scores)
        "dead_center":
            return _score_dead_center(template, state, scores)
        "dead_zone":
            return _score_dead_zone(template, state, scores)
        "occupy":
            return _score_occupy(template, state, scores)
        _:
            return scores

## Private: Score Dead Zone – deny enemy presence in center band.
static func _score_dead_zone(
    template: Dictionary, state: Dictionary, scores: Dictionary
) -> Dictionary:
    var zones: Array = template.get("control_zones", [])
    if zones.is_empty():
        return scores
    var zone: Dictionary = zones[0]
    var counts: Dictionary = _unit_counts_in_zone(zone, state)
    if counts.is_empty():
        return scores
    var players: Array = counts.keys()
    if players.size() < 2:
        return scores
    var p1: String = str(players[0])
    var p2: String = str(players[1])
    if counts.get(p2, 0) == 0 and counts.get(p1, 0) > 0:
        scores[p1] = int(scores.get(p1, 0)) + 1
    if counts.get(p1, 0) == 0 and counts.get(p2, 0) > 0:
        scores[p2] = int(scores.get(p2, 0)) + 1
    return scores

## Private: Score Control Center – majority in center band gains 1.
static func _score_control_center(
    template: Dictionary, state: Dictionary, scores: Dictionary
) -> Dictionary:
    var zones: Array = template.get("control_zones", [])
    if zones.is_empty():
        return scores
    var zone: Dictionary = zones[0]
    var counts: Dictionary = _unit_counts_in_zone(zone, state)
    var winner: String = _zone_winner(counts)
    if winner != "":
        scores[winner] = int(scores.get(winner, 0)) + 1
    return scores

## Private: Score Break Through – units in opponent home zone gain 1 if ahead.
static func _score_break_through(state: Dictionary, scores: Dictionary) -> Dictionary:
    var zones: Dictionary = DEFAULT_HOME_ZONES
    var counts_vs: Dictionary = {}
    for pid in zones.keys():
        var zone: Dictionary = zones.get(pid, {})
        var counts: Dictionary = _unit_counts_in_zone(zone, state)
        for owner in counts.keys():
            if owner == pid:
                continue
            counts_vs[owner] = int(counts_vs.get(owner, 0)) + counts.get(owner, 0)
    var winner: String = _zone_winner(counts_vs)
    if winner != "":
        scores[winner] = int(scores.get(winner, 0)) + 1
    return scores

## Private: Score Dead Center – control single center cell.
static func _score_dead_center(
    template: Dictionary, state: Dictionary, scores: Dictionary
) -> Dictionary:
    var zones: Array = template.get("control_zones", [])
    if zones.is_empty():
        return scores
    var zone: Dictionary = zones[0]
    var counts: Dictionary = _unit_counts_in_zone(zone, state)
    var winner: String = _zone_winner(counts)
    if winner != "":
        scores[winner] = int(scores.get(winner, 0)) + 1
    return scores

## Private: Score Crossfire Clash – count destroyed enemy units per player.
static func _score_crossfire_clash(state: Dictionary, scores: Dictionary) -> Dictionary:
    var units: Array = state.get("unit_states", [])
    var destroyed_counts: Dictionary = {}
    for unit in units:
        if unit.get("status", "") == "destroyed":
            var owner: String = unit.get("owner_id", "")
            if owner == "":
                continue
            destroyed_counts[owner] = int(destroyed_counts.get(owner, 0)) + 1
    # award 1 point per enemy destroyed; invert counts
    for owner in destroyed_counts.keys():
        for ps in state.get("player_states", []):
            var pid: String = ps.get("player_id", "")
            if pid == "" or pid == owner:
                continue
            scores[pid] = int(scores.get(pid, 0)) + destroyed_counts.get(owner, 0)
    return scores

## Private: Score Occupy – control zones grant 1 + bonus_points to the majority holder.
static func _score_occupy(
    template: Dictionary, state: Dictionary, scores: Dictionary
) -> Dictionary:
    var zones: Array = template.get("control_zones", [])
    if zones.is_empty():
        return scores
    for zone in zones:
        var counts: Dictionary = _unit_counts_in_zone(zone, state)
        var winner: String = _zone_winner(counts)
        if winner != "":
            var points: int = 1 + int(zone.get("bonus_points", 0))
            scores[winner] = int(scores.get(winner, 0)) + points
    return scores

## Private: Count alive units per player inside a zone.
static func _unit_counts_in_zone(zone: Dictionary, state: Dictionary) -> Dictionary:
    var counts: Dictionary = {}
    var units: Array = state.get("unit_states", [])
    for unit in units:
        if unit.get("status", "alive") == "destroyed":
            continue
        var pos: Dictionary = unit.get("position", {})
        if _cell_within_zone(pos, zone):
            var pid: String = unit.get("owner_id", "")
            if pid == "":
                continue
            counts[pid] = int(counts.get(pid, 0)) + 1
    return counts

## Private: Determine a single winner for a zone; ties return empty.
static func _zone_winner(counts: Dictionary) -> String:
    var winner: String = ""
    var best: int = 0
    for pid in counts.keys():
        var count: int = counts.get(pid, 0)
        if count > best:
            best = count
            winner = pid
        elif count == best:
            winner = ""
    return winner

## Private: Check if a cell lies within a rectangular zone.
static func _cell_within_zone(cell: Dictionary, zone: Dictionary) -> bool:
    if cell.is_empty():
        return false
    var col: int = int(cell.get("col", -1))
    var row: int = int(cell.get("row", -1))
    return (
        col >= int(zone.get("col_start", 0))
        and col <= int(zone.get("col_end", 0))
        and row >= int(zone.get("row_start", 0))
        and row <= int(zone.get("row_end", 0))
    )

## Private: Place a unit on the map and mark it as ready for activation.
static func _apply_deploy(state: Dictionary, command_data: Dictionary) -> Dictionary:
    var payload: Dictionary = command_data.get("payload", {})
    var unit_id: String = payload.get("unit_id", command_data.get("actor_unit_id", ""))
    var position: Dictionary = payload.get("position", {})
    var deploy_updater: Callable = func(u: Dictionary) -> void:
        u["position"] = position
        u["status"] = "alive"
        u["has_moved_this_activation"] = false
        u["activations_used"] = u.get("activations_used", 0)
        u["owner_id"] = command_data.get("player_id", u.get("owner_id", ""))
    _upsert_unit(state, unit_id, deploy_updater)
    return {"unit_id": unit_id, "position": position}

## Private: Move a unit along a provided path and mark activation usage.
static func _apply_move(
    state: Dictionary, command_data: Dictionary, data_config: Dictionary, roll_move: Dictionary
) -> Dictionary:
    var payload: Dictionary = command_data.get("payload", {})
    var unit_id: String = command_data.get("actor_unit_id", "")
    var path: Array = payload.get("path", payload.get("move_path", []))
    var start: Dictionary = _unit_position(unit_id, state)
    var dest: Dictionary = (path.back() if path.size() > 0 else start)
    var move_allowance: int = _get_unit_stat(unit_id, state, data_config, "move")
    var move_updater: Callable = func(u: Dictionary) -> void:
        u["position"] = dest
        u["has_moved_this_activation"] = true
        u["activations_used"] = (u.get("activations_used", 0)) + 1
        u["last_path"] = path
    _upsert_unit(state, unit_id, move_updater)
    return {
        "unit_id": unit_id,
        "from": start,
        "to": dest,
        "path": path,
        "move_allowance": move_allowance,
        "rolls": roll_move.get("rolls", [])
    }

## Private: Resolve a ranged attack, storing totals and applying downed state on high rolls.
static func _apply_attack(
    state: Dictionary,
    command_data: Dictionary,
    roll_attack: Dictionary,
    data_config: Dictionary
) -> Dictionary:
    var target_id: String = command_data.get("target_unit_id", "")
    var actor_id: String = command_data.get("actor_unit_id", "")
    var payload: Dictionary = command_data.get("payload", {})
    var attack_base: int = int(roll_attack.get("total", 0))
    var attacker_aq: int = _get_unit_stat(actor_id, state, data_config, "aq")
    var target_defense: int = _get_unit_stat(target_id, state, data_config, "defense")
    var cover_bonus: int = 1 if payload.get("target_in_cover", false) else 0
    var attack_total: int = attack_base + attacker_aq
    var defense_target: int = target_defense + cover_bonus
    var hit: bool = attack_total >= defense_target and target_id != ""
    if target_id != "":
        var apply_attack_results: Callable = func(u: Dictionary) -> void:
            if hit:
                u["status"] = "down"
                u["last_hit_by"] = actor_id
            u["last_attack_total"] = attack_total
            u["last_attack_defense"] = defense_target
            u["last_attack_cover"] = cover_bonus
        _upsert_unit(state, target_id, apply_attack_results)
    return {
        "unit_id": actor_id,
        "target_unit_id": target_id,
        "attack_total": attack_total,
        "defense_target": defense_target,
        "hit": hit,
        "cover": cover_bonus > 0,
        "rolls": roll_attack.get("rolls", [])
    }

## Private: Resolve a melee attack, requiring adjacency and logging the roll.
static func _apply_melee(
    state: Dictionary,
    command_data: Dictionary,
    roll_melee: Dictionary,
    data_config: Dictionary
) -> Dictionary:
    var target_id: String = command_data.get("target_unit_id", "")
    var actor_id: String = command_data.get("actor_unit_id", "")
    var roll_total: int = int(roll_melee.get("total", 0))
    var attacker_aq: int = _get_unit_stat(actor_id, state, data_config, "aq")
    var attack_total: int = roll_total + attacker_aq
    var hit: bool = attack_total >= 4 and target_id != ""
    if target_id != "":
        var melee_updater: Callable = func(u: Dictionary) -> void:
            if hit:
                u["status"] = "down"
                u["last_hit_by"] = actor_id
            u["last_melee_total"] = attack_total
        _upsert_unit(state, target_id, melee_updater)
    return {
        "unit_id": actor_id,
        "target_unit_id": target_id,
        "hit": hit,
        "melee_total": attack_total,
        "rolls": roll_melee.get("rolls", [])
    }

## Private: Restore a downed unit to alive and top off reroll counters safely.
static func _apply_first_aid(state: Dictionary, command_data: Dictionary) -> Dictionary:
    var target_id: String = command_data.get("target_unit_id", "")
    if target_id != "":
        var revive_updater: Callable = func(u: Dictionary) -> void:
            u["status"] = "alive"
            u["rerolls_available"] = max(0, int(u.get("rerolls_available", 0)))
            u["revived_by"] = command_data.get("actor_unit_id", "")
        _upsert_unit(state, target_id, revive_updater)
    return {"target_unit_id": target_id}

## Private: Consume a reroll charge and record which source triggered it.
static func _apply_reroll(state: Dictionary, command_data: Dictionary) -> Dictionary:
    var unit_id: String = command_data.get("actor_unit_id", "")
    var source: String = command_data.get("payload", {}).get("source", "")
    var reroll_updater: Callable = func(u: Dictionary) -> void:
        u["rerolls_available"] = max(0, int(u.get("rerolls_available", 0)) - 1)
        u["last_reroll_source"] = source
    _upsert_unit(state, unit_id, reroll_updater)
    return {"unit_id": unit_id, "source": source}

## Private: Capture a hold/skip activation command.
static func _apply_hold(state: Dictionary, command_data: Dictionary) -> Dictionary:
    var unit_id: String = command_data.get("actor_unit_id", "")
    var hold_updater: Callable = func(u: Dictionary) -> void:
        u["has_moved_this_activation"] = u.get("has_moved_this_activation", false)
        u["activations_used"] = (u.get("activations_used", 0)) + 1
        u["last_action"] = "hold"
    _upsert_unit(state, unit_id, hold_updater)
    state["last_event"] = "hold"
    return {"unit_id": unit_id}

## Private: Mark an advantage as spent and capture its usage context.
static func _apply_advantage(state: Dictionary, command_data: Dictionary) -> Dictionary:
    var payload: Dictionary = command_data.get("payload", {})
    var advantage_id: String = payload.get("advantage_id", "")
    var meta: Dictionary = state.get("advantages", {})
    meta[advantage_id] = {
        "used": true,
        "context": payload.get("context", ""),
        "actor_unit_id": command_data.get("actor_unit_id", "")
    }
    state["advantages"] = meta
    return {"advantage_id": advantage_id}

## Private: Append event metadata to the state's resolved events list.
static func _apply_event(state: Dictionary, command_data: Dictionary) -> Dictionary:
    var payload: Dictionary = command_data.get("payload", {})
    var events_meta: Array = state.get("events_resolved", [])
    events_meta.append({
        "id": payload.get("event_id", ""),
        "context": payload.get("context", ""),
        "actor_unit_id": command_data.get("actor_unit_id", "")
    })
    state["events_resolved"] = events_meta
    return {"event_id": payload.get("event_id", "")}

## Private: Batch move a set of units for quick-start scenarios.
static func _apply_quick_start_move(
    state: Dictionary,
    command_data: Dictionary
) -> Dictionary:
    var payload: Dictionary = command_data.get("payload", {})
    var unit_list: Array = payload.get("unit_ids", [])
    var previews: Array = []
    for unit_data in unit_list:
        if unit_data is Dictionary and unit_data.has("unit_id"):
            var dest: Dictionary = {}
            var path: Array = unit_data.get("path", [])
            if path.size() > 0:
                dest = path.back()
            var quick_move_updater: Callable = func(u: Dictionary) -> void:
                u["position"] = dest
                u["has_moved_this_activation"] = true
            _upsert_unit(state, unit_data.get("unit_id", ""), quick_move_updater)
            previews.append({"unit_id": unit_data.get("unit_id", ""), "to": dest, "path": path})
    state["options"] = state.get("options", {})
    state["options"]["quick_start_used"] = true
    return {"unit_ids": unit_list, "previews": previews}

## Private helper: Find or create a unit by id, applying a mutation closure safely.
static func _upsert_unit(state: Dictionary, unit_id: String, updater: Callable) -> void:
    if unit_id == "":
        return
    var units: Array = state.get("unit_states", [])
    var found: bool = false
    for i in units.size():
        var unit: Dictionary = units[i]
        if unit.get("id", "") == unit_id:
            var updated: Dictionary = unit.duplicate(true)
            updater.call(updated)
            units[i] = updated
            found = true
            break
    if not found:
        var new_unit: Dictionary = {"id": unit_id, "status": "alive"}
        updater.call(new_unit)
        units.append(new_unit)
    state["unit_states"] = units

## Private: Convenience to fetch a unit's position.
static func _unit_position(unit_id: String, state: Dictionary) -> Dictionary:
    var units: Array = state.get("unit_states", [])
    for u in units:
        if u.get("id", "") == unit_id:
            return u.get("position", {})
    return {}

## Private: Get player state by id.
static func _get_player_state(player_id: String, state: Dictionary) -> Dictionary:
    var players: Array = state.get("player_states", [])
    for ps in players:
        if ps.get("player_id", "") == player_id:
            return ps
    return {}

## Private: Resolve owning player for a unit.
static func _unit_owner(unit_id: String, state: Dictionary) -> String:
    var units: Array = state.get("unit_states", [])
    for u in units:
        if u.get("id", "") == unit_id:
            return u.get("owner_id", "")
    return ""

## Private: Pull a stat from faction data, defaulting to 0.
static func _get_unit_stat(
    unit_id: String, state: Dictionary, data_config: Dictionary, stat_name: String
) -> int:
    var owner_id: String = _unit_owner(unit_id, state)
    var player_state: Dictionary = _get_player_state(owner_id, state)
    var faction_id: String = player_state.get("faction_id", "")
    var factions: Dictionary = data_config.get("factions", {})
    var faction: Dictionary = factions.get(faction_id, {})
    var base_stats: Dictionary = faction.get("base_stats", {})
    var stat_val: Variant = base_stats.get(stat_name, 0)
    if stat_val is int:
        return stat_val
    return 0
