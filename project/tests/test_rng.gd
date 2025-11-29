###############################################################
# project/tests/test_rng.gd
# Key Classes      • (RefCounted suite) – verifies RNGService determinism
# Key Functions    • run() – public test entry; RNG behavior checks
# Critical Consts  • RNGService preload
# Editor Exports   • (none)
# Dependencies     • rng_service.gd
# Last Major Rev   • 25-01-07 – Documented RNG tests
###############################################################
extends RefCounted

const RNGService = preload("res://project/src/services/rng_service.gd")

var rng_service: RNGService

## Public API: Execute RNG-focused test cases.
func run() -> Array:
    var results: Array = []
    results.append(_test_same_seed_same_rolls())
    results.append(_test_snapshot_restore())
    results.append(_test_advance_increments_offset())
    return results

## Private: Same seed should produce identical roll sequences.
func _test_same_seed_same_rolls() -> Dictionary:
    var rng_a: RNGService = RNGService.new("seed_a", 0)
    var rng_b: RNGService = RNGService.new("seed_a", 0)
    var rolls_a: Array[Dictionary] = [rng_a.roll_d6(), rng_a.roll_2d6()]
    var rolls_b: Array[Dictionary] = [rng_b.roll_d6(), rng_b.roll_2d6()]
    var passed: bool = rolls_a == rolls_b
    return {"name": "rng_same_seed_same_rolls", "passed": passed, "detail": [rolls_a, rolls_b]}

## Private: Snapshot/restore should rewind stream back to saved offset.
func _test_snapshot_restore() -> Dictionary:
    var rng: RNGService = RNGService.new("seed_b", 0)
    var first: Dictionary = rng.roll_2d6()
    var snapshot: Dictionary = rng.snapshot()
    rng.roll_d6()
    rng.restore(snapshot)
    var after_restore: Dictionary = rng.roll_d6()
    var passed: bool = snapshot.get("offset") + 1 == rng.get_offset() \
            and after_restore.get("total") \
            == RNGService.new("seed_b", snapshot.get("offset")).roll_d6().get("total")
    return {
        "name": "rng_snapshot_restore",
        "passed": passed,
        "detail": {"snapshot": snapshot, "after_restore": after_restore}
    }

## Private: Advance should only shift offset counter.
func _test_advance_increments_offset() -> Dictionary:
    rng_service = RNGService.new(123, 0)
    rng_service.advance(3)
    var current_offset: int = rng_service.get_offset()
    var roll: Dictionary = rng_service.roll_d6()
    var passed: bool = current_offset == 3 and roll.get("offset") == 4
    return {
        "name": "rng_advance_offset",
        "passed": passed,
        "detail": {"offset_before": current_offset, "roll": roll}
    }
