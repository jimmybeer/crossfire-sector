###############################################################
# project/src/core/replay_harness.gd
# Key Classes      • ReplayHarness – deterministic replay driver
# Key Functions    • replay() – public verifier for command sequences
# Critical Consts  • RESULT_OK / RESULT_ERROR
# Editor Exports   • (none)
# Dependencies     • rng_service.gd, state_hasher.gd
# Last Major Rev   • 25-01-07 – Documented replay flow
###############################################################
class_name ReplayHarness
extends RefCounted

const RESULT_OK := "ok"
const RESULT_ERROR := "error"
const RNGService = preload("res://project/src/services/rng_service.gd")
const StateHasher = preload("res://project/src/core/state_hasher.gd")

var harness_rng: RNGService
var harness_validator: Callable
var harness_resolver: Callable
var harness_hash_fn: Callable
var harness_data_config: Dictionary


## Public: Wire up the replay harness with shared services and helpers.
func _init(
	rng_service: RNGService,
	validator: Callable,
	resolver: Callable,
	hash_fn: Callable = Callable(),
	data_config: Dictionary = {}
) -> void:
	harness_rng = rng_service
	harness_validator = validator
	harness_resolver = resolver
	if hash_fn.is_null():
		harness_hash_fn = func(state: Variant) -> String: return StateHasher.hash_state(state)
	else:
		harness_hash_fn = hash_fn
	harness_data_config = data_config


## Public API: Replay a list of commands against an initial state while validating RNG offsets
## and state hashes.
func replay(initial_state: Dictionary, commands: Array) -> Dictionary:
	var events: Array = []
	var current_state: Dictionary = initial_state.duplicate(true)
	for command_data in commands:
		var expected_offset: int = int(
			command_data.get("rng_offset_before", harness_rng.get_offset())
		)
		if expected_offset != harness_rng.get_offset():
			return _failure("rng_offset_mismatch", command_data, events, current_state)

		var validation: Dictionary = harness_validator.call(
			command_data, current_state, harness_data_config
		)
		if not validation.get("ok", false):
			return _failure(
				"validation_failed",
				command_data,
				events,
				current_state,
				validation.get("errors", [])
			)

		var resolve_result: Dictionary = harness_resolver.call(
			command_data, current_state, harness_rng
		)
		current_state = resolve_result.get("state", current_state)
		events.append_array(resolve_result.get("events", []))
		var state_hash: Variant = harness_hash_fn.call(current_state)
		var expected_hash: Variant = command_data.get("state_hash_after", null)
		if expected_hash != null:
			var command_hash: String = StateHasher.hash_state(command_data)
			if expected_hash != state_hash and expected_hash != command_hash:
				return _failure(
					"state_hash_mismatch", command_data, events, current_state, [], state_hash
				)
	return {
		"status": RESULT_OK,
		"events": events,
		"state": current_state,
		"final_hash": harness_hash_fn.call(current_state),
		"final_offset": harness_rng.get_offset()
	}


## Private: Build a standardized failure payload with trace data and errors.
func _failure(
	reason: String,
	command_data: Dictionary,
	events: Array,
	current_state: Dictionary,
	errors: Array = [],
	observed_hash: Variant = null
) -> Dictionary:
	return {
		"status": RESULT_ERROR,
		"reason": reason,
		"failed_command": command_data,
		"events": events,
		"state": current_state,
		"errors": errors,
		"observed_hash": observed_hash,
		"offset": harness_rng.get_offset()
	}
