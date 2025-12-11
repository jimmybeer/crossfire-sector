###############################################################
# project/src/ui/ui_command_bus.gd
# Key Classes      • UICommandBus – UI-facing queue for validator/resolver
# Key Functions    • enqueue(), set_state(), set_bindings()
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • CommandValidator, ProductionResolver, RNGService, UIAdapter
# Last Major Rev   • 25-11-29 – Stage 1 command bus scaffolding
###############################################################
class_name UICommandBus
extends RefCounted

const CommandValidator = preload("res://project/src/validation/command_validator.gd")
const ProductionResolver = preload("res://project/src/core/sample_resolver.gd")
const RNGService = preload("res://project/src/services/rng_service.gd")
const UIAdapter = preload("res://project/src/ui/ui_adapter.gd")

var bus_validator: CommandValidator
var bus_rng: RNGService
var bus_data_config: Dictionary
var bus_adapter: UIAdapter
var bus_state: Dictionary
var bus_bindings: Dictionary


## Public: Initialize the bus with required services.
func _init(
    validator: CommandValidator = CommandValidator.new(),
    rng_service: RNGService = null,
    data_config: Dictionary = {},
    adapter: UIAdapter = UIAdapter.new(),
    initial_state: Dictionary = {}
) -> void:
    bus_validator = validator
    bus_rng = rng_service if rng_service != null else RNGService.new(0)
    bus_data_config = data_config
    bus_adapter = adapter
    bus_state = initial_state.duplicate(true)
    bus_bindings = {}


## Public: Set the state snapshot the UI is currently displaying.
func set_state(state: Dictionary) -> void:
    bus_state = state.duplicate(true)


## Public: Provide custom bindings map for input → command DTO templates.
func set_bindings(bindings: Dictionary) -> void:
    bus_bindings = bindings.duplicate(true)


## Public: Enqueue and process a command built by the UI. Returns UI-facing payload.
func enqueue(command_data: Dictionary) -> Dictionary:
    var validation: Dictionary = bus_validator.validate(command_data, bus_state, bus_data_config)
    if not validation.get("ok", false):
        return {
            "ok": false,
            "errors": bus_adapter.errors_to_ui(validation.get("errors", [])),
            "snapshot": bus_adapter.state_to_snapshot(bus_state),
            "events": [],
            "state": bus_state
        }

    var resolve_result: Dictionary = ProductionResolver.resolve(
        command_data, bus_state, bus_rng, bus_data_config
    )
    bus_state = resolve_result.get("state", bus_state)
    var events: Array = bus_adapter.events_to_stream(resolve_result.get("events", []))
    var snapshot: Dictionary = bus_adapter.state_to_snapshot(bus_state)
    return {"ok": true, "snapshot": snapshot, "events": events, "state": bus_state}


## Public: Preview a command without mutating state; returns validation preview/errors.
func preview(command_data: Dictionary) -> Dictionary:
    var validation: Dictionary = bus_validator.validate(command_data, bus_state, bus_data_config)
    return {
        "ok": validation.get("ok", false),
        "preview": validation.get("preview", {}),
        "errors": bus_adapter.errors_to_ui(validation.get("errors", []))
    }


## Public: Build a command dictionary based on a binding id and a payload override.
func build_command_from_binding(binding_id: String, override_payload: Dictionary) -> Dictionary:
    if not bus_bindings.has(binding_id):
        return {}
    var binding: Dictionary = bus_bindings[binding_id]
    var payload: Dictionary = binding.get("payload_template", {}).duplicate(true)
    for key in override_payload.keys():
        payload[key] = override_payload[key]
    return {
        "type": binding.get("command_type", ""),
        "payload": payload,
        "actor_unit_id": override_payload.get("actor_unit_id", ""),
        "sequence": override_payload.get("sequence", 0)
    }
