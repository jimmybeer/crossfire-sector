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


## Public: Convert engine state into a UI snapshot DTO. State keys are optional and
## defaulted to keep UI rendering resilient during early prototyping.
func state_to_snapshot(state: Dictionary) -> Dictionary:
	var board: Dictionary = state.get("board", {})
	var units: Array = state.get("units", [])
	var reachability: Array = []
	var preview_state: Variant = state.get("preview", [])
	if preview_state is Dictionary:
		reachability = preview_state.get("reachable_tiles", [])
	elif preview_state is Array:
		reachability = preview_state
	var activation: Dictionary = state.get("activation", {})
	var mission: Dictionary = state.get("mission", {})
	var campaign: Dictionary = state.get("campaign", {})
	var logs: Array = state.get("log", [])
	var errors: Array = []
	return UIContracts.snapshot(
		board, units, reachability, activation, mission, campaign, logs, errors
	)


## Public: Convert resolver/validator events into UI-friendly stream payloads.
func events_to_stream(raw_events: Array) -> Array:
	var stream: Array = []
	for event_data in raw_events:
		var event_type: String = event_data.get("type", "unknown")
		var payload: Dictionary = event_data.duplicate(true)
		payload.erase("type")
		stream.append(UIContracts.event(event_type, payload, _requirements_for_event(event_type)))
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
	match event_type:
		"deploy":
			return ["GR-012", "DA-001"]
		"move":
			return ["GR-018", "DA-004"]
		"attack":
			return ["GR-022", "DA-006"]
		"melee":
			return ["GR-027", "DA-012"]
		"first_aid":
			return ["GR-020", "DA-007"]
		"reroll":
			return ["GR-045", "DA-018"]
		"advantage_use":
			return ["GR-040"]
		"event_use":
			return ["GR-042"]
		"quick_start_move":
			return ["DA-017"]
		_:
			return []
