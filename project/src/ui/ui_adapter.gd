###############################################################
# project/src/ui/ui_adapter.gd
# Key Classes      • UIAdapter – translates engine state/events into UI DTOs
# Key Functions    • state_to_snapshot(), events_to_stream(), errors_to_ui()
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • ui_contracts.gd
# Last Major Rev   • 25-11-29 – Stage 1 adapter scaffolding
###############################################################
class_name UIAdapter
extends RefCounted

const UIContracts = preload("res://project/src/ui/ui_contracts.gd")

# Stage 1 DTO contract note:
# Snapshot keys expected from validator/resolver:
# - board{columns,rows}
# - units[{id,owner_id,position{col,row},status,cover?,in_range?,activated?}]
# - terrain[{template_id,cells[]}]
# - reachability[{col,row,color?,name?}]
# - los[{from,to,visible,path?,blocker?,rays?}]
# - cover_sources[{col,row,kind}]
# - activation{round,active_player,remaining}
# - mission{mission_id,scores,round}
# - campaign{battle_index,total_battles,scores,advantages}
# - options{commander,events,quick_start_used,revive_used}
# - rng{seed,offset}
# - logs[] (strings or {type,message,requirements?,timestamp?,severity?})
# - errors[], hash?
# Event stream uses {type,payload,requirements,severity,timestamp?,event_seq?}.


## Public: Convert engine state into a UI snapshot DTO. State keys are optional and
## defaulted to keep UI rendering resilient during early prototyping.
func state_to_snapshot(state: Dictionary) -> Dictionary:
    var board: Dictionary = state.get("board", {})
    var units: Array = state.get("units", state.get("unit_states", []))
    var terrain: Array = state.get("terrain", [])
    var reachability: Array = []
    var los: Array = state.get("los", [])
    var cover_sources: Array = state.get("cover_sources", [])
    var preview_state: Variant = state.get("preview", [])
    if preview_state is Dictionary:
        reachability = preview_state.get("reachable_tiles", reachability)
        los = preview_state.get("los", los)
        cover_sources = preview_state.get("cover_sources", cover_sources)
    elif preview_state is Array:
        reachability = preview_state
    var activation: Dictionary = state.get("activation", {})
    var mission: Dictionary = state.get("mission", {})
    var campaign: Dictionary = state.get("campaign", {})
    var options: Dictionary = state.get("options", {})
    var rng: Dictionary = state.get("rng", {})
    var logs: Array = state.get("log", state.get("logs", []))
    var errors: Array = state.get("errors", [])
    var state_hash: String = state.get("hash", "")
    return UIContracts.snapshot(
        board,
        units,
        terrain,
        reachability,
        los,
        cover_sources,
        activation,
        mission,
        campaign,
        options,
        rng,
        logs,
        errors,
        state_hash
    )


## Public: Convert resolver/validator events into UI-friendly stream payloads.
func events_to_stream(raw_events: Array) -> Array:
    var stream: Array = []
    for event_data in raw_events:
        var event_type: String = event_data.get("type", "unknown")
        var payload: Dictionary = event_data.duplicate(true)
        payload.erase("type")
        var severity: String = payload.get("severity", "info")
        payload.erase("severity")
        stream.append(
            UIContracts.event(event_type, payload, _requirements_for_event(event_type), severity)
        )
    return stream


## Public: Convert validation errors into UI-facing error DTOs.
func errors_to_ui(errors: Array) -> Array:
    var ui_errors: Array = []
    for err in errors:
        var code: String = err.get("code", "unknown")
        var message: String = err.get("message", "Validation failed")
        var reqs: Array = err.get("requirements", [])
        ui_errors.append(UIContracts.error(code, message, reqs))
    return ui_errors


## Private: Map event types to requirement coverage for quick traceability in UI.
func _requirements_for_event(event_type: String) -> Array:
    var req_map := {
        "deploy": ["GR-012", "DA-001"],
        "move": ["GR-018", "DA-004"],
        "attack": ["GR-022", "DA-006"],
        "melee": ["GR-027", "DA-012"],
        "first_aid": ["GR-020", "DA-007"],
        "reroll": ["GR-045", "DA-018"],
        "advantage_use": ["GR-040"],
        "event_use": ["GR-042"],
        "quick_start_move": ["DA-017"]
    }
    return req_map.get(event_type, [])
