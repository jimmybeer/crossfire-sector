###############################################################
# project/tests/test_persistence.gd
# Key Classes      • (RefCounted suite) – verifies persistence checksums
# Key Functions    • run() – public entry; temp path helpers and round-trip tests
# Critical Consts  • PersistenceService preload
# Editor Exports   • (none)
# Dependencies     • persistence_service.gd
# Last Major Rev   • 25-01-07 – Documented persistence tests
###############################################################
extends RefCounted

const PersistenceService = preload("res://project/src/services/persistence_service.gd")

## Public API: Execute persistence-focused test cases.
func run() -> Array:
    var results: Array = []
    results.append(_test_save_load_round_trip())
    results.append(_test_partial_write_failure_keeps_original())
    return results

## Private: Build sandboxed tmp path for test artifacts.
func _tmp_path(name: String) -> String:
    return "res://.tmp/%s.json" % name

## Private: Save then load payload verifying both meta and command-log checksums.
func _test_save_load_round_trip() -> Dictionary:
    var path: String = _tmp_path("persistence_round_trip")
    var payload: Dictionary = {
        "match": {
            "id": "match_rt_01",
            "command_log": {
                "id": "log_rt_01",
                "entries": [
                    {
                        "id": "cmd_001",
                        "sequence": 1,
                        "type": "hold",
                        "rng_offset_before": 0,
                        "state_hash_after": "sha256:state_after_1"
                    }
                ],
                "version": "1.0.0"
            },
            "state_hash": "sha256:match_state_rt",
            "version": "1.0.0"
        },
        "meta": {
            "created_at": "2025-11-28T00:00:00Z",
            "updated_at": "2025-11-28T00:00:00Z",
            "compressed": false
        }
    }

    var save_result: Dictionary = PersistenceService.save_payload_atomic(path, payload)
    var load_result: Dictionary = PersistenceService.load_payload_with_checksum(path)
    var checksum_matches: bool = load_result.get("checksum", "") \
            == load_result.get("payload", {}).get("meta", {}).get("checksum", "")
    var log_checksum_matches: bool = load_result.get("log_checksum", "") \
            == load_result.get("expected_log_checksum", "")
    var passed: bool = save_result.get("ok", false) \
            and load_result.get("ok", false) \
            and checksum_matches \
            and log_checksum_matches

    DirAccess.remove_absolute(path + ".tmp")
    DirAccess.remove_absolute(path)
    return {
        "name": "persistence_round_trip",
        "passed": passed,
        "detail": {"save": save_result, "load": load_result}
    }

## Private: Simulate partial write and ensure original payload stays intact.
func _test_partial_write_failure_keeps_original() -> Dictionary:
    var path: String = _tmp_path("persistence_partial")
    var base_payload: Dictionary = {
        "match": {
            "id": "match_base_01",
            "command_log": {"id": "log_base", "entries": [], "version": "1.0.0"},
            "state_hash": "sha256:base_state",
            "version": "1.0.0"
        },
        "meta": {
            "created_at": "2025-11-28T00:00:00Z",
            "updated_at": "2025-11-28T00:00:00Z",
            "compressed": false
        }
    }
    var baseline: Dictionary = PersistenceService.save_payload_atomic(path, base_payload)
    var baseline_load: Dictionary = PersistenceService.load_payload_with_checksum(path)

    var modified_payload: Dictionary = base_payload.duplicate(true)
    modified_payload["match"]["state_hash"] = "sha256:modified_state"
    var failed_save: Dictionary = PersistenceService.save_payload_atomic(
        path,
        modified_payload,
        {"simulate_partial_write": true}
    )
    var after_load: Dictionary = PersistenceService.load_payload_with_checksum(path)

    var unchanged: bool = after_load.get("checksum", "") == baseline_load.get("checksum", "")
    var passed: bool = not failed_save.get("ok", true) and unchanged and after_load.get("ok", false)

    DirAccess.remove_absolute(path + ".tmp")
    DirAccess.remove_absolute(path)
    return {
        "name": "persistence_partial_write_protects_original",
        "passed": passed,
        "detail": {
            "baseline_save": baseline,
            "baseline_load": baseline_load,
            "failed_save": failed_save,
            "after_load": after_load
        }
    }
