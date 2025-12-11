###############################################################
# project/src/ui/ui_contracts.gd
# Key Classes      • UIContracts – helpers to build UI-facing DTOs
# Key Functions    • snapshot(), event(), error(), input_binding()
# Critical Consts  • SNAPSHOT_VERSION
# Editor Exports   • (none)
# Dependencies     • (none)
# Last Major Rev   • 25-11-29 – Stage 1 UI contract scaffolding
###############################################################
class_name UIContracts
extends RefCounted

const SNAPSHOT_VERSION := "1.0.0"


## Public: Build a render-ready snapshot DTO for the battlefield view.
static func snapshot(
    board: Dictionary = {},
    units: Array = [],
    terrain: Array = [],
    reachability: Array = [],
    los: Array = [],
    cover_sources: Array = [],
    activation: Dictionary = {},
    mission: Dictionary = {},
    campaign: Dictionary = {},
    options: Dictionary = {},
    rng: Dictionary = {},
    logs: Array = [],
    errors: Array = [],
    state_hash: String = ""
) -> Dictionary:
    return {
        "version": SNAPSHOT_VERSION,
        "board": board,
        "units": units,
        "terrain": terrain,
        "reachability": reachability,
        "los": los,
        "cover_sources": cover_sources,
        "activation": activation,
        "mission": mission,
        "campaign": campaign,
        "options": options,
        "rng": rng,
        "logs": logs,
        "errors": errors,
        "hash": state_hash
    }


## Public: Build a UI event DTO for dice/results/log stream rendering.
static func event(
    event_type: String,
    payload: Dictionary = {},
    requirements: Array = [],
    severity: String = "info"
) -> Dictionary:
    return {
        "type": event_type, "payload": payload, "requirements": requirements, "severity": severity
    }


## Public: Build a UI error DTO suitable for surfacing validator issues.
static func error(code: String, message: String, requirements: Array = []) -> Dictionary:
    return {"code": code, "message": message, "requirements": requirements}


## Public: Build an input-binding DTO for pointer/keyboard maps.
static func input_binding(
    action_id: String, input: String, command_type: String, payload_template: Dictionary = {}
) -> Dictionary:
    return {
        "action_id": action_id,
        "input": input,
        "command_type": command_type,
        "payload_template": payload_template
    }
