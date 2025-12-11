###############################################################
# project/src/ui/ui_slice_loader.gd
# Key Classes      • UISliceLoader – loads fixtures and wires UI command flow
# Key Functions    • load_fixture(), process_command()
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • UICommandBus, UIAdapter, CommandValidator, ProductionResolver, RNGService
# Last Major Rev   • 25-11-29 – Stage 1 integration slice scaffolding
###############################################################
class_name UISliceLoader
extends RefCounted

const UICommandBus = preload("res://project/src/ui/ui_command_bus.gd")
const UIAdapter = preload("res://project/src/ui/ui_adapter.gd")
const CommandValidator = preload("res://project/src/validation/command_validator.gd")
const ProductionResolver = preload("res://project/src/core/sample_resolver.gd")
const RNGService = preload("res://project/src/services/rng_service.gd")

var loader_bus: UICommandBus
var loader_adapter: UIAdapter
var loader_state: Dictionary


## Public: Initialize loader with Stage 0 services and UI adapter.
func _init(
    data_config: Dictionary = {}, rng_seed: Variant = 0, initial_state: Dictionary = {}
) -> void:
    loader_adapter = UIAdapter.new()
    loader_bus = UICommandBus.new(
        CommandValidator.new(), RNGService.new(rng_seed), data_config, loader_adapter, initial_state
    )
    loader_state = initial_state.duplicate(true)


## Public: Load a fixture match into the UI-facing state and return snapshot + events.
func load_fixture(fixture_state: Dictionary) -> Dictionary:
    loader_state = fixture_state.duplicate(true)
    loader_bus.set_state(loader_state)
    return {"snapshot": loader_adapter.state_to_snapshot(loader_state), "events": []}


## Public: Process a single command through validator + resolver and return UI payload.
func process_command(command_data: Dictionary) -> Dictionary:
    loader_bus.set_state(loader_state)
    var result: Dictionary = loader_bus.enqueue(command_data)
    loader_state = result.get("state", loader_state)
    return result


## Public: Preview a command without mutating the tracked state.
func preview_command(command_data: Dictionary) -> Dictionary:
    loader_bus.set_state(loader_state)
    return loader_bus.preview(command_data)
