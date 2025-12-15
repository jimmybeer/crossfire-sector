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
    results.append(_test_validator_optional_rules_default_off())
    results.append(_test_validator_attack_requires_target_unit())
    results.append(_test_replay_determinism())
    results.append(_test_replay_detects_offset_mismatch())
    results.append(_test_resolver_emits_metadata())
    results.append(_test_event_hash_alignment())
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

## Private: Optional rules should be default-off, gating campaign/events commands.
func _test_validator_optional_rules_default_off() -> Dictionary:
    var validator: CommandValidator = CommandValidator.new()
    var state: Dictionary = {
        "optional_rules": {},  # default-off expected
        "unit_states": [],
        "player_states": []
    }
    var command_advantage: Dictionary = {
        "id": "cmd_adv_1",
        "sequence": 1,
        "type": "advantage_use",
        "actor_unit_id": "unit_p1_1",
        "payload": {"advantage_id": "adv_01"}
    }
    var result_adv: Dictionary = validator.validate(command_advantage, state, {})
    var has_gate_adv: bool = not result_adv.get("ok", true) \
            and result_adv.get("errors", [])[0].get("code", "") == "campaign_disabled"

    var command_event: Dictionary = {
        "id": "cmd_evt_1",
        "sequence": 1,
        "type": "event_use",
        "payload": {"event_id": "evt_01"}
    }
    var result_evt: Dictionary = validator.validate(command_event, state, {})
    var has_gate_evt: bool = not result_evt.get("ok", true) \
            and result_evt.get("errors", [])[0].get("code", "") == "events_disabled"

    return {
        "name": "validator_optional_rules_default_off",
        "passed": has_gate_adv and has_gate_evt,
        "detail": {"adv": result_adv, "evt": result_evt}
    }

## Private: Attacks must specify a target unit and cell.
func _test_validator_attack_requires_target_unit() -> Dictionary:
    var validator: CommandValidator = CommandValidator.new()
    var state: Dictionary = {
        "unit_states": [
            {"id": "unit_p1_1", "owner_id": "P1", "position": {"col": 1, "row": 1}},
            {"id": "unit_p2_1", "owner_id": "P2", "position": {"col": 3, "row": 1}}
        ],
        "player_states": [
            {"player_id": "P1", "faction_id": "azure_blades"},
            {"player_id": "P2", "faction_id": "ember_guard"}
        ]
    }
    var data_config: Dictionary = {
        "board_layout": {"columns": 15, "rows": 9, "home_zones": []},
        "factions": {
            "azure_blades": {"base_stats": {"move": 4, "range": 5, "aq": 1, "defense": 8}},
            "ember_guard": {"base_stats": {"move": 2, "range": 3, "aq": 2, "defense": 9}}
        }
    }
    var command_attack: Dictionary = {
        "id": "cmd_attack_no_target",
        "sequence": 1,
        "type": "attack",
        "actor_unit_id": "unit_p1_1",
        "payload": {"target_cell": {"col": 3, "row": 1}}
    }
    var result: Dictionary = validator.validate(command_attack, state, data_config)
    var passed: bool = not result.get("ok", true) \
            and result.get("errors", [])[0].get("code", "") == "missing_actor_target"
    return {"name": "validator_attack_requires_target_unit", "passed": passed, "detail": result}

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

## Private: Ensure resolver events contain audit-lite metadata and hash updates.
func _test_resolver_emits_metadata() -> Dictionary:
    var rng: RNGService = RNGService.new("seed_meta", 0)
    var data_config: Dictionary = {
        "factions": {
            "azure_blades": {
                "base_stats": {"move": 4, "range": 5, "aq": 1, "defense": 8}
            }
        }
    }
    var initial_state: Dictionary = {
        "unit_states": [
            {
                "id": "unit_p1_1",
                "owner_id": "P1",
                "position": {"col": 1, "row": 1},
                "status": "alive"
            }
        ],
        "player_states": [{"player_id": "P1", "faction_id": "azure_blades"}],
        "optional_rules": {"campaign": false, "events": false},
        "rng": {"seed": "seed_meta", "offset": 0}
    }
    var command_data: Dictionary = {
        "id": "cmd_move_meta",
        "sequence": 1,
        "type": "move",
        "actor_unit_id": "unit_p1_1",
        "payload": {"path": [{"col": 1, "row": 1}, {"col": 2, "row": 1}]}
    }
    var result: Dictionary = ProductionResolver.resolve(
        command_data,
        initial_state,
        rng,
        data_config
    )
    var events: Array = result.get("events", [])
    var state_after: Dictionary = result.get("state", {})
    var event_ok: bool = events.size() == 1 \
            and events[0].has("seed") \
            and events[0].has("offset") \
            and events[0].has("event_seq") \
            and events[0].get("requirements", []) != []
    var hash_ok: bool = state_after.get("hash", "") != ""
    var seq_ok: bool = int(state_after.get("event_seq", 0)) == events[0].get("event_seq", -1)
    return {
        "name": "resolver_event_metadata",
        "passed": event_ok and hash_ok and seq_ok,
        "detail": {"events": events, "state": state_after}
    }

## Private: Events should include hash_after matching the state after resolve.
func _test_event_hash_alignment() -> Dictionary:
    var rng: RNGService = RNGService.new("seed_event_hash", 0)
    var initial_state: Dictionary = {
        "unit_states": [],
        "player_states": [],
        "optional_rules": {"campaign": false, "events": false},
        "rng": {"seed": "seed_event_hash", "offset": 0}
    }
    var command_data: Dictionary = {
        "id": "cmd_hold_hash",
        "sequence": 1,
        "type": "hold",
        "actor_unit_id": "unit_p1_1",
        "payload": {}
    }
    var result: Dictionary = ProductionResolver.resolve(command_data, initial_state, rng, {})
    var events: Array = result.get("events", [])
    var state_after: Dictionary = result.get("state", {})
    var expected_hash: String = state_after.get("hash", "")
    var passed: bool = events.size() == 1 and str(events[0].get("hash_after", "")) == expected_hash
    return {
        "name": "event_hash_alignment",
        "passed": passed,
        "detail": {"events": events, "state": state_after}
    }

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
