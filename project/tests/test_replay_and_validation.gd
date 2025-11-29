###############################################################
# project/tests/test_replay_and_validation.gd
# Key Classes      • (RefCounted suite) – validates replay + command logic
# Key Functions    • run() – public test entry; helpers for validation scenarios
# Critical Consts  • preloaded services (RNGService, ReplayHarness, etc.)
# Editor Exports   • (none)
# Dependencies     • rng_service.gd, replay_harness.gd, command_validator.gd,
#                    state_hasher.gd, sample_resolver.gd
# Last Major Rev   • 25-01-07 – Documented replay/validation tests
###############################################################
extends RefCounted

const RNGService = preload("res://project/src/services/rng_service.gd")
const ReplayHarness = preload("res://project/src/core/replay_harness.gd")
const CommandValidator = preload("res://project/src/validation/command_validator.gd")
const StateHasher = preload("res://project/src/core/state_hasher.gd")
const ProductionResolver = preload("res://project/src/core/sample_resolver.gd")

## Public API: Run suite of replay and validator checks.
func run() -> Array:
    var results: Array = []
    results.append(_test_validator_shapes())
    results.append(_test_replay_determinism())
    results.append(_test_replay_detects_offset_mismatch())
    return results

## Private: Basic shape validation to ensure move previews populate expected keys.
func _test_validator_shapes() -> Dictionary:
    var validator: CommandValidator = CommandValidator.new()
    var state: Dictionary = {
        "board_layout": {"columns": 15, "rows": 9},
        "optional_rules": {"commander": false, "events": false, "campaign": true},
        "unit_states": [
            {
                "id": "unit_p1_1",
                "owner_id": "P1",
                "position": {"col": 1, "row": 1},
                "status": "alive",
                "rerolls_available": 1
            }
        ],
        "player_states": [
            {"player_id": "P1", "faction_id": "azure_blades"}
        ]
    }
    var data_config: Dictionary = {
        "board_layout": {
            "columns": 15,
            "rows": 9,
            "home_zones": [{
                "player_id": "P1",
                "col_start": 1,
                "col_end": 2,
                "row_start": 1,
                "row_end": 9
            }]
        },
        "factions": {
            "azure_blades": {
                "base_stats": {"move": 4, "range": 5, "aq": 1, "defense": 8}
            }
        }
    }
    var command_data: Dictionary = {
        "id": "cmd_001",
        "sequence": 1,
        "type": "move",
        "actor_unit_id": "unit_p1_1",
        "payload": {"path": [{"col": 1, "row": 1}, {"col": 2, "row": 1}]}
    }
    var result: Dictionary = validator.validate(command_data, state, data_config)
    var passed: bool = result.get("ok", false) \
            and result.get("errors", []).is_empty() \
            and result.get("preview", {}).has("reachable_tiles")
    return {"name": "validator_shape_move", "passed": passed, "detail": result}

## Private: Ensure replay harness yields identical hashes for identical seeds/sequences.
func _test_replay_determinism() -> Dictionary:
    var rng: RNGService = RNGService.new("seed_replay", 0)
    var validator: CommandValidator = CommandValidator.new()
    var data_config: Dictionary = {
        "board_layout": {"columns": 15, "rows": 9, "home_zones": []},
        "factions": {}
    }
    var resolver: Callable = func(
            cmd: Dictionary, state: Dictionary, rng_service: RNGService
    ) -> Dictionary:
        return ProductionResolver.resolve(
            cmd, state, rng_service, data_config
        )
    var hash_fn: Callable = func(state: Dictionary) -> String:
        return StateHasher.hash_state(state)
    var harness: ReplayHarness = ReplayHarness.new(
        rng, validator.validate, resolver, hash_fn, data_config
    )
    var initial_state: Dictionary = {
        "applied_commands": 0,
        "unit_states": [],
        "player_states": [],
        "optional_rules": {"campaign": true},
        "rng": {"seed": "seed_replay", "offset": 0}
    }
    var base_commands: Array[Dictionary] = [
        {"id": "cmd_001", "sequence": 1, "type": "hold", "payload": {}},
        {"id": "cmd_002", "sequence": 2, "type": "hold", "payload": {}}
    ]
    var decorated_commands: Array = _decorate_with_hashes(
        base_commands,
        initial_state,
        data_config,
        "seed_replay",
        resolver
    )
    var first_run: Dictionary = harness.replay(initial_state, decorated_commands)
    var second_rng: RNGService = RNGService.new("seed_replay", 0)
    var second_harness: ReplayHarness = ReplayHarness.new(
        second_rng, validator.validate, resolver, hash_fn, data_config
    )
    var second_run: Dictionary = second_harness.replay(initial_state, decorated_commands)
    var passed: bool = first_run.get("status") == ReplayHarness.RESULT_OK \
            and second_run.get("status") == ReplayHarness.RESULT_OK \
            and first_run.get("final_hash") == second_run.get("final_hash")
    return {
        "name": "replay_determinism",
        "passed": passed,
        "detail": {"first": first_run, "second": second_run}
    }

## Private: Ensure harness catches mismatched RNG offsets before applying commands.
func _test_replay_detects_offset_mismatch() -> Dictionary:
    var rng: RNGService = RNGService.new("seed_replay_mismatch", 0)
    var validator: CommandValidator = CommandValidator.new()
    var data_config: Dictionary = {
        "board_layout": {"columns": 15, "rows": 9, "home_zones": []},
        "factions": {}
    }
    var resolver: Callable = func(
            cmd: Dictionary, state: Dictionary, rng_service: RNGService
    ) -> Dictionary:
        return ProductionResolver.resolve(
            cmd, state, rng_service, data_config
        )
    var hash_fn: Callable = func(state: Dictionary) -> String:
        return StateHasher.hash_state(state)
    var harness: ReplayHarness = ReplayHarness.new(
        rng, validator.validate, resolver, hash_fn, data_config
    )
    var initial_state: Dictionary = {
        "unit_states": [],
        "player_states": [],
        "optional_rules": {"campaign": true},
        "rng": {"seed": "seed_replay_mismatch", "offset": 2}
    }
    var commands: Array[Dictionary] = [
        {"id": "cmd_001", "sequence": 1, "type": "hold", "payload": {}, "rng_offset_before": 2}
    ]
    var result: Dictionary = harness.replay(initial_state, commands)
    var passed: bool = result.get("status") == ReplayHarness.RESULT_ERROR \
            and result.get("reason") == "rng_offset_mismatch"
    return {"name": "replay_offset_mismatch", "passed": passed, "detail": result}

## Private: Decorate commands with deterministic hashes and RNG offsets for reuse.
func _decorate_with_hashes(
        commands: Array,
        initial_state: Dictionary,
        _data_config: Dictionary,
        seed: String,
        resolver: Callable
) -> Array:
    var decorated: Array[Dictionary] = []
    var state: Dictionary = initial_state.duplicate(true)
    var rng: RNGService = RNGService.new(seed, 0)
    for cmd in commands:
        var cmd_copy: Dictionary = cmd.duplicate(true)
        cmd_copy["rng_offset_before"] = rng.get_offset()
        var resolve_result: Dictionary = resolver.call(cmd_copy, state, rng)
        state = resolve_result.get("state", state)
        cmd_copy["state_hash_after"] = StateHasher.hash_state(state)
        decorated.append(cmd_copy)
    return decorated
