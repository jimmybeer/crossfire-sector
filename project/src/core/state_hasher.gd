###############################################################
# project/src/core/state_hasher.gd
# Key Classes      • StateHasher – canonical JSON + SHA-256 hashing
# Key Functions    • hash_state() – public hash helper
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • HashingContext
# Last Major Rev   • 25-01-07 – Documented hashing helpers
###############################################################
class_name StateHasher
extends RefCounted

## Public API: Deterministic state hashing helper using canonical JSON + SHA-256.

## Public: Hash any Variant by first canonicalizing ordering and encoding.
static func hash_state(state: Variant) -> String:
    var canonical: Variant = _canonicalize(state)
    var json: String = JSON.stringify(canonical)
    var ctx: HashingContext = HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(json.to_utf8_buffer())
    var digest: PackedByteArray = ctx.finish()
    return "sha256:" + digest.hex_encode()

## Private: Normalize ordering and numeric types to make hashes stable across runs.
static func _canonicalize(value: Variant) -> Variant:
    if value is Dictionary:
        var ordered: Dictionary = {}
        var keys: Array = value.keys()
        keys.sort()
        for key in keys:
            ordered[key] = _canonicalize(value[key])
        return ordered
    if value is Array:
        var arr: Array = []
        for item in value:
            arr.append(_canonicalize(item))
        return arr
    return value
