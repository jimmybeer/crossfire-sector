###############################################################
# project/src/services/rng_service.gd
# Key Classes      • RNGService – deterministic RNG with offset tracking
# Key Functions    • roll_d6(), roll_2d6(), snapshot(), restore()
# Critical Consts  • DEFAULT_DICE_MIN/MAX
# Editor Exports   • (none)
# Dependencies     • RandomNumberGenerator
# Last Major Rev   • 25-01-07 – Documented RNG service
###############################################################
class_name RNGService
extends RefCounted

const DEFAULT_DICE_MIN := 1
const DEFAULT_DICE_MAX := 6

var rng_seed_value: int
var rng_offset_value: int
var rng_instance: RandomNumberGenerator

## Public: Initialize RNG with a seed (int or string) and optional offset to replay past rolls.
func _init(seed: Variant, offset: int = 0) -> void:
    rng_seed_value = _normalize_seed(seed)
    rng_offset_value = max(0, offset)
    rng_instance = RandomNumberGenerator.new()
    _reset_rng()
    _prime_rng_to_offset(rng_offset_value)

## Public API: Roll a single D6 and return the value plus current offset.
func roll_d6() -> Dictionary:
    var roll_value: int = _roll_die()
    return {
        "total": roll_value,
        "rolls": [roll_value],
        "offset": rng_offset_value
    }

## Public API: Roll 2D6 and return summed total and per-die rolls.
func roll_2d6() -> Dictionary:
    var first_roll: int = _roll_die()
    var second_roll: int = _roll_die()
    var total: int = first_roll + second_roll
    return {
        "total": total,
        "rolls": [first_roll, second_roll],
        "offset": rng_offset_value
    }

## Public API: Advance RNG state by a count of rolls without returning values.
func advance(steps: int) -> int:
    var safe_steps: int = max(0, steps)
    if safe_steps == 0:
        return rng_offset_value
    for _i in safe_steps:
        _roll_die()
    return rng_offset_value

## Public API: Snapshot seed and offset to support deterministic restore later.
func snapshot() -> Dictionary:
    return {
        "seed": rng_seed_value,
        "offset": rng_offset_value
    }

## Public API: Restore RNG seed/offset and fast-forward to the saved offset.
func restore(snapshot_data: Dictionary) -> void:
    var snapshot_seed: Variant = snapshot_data.get("seed", rng_seed_value)
    var snapshot_offset: Variant = snapshot_data.get("offset", 0)
    rng_seed_value = _normalize_seed(snapshot_seed)
    rng_offset_value = 0
    _reset_rng()
    _prime_rng_to_offset(max(0, int(snapshot_offset)))

## Public: Return current offset (number of rolls consumed).
func get_offset() -> int:
    return rng_offset_value

## Public: Return normalized numeric seed.
func get_seed() -> int:
    return rng_seed_value

## Private: Normalize seed input to an int for RNG seeding.
func _normalize_seed(raw_seed: Variant) -> int:
    if raw_seed is int:
        return raw_seed
    if raw_seed is String:
        return hash(raw_seed)
    return hash(str(raw_seed))

## Private: Reset RNG instance to the base seed and zero state.
func _reset_rng() -> void:
    rng_instance.seed = rng_seed_value
    rng_instance.state = 0

## Private: Burn RNG steps to reach a requested offset.
func _prime_rng_to_offset(target_offset: int) -> void:
    if target_offset <= 0:
        return
    for _i in target_offset:
        _roll_die()

## Private: Single die roll that also increments offset counter.
func _roll_die() -> int:
    var value: int = rng_instance.randi_range(DEFAULT_DICE_MIN, DEFAULT_DICE_MAX)
    rng_offset_value += 1
    return value
