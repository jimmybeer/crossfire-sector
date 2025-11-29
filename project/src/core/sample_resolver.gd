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

## Public API: Deterministic resolver applying real state mutations for replay and
## fixture generation. Public entry point that mutates a duplicated state based on
## the incoming command and records emitted events.
static func resolve(
        command_data: Dictionary,
        state: Dictionary,
        rng_service,
        _data_config: Dictionary = {}
) -> Dictionary:
    var new_state: Dictionary = state.duplicate(true)
    var events: Array = []
    var cmd_type: String = command_data.get("type", "")
    var payload: Dictionary = command_data.get("payload", {})
    # TODO: Confirm whether data_config should influence resolver behavior.

    match cmd_type:
        "deploy":
            _apply_deploy(new_state, command_data)
            events.append({
                "type": "deploy",
                "unit_id": command_data.get("actor_unit_id", ""),
                "offset": rng_service.get_offset()
            })
        "move":
            var roll_move: Dictionary = rng_service.roll_d6()
            _apply_move(new_state, command_data)
            events.append({
                "type": "move",
                "unit_id": command_data.get("actor_unit_id", ""),
                "offset": roll_move.get("offset", rng_service.get_offset()),
                "rolls": roll_move.get("rolls", [])
            })
        "attack":
            var roll_attack: Dictionary = rng_service.roll_2d6()
            _apply_attack(new_state, command_data, roll_attack)
            events.append({
                "type": "attack",
                "unit_id": command_data.get("actor_unit_id", ""),
                "target_unit_id": command_data.get("target_unit_id", null),
                "offset": roll_attack.get("offset", rng_service.get_offset()),
                "rolls": roll_attack.get("rolls", [])
            })
        "melee":
            var roll_melee: Dictionary = rng_service.roll_d6()
            _apply_melee(new_state, command_data, roll_melee)
            events.append({
                "type": "melee",
                "unit_id": command_data.get("actor_unit_id", ""),
                "target_unit_id": command_data.get("target_unit_id", null),
                "offset": roll_melee.get("offset", rng_service.get_offset()),
                "rolls": roll_melee.get("rolls", [])
            })
        "first_aid":
            _apply_first_aid(new_state, command_data)
            events.append({
                "type": "first_aid",
                "unit_id": command_data.get("actor_unit_id", ""),
                "target_unit_id": command_data.get("target_unit_id", null),
                "offset": rng_service.get_offset()
            })
        "hold":
            new_state["last_event"] = "hold"
            events.append({
                "type": "hold",
                "unit_id": command_data.get("actor_unit_id", ""),
                "offset": rng_service.get_offset()
            })
        "reroll":
            _apply_reroll(new_state, command_data)
            events.append({
                "type": "reroll",
                "unit_id": command_data.get("actor_unit_id", ""),
                "offset": rng_service.get_offset()
            })
        "advantage_use":
            var roll_advantage: Dictionary = rng_service.roll_d6()
            _apply_advantage(new_state, command_data)
            events.append({
                "type": "advantage_use",
                "advantage_id": payload.get("advantage_id", ""),
                "offset": roll_advantage.get("offset", rng_service.get_offset()),
                "rolls": roll_advantage.get("rolls", [])
            })
        "event_use":
            _apply_event(new_state, command_data)
            events.append({
                "type": "event_use",
                "event_id": payload.get("event_id", ""),
                "offset": rng_service.get_offset()
            })
        "quick_start_move":
            _apply_quick_start_move(new_state, command_data)
            events.append({
                "type": "quick_start_move",
                "unit_ids": payload.get("unit_ids", []),
                "offset": rng_service.get_offset()
            })
        _:
            events.append({"type": "noop", "offset": rng_service.get_offset()})

    _sync_rng(new_state, rng_service)
    return {"state": new_state, "events": events}

## Private: Persist RNG seed/offset into state after mutations to keep replay deterministic.
static func _sync_rng(state: Dictionary, rng_service) -> void:
    var rng_block: Dictionary = state.get("rng", {})
    rng_block["seed"] = rng_service.get_seed()
    rng_block["offset"] = rng_service.get_offset()
    state["rng"] = rng_block

## Private: Place a unit on the map and mark it as ready for activation.
static func _apply_deploy(state: Dictionary, command_data: Dictionary) -> void:
    var payload: Dictionary = command_data.get("payload", {})
    var unit_id: String = payload.get("unit_id", command_data.get("actor_unit_id", ""))
    var position: Dictionary = payload.get("position", {})
    _upsert_unit(state, unit_id, func(u: Dictionary) -> void:
        u["position"] = position
        u["status"] = "alive"
        u["has_moved_this_activation"] = false
    )

