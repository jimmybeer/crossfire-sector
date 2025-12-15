###############################################################
# project/tools/regenerate_fixture_hashes.gd
# Key Classes      • (SceneTree script) – fixture regeneration tool
# Key Functions    • _initialize() – entry; _regenerate() – main workflow
# Critical Consts  • paths to hashing/resolver services
# Editor Exports   • (none)
# Dependencies     • state_hasher.gd, sample_resolver.gd, rng_service.gd, persistence_service.gd
# Last Major Rev   • 25-01-07 – Documented fixture regeneration flow
###############################################################
extends SceneTree

const STATE_HASHER_PATH := "res://project/src/core/state_hasher.gd"
const SAMPLE_RESOLVER_PATH := "res://project/src/core/sample_resolver.gd"
const RNG_SERVICE_PATH := "res://project/src/services/rng_service.gd"
const PERSISTENCE_SERVICE_PATH := "res://project/src/services/persistence_service.gd"

var state_hasher_script: Script
var resolver_script: Script
var rng_service_script: Script
var persistence_service_script: Script

## Entry point: Load dependencies and refresh fixture hashes; exits process with status.
func _initialize() -> void:
    state_hasher_script = load(STATE_HASHER_PATH)
    resolver_script = load(SAMPLE_RESOLVER_PATH)
    rng_service_script = load(RNG_SERVICE_PATH)
    persistence_service_script = load(PERSISTENCE_SERVICE_PATH)
    var ok: bool = _regenerate()
    quit(0 if ok else 1)

## Private: Walk fixture JSON payloads, recompute hashes using real resolver, and persist updates.
func _regenerate() -> bool:
    var fixture_paths: Dictionary = {
        "save_match": ProjectSettings.globalize_path(
            "res://docs/data-definition/fixtures/save_match.json"
        ),
        "commands": ProjectSettings.globalize_path(
            "res://docs/data-definition/fixtures/commands.json"
        ),
        "command_log": ProjectSettings.globalize_path(
            "res://docs/data-definition/fixtures/command_log.json"
        ),
        "match_state": ProjectSettings.globalize_path(
            "res://docs/data-definition/fixtures/match_state.json"
        ),
        "match_state_crossfire": ProjectSettings.globalize_path(
            "res://docs/data-definition/fixtures/match_state_crossfire_clash.json"
        ),
        "match_state_dead_zone": ProjectSettings.globalize_path(
            "res://docs/data-definition/fixtures/match_state_dead_zone.json"
        ),
        "match_state_occupy": ProjectSettings.globalize_path(
            "res://docs/data-definition/fixtures/match_state_occupy.json"
        )
    }

    var payload: Dictionary = _load_json(fixture_paths["save_match"])
    if payload.is_empty() or not payload.has("match"):
        push_error("[regen] Failed to load match payload from %s" % fixture_paths["save_match"])
        return false

    var match_block: Dictionary = payload["match"]
    var commands: Array = _load_commands(fixture_paths["commands"], match_block)

    var data_config: Dictionary = {
        "board_layout": {"columns": 15, "rows": 9, "home_zones": []},
        "factions": {}
    }

    var seed: Variant = match_block.get("rng", {}).get("seed", "fixture_seed")
    var rng: Object = rng_service_script.new(seed, 0)
    var initial_state: Dictionary = match_block.duplicate(true)
    initial_state.erase("command_log")
    initial_state["rng"] = {"seed": seed, "offset": 0}

    var current_state: Dictionary = initial_state
    for cmd in commands:
        cmd["rng_offset_before"] = rng.get_offset()
        var result: Dictionary = resolver_script.resolve(cmd, current_state, rng, data_config)
        current_state = result.get("state", current_state)
        cmd["state_hash_after"] = state_hasher_script.hash_state(current_state)
    match_block["command_log"]["entries"] = commands
    match_block["state_hash"] = state_hasher_script.hash_state(current_state)
    match_block["rng"]["offset"] = rng.get_offset()
    payload["match"] = match_block

    if not persistence_service_script.save_payload_atomic(
        fixture_paths["save_match"], payload
    ).get("ok", false):
        push_error("[regen] Failed to write save_match.json with checksums")
        return false

    _write_json(fixture_paths["commands"], commands)
    _write_json(fixture_paths["command_log"], match_block.get("command_log", {}))

    var match_state: Dictionary = _load_json(fixture_paths["match_state"])
    if not match_state.is_empty():
        match_state["state_hash"] = match_block["state_hash"]
        _write_json(fixture_paths["match_state"], match_state)

    _propagate_hash(
        fixture_paths["match_state_crossfire"],
        match_block["state_hash"]
    )
    _propagate_hash(
        fixture_paths["match_state_dead_zone"],
        match_block["state_hash"]
    )
    _propagate_hash(
        fixture_paths["match_state_occupy"],
        match_block["state_hash"]
    )

    print("[regen] Fixture hashes regenerated with real resolver state.")
    return true

## Private: Load JSON file into Dictionary (empty on missing/invalid input).
func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var text: String = FileAccess.get_file_as_string(path)
    var parsed: Variant = JSON.parse_string(text)
    return parsed if parsed is Dictionary else {}

## Private: Write JSON to disk, overwriting existing content.
func _write_json(path: String, value: Variant) -> void:
    var json_text: String = JSON.stringify(value, "  ")
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(json_text)
        file.close()

## Private: If a match_state fixture exists, stamp the provided hash.
func _propagate_hash(path: String, state_hash: String) -> void:
    var data: Dictionary = _load_json(path)
    if data.is_empty():
        return
    data["state_hash"] = state_hash
    _write_json(path, data)

## Private: Read commands from file or fallback to existing command_log entries.
func _load_commands(path: String, match_block: Dictionary) -> Array:
    if FileAccess.file_exists(path):
        var text: String = FileAccess.get_file_as_string(path)
        var parsed: Variant = JSON.parse_string(text)
        if parsed is Array:
            return _normalize_numbers(parsed)
    var fallback: Array = match_block.get("command_log", {}).get("entries", [])
    return _normalize_numbers(fallback)

## Private: Normalize floats that are whole numbers back to ints for stable hashing.
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
