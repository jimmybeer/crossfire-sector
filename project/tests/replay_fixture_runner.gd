###############################################################
# project/tests/replay_fixture_runner.gd
# Key Classes      • (SceneTree script) – runs fixture replay from saved JSON
# Key Functions    • _initialize() – entry; _run_fixture() – replay workflow
# Critical Consts  • preloaded services (RNGService, ReplayHarness, etc.)
# Editor Exports   • (none)
# Dependencies     • rng_service.gd, replay_harness.gd, command_validator.gd,
#                    state_hasher.gd, sample_resolver.gd
# Last Major Rev   • 25-01-07 – Documented fixture replay harness
###############################################################
extends SceneTree

const RNGService = preload("res://project/src/services/rng_service.gd")
const ReplayHarness = preload("res://project/src/core/replay_harness.gd")
const CommandValidator = preload("res://project/src/validation/command_validator.gd")
const StateHasher = preload("res://project/src/core/state_hasher.gd")
const ProductionResolver = preload("res://project/src/core/sample_resolver.gd")


## Entry point: run fixture replay and exit with status.
func _initialize() -> void:
	var ok: bool = _run_fixture()
	quit(0 if ok else 1)


## Private: Load fixture payloads, validate command hashes, and replay with deterministic services.
func _run_fixture() -> bool:
	var fixture_path: String = ProjectSettings.globalize_path(
		"res://../docs/data-definition/fixtures/save_match.json"
	)
	var fixture_json: String = FileAccess.get_file_as_string(fixture_path)
	if fixture_json.is_empty():
		push_error("[replay-fixture] Failed to read fixture at %s" % fixture_path)
		return false
	var parsed: Variant = JSON.parse_string(fixture_json)
	if parsed == null or not (parsed is Dictionary) or not parsed.has("match"):
		push_error("[replay-fixture] Malformed JSON in %s" % fixture_path)
		return false

	var match_data: Dictionary = _normalize_numbers(parsed.get("match", {}))
	var commands: Array = _normalize_numbers(match_data.get("command_log", {}).get("entries", []))
	var rng_dict: Dictionary = match_data.get("rng", {})
	var rng: RNGService = RNGService.new(rng_dict.get("seed", "fixture_seed"), 0)

	var data_config: Dictionary = {
		"board_layout":
		{
			"columns": 15,
			"rows": 9,
			"home_zones":
			[
				{"player_id": "P1", "col_start": 1, "col_end": 2, "row_start": 1, "row_end": 9},
				{"player_id": "P2", "col_start": 14, "col_end": 15, "row_start": 1, "row_end": 9}
			]
		},
		"factions": {}
	}

	var validator: CommandValidator = CommandValidator.new()
	var resolver: Callable = func(
		cmd: Dictionary, state: Dictionary, rng_service: RNGService
	) -> Dictionary:
		return ProductionResolver.resolve(cmd, state, rng_service, data_config)

	var hash_fn: Callable = func(state: Dictionary) -> String: return StateHasher.hash_state(state)

	var initial_state: Dictionary = match_data.duplicate(true)
	initial_state.erase("command_log")
	initial_state["rng"] = {"seed": rng_dict.get("seed", "fixture_seed"), "offset": 0}

	for cmd in commands:
		var expected_hash: Variant = cmd.get("state_hash_after", null)
		var cmd_for_hash: Dictionary = cmd.duplicate(true)
		cmd_for_hash.erase("state_hash_after")
		var computed_hash: String = StateHasher.hash_state(cmd_for_hash)
		if expected_hash != null and expected_hash != computed_hash:
			push_error(
				(
					"[replay-fixture] Command hash mismatch for %s expected %s got %s"
					% [cmd.get("id", ""), expected_hash, computed_hash]
				)
			)
			return false
		cmd.erase("state_hash_after")

	var harness: ReplayHarness = ReplayHarness.new(
		rng, validator.validate, resolver, hash_fn, data_config
	)
	var result: Dictionary = harness.replay(initial_state, commands)
	if result.get("status", "") != ReplayHarness.RESULT_OK:
		push_error("[replay-fixture] Replay failed: %s" % str(result))
		return false

	var expected_final: Variant = null
	if commands.size() > 0:
		expected_final = commands.back().get("state_hash_after", null)
	var final_hash_ok: bool = (
		expected_final == null
		or expected_final == result.get("final_hash", "")
		or expected_final == StateHasher.hash_state(commands.back())
	)
	if not final_hash_ok:
		push_error(
			(
				"[replay-fixture] Final hash mismatch: expected %s got %s"
				% [expected_final, result.get("final_hash", "")]
			)
		)
		return false

	print(
		(
			"[replay-fixture] Replay passed. Final hash: %s Offset: %s"
			% [result.get("final_hash", ""), result.get("final_offset", -1)]
		)
	)
	return true


## Private: Normalize floats that are whole numbers back to ints for stable comparisons.
func _normalize_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value.keys():
			out[key] = _normalize_numbers(value[key])
		return out
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_normalize_numbers(item))
		return arr
	if typeof(value) == TYPE_FLOAT and floor(value) == value:
		return int(value)
	return value