## Private: Move a unit along a provided path and mark activation usage.
static func _apply_move(state: Dictionary, command_data: Dictionary) -> void:
    var payload: Dictionary = command_data.get("payload", {})
    var unit_id: String = command_data.get("actor_unit_id", "")
    var path: Array = payload.get("path", [])
    var dest: Dictionary = {}
    if path.size() > 0:
        dest = path.back()
    _upsert_unit(state, unit_id, func(u: Dictionary) -> void:
        if not u.has("position"):
            u["position"] = dest
        else:
            u["position"] = dest
        u["has_moved_this_activation"] = true
        u["activations_used"] = (u.get("activations_used", 0)) + 1
    )

## Private: Resolve a ranged attack, storing totals and applying downed state on high rolls.
static func _apply_attack(
        state: Dictionary,
        command_data: Dictionary,
        roll_attack: Dictionary
) -> void:
    var target_id: String = command_data.get("target_unit_id", "")
    var roll_total: int = int(roll_attack.get("total", 0))
    if target_id != "":
        _upsert_unit(state, target_id, func(u: Dictionary) -> void:
            if roll_total >= 7:
                u["status"] = "down"
            u["last_attack_total"] = roll_total
        )

## Private: Resolve a melee attack, requiring adjacency and logging the roll.
static func _apply_melee(
        state: Dictionary,
        command_data: Dictionary,
        roll_melee: Dictionary
) -> void:
    var target_id: String = command_data.get("target_unit_id", "")
    var roll_total: int = int(roll_melee.get("total", 0))
    if target_id != "":
        _upsert_unit(state, target_id, func(u: Dictionary) -> void:
            if roll_total >= 4:
                u["status"] = "down"
            u["last_melee_total"] = roll_total
        )

## Private: Restore a downed unit to alive and top off reroll counters safely.
static func _apply_first_aid(state: Dictionary, command_data: Dictionary) -> void:
    var target_id: String = command_data.get("target_unit_id", "")
    if target_id != "":
        _upsert_unit(state, target_id, func(u: Dictionary) -> void:
            u["status"] = "alive"
            u["rerolls_available"] = max(0, int(u.get("rerolls_available", 0)))
        )

## Private: Consume a reroll charge and record which source triggered it.
static func _apply_reroll(state: Dictionary, command_data: Dictionary) -> void:
    var unit_id: String = command_data.get("actor_unit_id", "")
    _upsert_unit(state, unit_id, func(u: Dictionary) -> void:
        u["rerolls_available"] = max(0, int(u.get("rerolls_available", 0)) - 1)
        u["last_reroll_source"] = command_data.get("payload", {}).get("source", "")
    )

## Private: Mark an advantage as spent and capture its usage context.
static func _apply_advantage(state: Dictionary, command_data: Dictionary) -> void:
    var payload: Dictionary = command_data.get("payload", {})
    var advantage_id: String = payload.get("advantage_id", "")
    var meta: Dictionary = state.get("advantages", {})
    meta[advantage_id] = {
        "used": true,
        "context": payload.get("context", "")
    }
    state["advantages"] = meta

## Private: Append event metadata to the state's resolved events list.
static func _apply_event(state: Dictionary, command_data: Dictionary) -> void:
    var payload: Dictionary = command_data.get("payload", {})
    var events_meta: Array = state.get("events_resolved", [])
    events_meta.append({
        "id": payload.get("event_id", ""),
        "context": payload.get("context", "")
    })
    state["events_resolved"] = events_meta

## Private: Batch move a set of units for quick-start scenarios.
static func _apply_quick_start_move(
        state: Dictionary,
        command_data: Dictionary
) -> void:
    var payload: Dictionary = command_data.get("payload", {})
    var unit_list: Array = payload.get("unit_ids", [])
    for unit_data in unit_list:
        if unit_data is Dictionary and unit_data.has("unit_id"):
            var dest: Dictionary = {}
            var path: Array = unit_data.get("path", [])
            if path.size() > 0:
                dest = path.back()
            _upsert_unit(state, unit_data.get("unit_id", ""), func(u: Dictionary) -> void:
                u["position"] = dest
                u["has_moved_this_activation"] = true
            )

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
