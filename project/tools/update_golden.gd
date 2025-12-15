###############################################################
# project/tools/update_golden.gd
# Key Classes      • (SceneTree script) – updates golden expected outputs
# Key Functions    • _initialize() – entry; _update_golden() – workflow
# Critical Consts  • GOLDEN_DIR, default label
# Editor Exports   • (none)
# Dependencies     • replay_harness.gd, command_validator.gd, rng_service.gd, sample_resolver.gd
# Last Major Rev   • 25-02-09 – Add golden updater tool
###############################################################
extends SceneTree

const GOLDEN_DIR := "res://project/tests/golden/"
const DEFAULT_LABEL := "crossfire_clash"

const RNGService = preload("res://project/src/services/rng_service.gd")
const ReplayHarness = preload("res://project/src/core/replay_harness.gd")
const CommandValidator = preload("res://project/src/validation/command_validator.gd")
const StateHasher = preload("res://project/src/core/state_hasher.gd")
const ProductionResolver = preload("res://project/src/core/sample_resolver.gd")


func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var label: String = DEFAULT_LABEL
    if args.size() > 0:
        label = args[0]
    var ok: bool = _update_golden(label)
    quit(0 if ok else 1)


## Private: Load commands, run replay, and persist expected output with hashes/offset.
func _update_golden(label: String) -> bool:
    var commands_path: String = GOLDEN_DIR + "%s_commands.json" % label
    var expected_path: String = GOLDEN_DIR + "%s_expected.json" % label
    if not FileAccess.file_exists(commands_path):
        push_error("[golden-update] Missing commands file for %s" % label)
        return false

    var commands_text: String = FileAccess.get_file_as_string(commands_path)
    var commands: Variant = JSON.parse_string(commands_text)
    if not (commands is Array):
        push_error("[golden-update] Invalid commands JSON for %s" % label)
        return false

    var expected: Dictionary = {}
    if FileAccess.file_exists(expected_path):
        var expected_text: String = FileAccess.get_file_as_string(expected_path)
        var parsed_expected: Variant = JSON.parse_string(expected_text)
        if parsed_expected is Dictionary:
            expected = parsed_expected

    var seed: Variant = expected.get("seed", label)
    var optional_rules: Dictionary = expected.get(
        "optional_rules", {"campaign": false, "events": false, "commander": false}
    )
    var rng: RNGService = RNGService.new(seed, 0)
    var validator: CommandValidator = CommandValidator.new()
    var data_config: Dictionary = {"board_layout": {"columns": 15, "rows": 9, "home_zones": []}}
    var resolver: Callable = func(
            cmd: Dictionary, state: Dictionary, rng_service: RNGService
    ) -> Dictionary:
        return ProductionResolver.resolve(cmd, state, rng_service, data_config)
        var hash_fn: Callable = func(state: Dictionary) -> String:
            return StateHasher.hash_state(state)
        var harness: ReplayHarness = ReplayHarness.new(
            rng,
            validator.validate,
            resolver,
            hash_fn,
            data_config
        )

    var initial_state: Dictionary = {
        "unit_states": [],
        "player_states": [],
        "optional_rules": optional_rules,
        "rng": {"seed": seed, "offset": 0}
    }
    var computed_commands: Array = []
    var state_cursor: Dictionary = initial_state.duplicate(true)
    var rng_cursor: RNGService = RNGService.new(seed, 0)
    for cmd in commands:
        var cmd_copy: Dictionary = cmd.duplicate(true)
        cmd_copy["rng_offset_before"] = rng_cursor.get_offset()
        var resolve_result: Dictionary = resolver.call(cmd_copy, state_cursor, rng_cursor)
        state_cursor = resolve_result.get("state", state_cursor)
        cmd_copy["state_hash_after"] = StateHasher.hash_state(state_cursor)
        computed_commands.append(cmd_copy)
    var result: Dictionary = harness.replay(initial_state, computed_commands)

    expected["seed"] = seed
    expected["final_offset"] = result.get("final_offset", 0)
    expected["final_hash"] = result.get("final_hash", "")
    expected["events"] = result.get("events", [])
    expected["status"] = result.get("status", "")

    # Persist updated commands with state_hash_after for determinism.
    var commands_json: String = JSON.stringify(computed_commands, "  ")
    var cmds_file: FileAccess = FileAccess.open(commands_path, FileAccess.WRITE)
    if cmds_file:
        cmds_file.store_string(commands_json)
        cmds_file.close()

    var json_text: String = JSON.stringify(expected, "  ")
    var file: FileAccess = FileAccess.open(expected_path, FileAccess.WRITE)
    if file:
        file.store_string(json_text)
        file.close()
        print("[golden-update] Updated expected for %s" % label)
        return true

    push_error("[golden-update] Failed to write expected file for %s" % label)
    return false
