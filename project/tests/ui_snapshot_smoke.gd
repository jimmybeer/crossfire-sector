###############################################################
# project/tests/ui_snapshot_smoke.gd
# Key Classes      • (SceneTree script) – UI snapshot smoke test from fixture
# Key Functions    • _initialize(), _run()
# Critical Consts  • FIXTURE_PATH, bindings
# Editor Exports   • (none)
# Dependencies     • UISliceLoader, UICommandBus, UIAdapter, RNGService
# Last Major Rev   • 25-02-09 – Fixture-to-UI DTO smoke harness
###############################################################
extends SceneTree

const UISliceLoader = preload("res://project/src/ui/ui_slice_loader.gd")
const UICommandBus = preload("res://project/src/ui/ui_command_bus.gd")
const UIAdapter = preload("res://project/src/ui/ui_adapter.gd")
const RNGService = preload("res://project/src/services/rng_service.gd")
const CommandValidator = preload("res://project/src/validation/command_validator.gd")
const ProductionResolver = preload("res://project/src/core/sample_resolver.gd")

const FIXTURE_PATH := "res://docs/data-definition/fixtures/save_match.json"
const SNAPSHOT_KEYS := [
    "board", "units", "terrain", "reachability", "los", "cover_sources", "activation",
    "mission", "campaign", "options", "rng", "logs", "errors", "hash"
]


func _initialize() -> void:
    var ok: bool = _run()
    quit(0 if ok else 1)


## Private: Load fixture, produce snapshot, and emit a simple command to verify DTO wiring.
func _run() -> bool:
    var fixture_abs: String = ProjectSettings.globalize_path(FIXTURE_PATH)
    if not FileAccess.file_exists(fixture_abs):
        push_error("[ui-snapshot-smoke] Fixture not found at %s" % FIXTURE_PATH)
        return false
    var fixture_json: String = FileAccess.get_file_as_string(fixture_abs)
    if fixture_json.is_empty():
        push_error("[ui-snapshot-smoke] Failed to read fixture at %s" % FIXTURE_PATH)
        return false
    var parsed: Variant = JSON.parse_string(fixture_json)
    if parsed == null or not (parsed is Dictionary) or not parsed.has("match"):
        push_error("[ui-snapshot-smoke] Malformed JSON in %s" % FIXTURE_PATH)
        return false

    var fixture_state: Dictionary = parsed.get("match", {}).duplicate(true)
    var rng_seed: Variant = fixture_state.get("rng", {}).get("seed", "fixture_seed")
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
        }
    }

    var loader := UISliceLoader.new(data_config, rng_seed, fixture_state)
    var load_result: Dictionary = loader.load_fixture(fixture_state)
    var initial_snapshot: Dictionary = load_result.get("snapshot", {})
    if not _has_snapshot_keys(initial_snapshot):
        push_error("[ui-snapshot-smoke] Snapshot missing expected keys")
        return false
    _print_snapshot(initial_snapshot, "[ui-snapshot-smoke] initial snapshot")

    # Build a no-op/hold command if present in bindings, otherwise skip command step.
    var bindings: Dictionary = {"hold": {"command_type": "hold", "payload_template": {}}}
    var bus := UICommandBus.new(
        CommandValidator.new(),
        RNGService.new(rng_seed),
        data_config,
        UIAdapter.new(),
        fixture_state
    )
    bus.set_bindings(bindings)
    bus.set_state(fixture_state)

    var hold_actor: String = ""
    if fixture_state.has("command_log"):
        var entries: Array = fixture_state.get("command_log", {}).get("entries", [])
        for entry in entries:
            if entry.get("type", "") == "hold":
                hold_actor = entry.get("actor_unit_id", "")
                break
    if hold_actor == "":
        var units: Array = fixture_state.get("units", fixture_state.get("unit_states", []))
        if units.size() > 0:
            hold_actor = str(units[0].get("id", units[0].get("unit_id", "")))
    var hold_cmd: Dictionary = bus.build_command_from_binding("hold", {"actor_unit_id": hold_actor})
    if hold_cmd.get("type", "") == "":
        print("[ui-snapshot-smoke] No hold binding; skipping command execution step.")
        return true

    var result: Dictionary = bus.enqueue(hold_cmd)
    _print_snapshot(result.get("snapshot", {}), "[ui-snapshot-smoke] after hold command")
    for ev in result.get("events", []):
        print_rich("[ui-snapshot-smoke][event] %s" % str(ev))

    return true


func _print_snapshot(snapshot: Dictionary, title: String) -> void:
    print_rich(
        (
            "%s version=%s units=%d logs=%d errors=%d"
            % [
                title,
                snapshot.get("version", ""),
                snapshot.get("units", []).size(),
                snapshot.get("logs", []).size(),
                snapshot.get("errors", []).size()
            ]
        )
    )

## Private: Ensure frozen DTO keys are present in snapshots.
func _has_snapshot_keys(snapshot: Dictionary) -> bool:
    for key in SNAPSHOT_KEYS:
        if not snapshot.has(key):
            return false
    return true
