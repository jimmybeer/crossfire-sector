###############################################################
# project/src/services/persistence_service.gd
# Key Classes      • PersistenceService – atomic JSON saves with checksums
# Key Functions    • save_payload_atomic(), load_payload_with_checksum()
# Critical Consts  • CHECKSUM_PREFIX, TEMP_SUFFIX
# Editor Exports   • (none)
# Dependencies     • state_hasher.gd style checksum helpers
# Last Major Rev   • 25-01-07 – Documented persistence workflow
###############################################################
class_name PersistenceService
extends RefCounted

## Public API: Persistence utilities for checksum-stamped saves with atomic temp+rename writes.

const CHECKSUM_PREFIX := "sha256:"
const TEMP_SUFFIX := ".tmp"

## Public API: Write payload JSON atomically with checksum stamping and optional simulated failures.
static func save_payload_atomic(
        path: String,
        payload: Dictionary,
        options: Dictionary = {}
) -> Dictionary:
    var prepared: Dictionary = _prepare_payload(payload)
    var json_text: String = JSON.stringify(prepared, "  ")
    var bytes: PackedByteArray = json_text.to_utf8_buffer()
    var temp_path: String = path + TEMP_SUFFIX
    var simulate_partial_write: bool = options.get(
        "simulate_partial_write", false
    )

    var dir_err: int = _ensure_parent_directory(temp_path)
    if dir_err != OK:
        return {
            "ok": false,
            "reason": "dir_creation_failed",
            "code": dir_err,
            "path": temp_path
        }

    var write_result: Dictionary = _write_bytes(temp_path, bytes, simulate_partial_write)
    if not write_result.get("ok", false):
        return write_result

    var load_result: Dictionary = load_payload_with_checksum(temp_path)
    if not load_result.get("ok", false):
        return {
            "ok": false,
            "reason": "write_verify_failed",
            "detail": load_result
        }

    var rename_err: int = DirAccess.rename_absolute(temp_path, path)
    if rename_err != OK:
        return {"ok": false, "reason": "rename_failed", "code": rename_err}

    return {
        "ok": true,
        "checksum": load_result.get("checksum", ""),
        "log_checksum": load_result.get("log_checksum", ""),
        "size_bytes": load_result.get("size_bytes", bytes.size()),
        "path": path
    }

## Public API: Load a payload and verify stored checksum plus command-log checksum if present.
static func load_payload_with_checksum(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "reason": "file_missing", "path": path}

    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {"ok": false, "reason": "invalid_json", "path": path}

    var payload: Dictionary = parsed
    var expected_meta_checksum: String = payload.get("meta", {}).get("checksum", "")
    var computed_meta_checksum: String = _compute_checksum_without_meta_checksum(payload)
    var command_log_check: Dictionary = _validate_command_log_checksum(payload)
    var has_expected: bool = expected_meta_checksum != ""
    var meta_ok: bool = has_expected and expected_meta_checksum == computed_meta_checksum
    var all_ok: bool = meta_ok and command_log_check.get("ok", true)

    var result: Dictionary = {
        "ok": all_ok,
        "checksum": computed_meta_checksum,
        "expected_checksum": expected_meta_checksum,
        "log_checksum": command_log_check.get("computed", ""),
        "expected_log_checksum": command_log_check.get("expected", ""),
        "size_bytes": bytes.size(),
        "payload": payload
    }

    if not meta_ok:
        result["reason"] = "checksum_mismatch"
    if not command_log_check.get("ok", true):
        result["reason"] = "command_log_checksum_mismatch"

    return result

## Private: Stamp meta and command-log checksums while stabilizing size_bytes.
static func _prepare_payload(payload: Dictionary) -> Dictionary:
    var prepared: Dictionary = payload.duplicate(true)
    prepared = _stamp_command_log_checksum(prepared)
    prepared = _ensure_meta_dict(prepared)

    var meta: Dictionary = prepared.get("meta", {})
    meta.erase("checksum")
    meta["size_bytes"] = 0
    prepared["meta"] = meta

    var last_checksum: String = ""
    var last_size: int = -1
    for _i in range(4):
        var checksum: String = _compute_checksum_without_meta_checksum(prepared)
        meta = prepared["meta"]
        meta["checksum"] = checksum
        prepared["meta"] = meta

        var size_bytes: int = JSON.stringify(prepared, "  ").to_utf8_buffer().size()
        meta = prepared["meta"]
        meta["size_bytes"] = size_bytes
        prepared["meta"] = meta

        if checksum == last_checksum and size_bytes == last_size:
            break
        last_checksum = checksum
        last_size = size_bytes

    meta = prepared["meta"]
    meta.erase("checksum")
    prepared["meta"] = meta
    var final_checksum: String = _compute_checksum_without_meta_checksum(prepared)
    meta["checksum"] = final_checksum
    meta["size_bytes"] = JSON.stringify(prepared, "  ").to_utf8_buffer().size()
    prepared["meta"] = meta
    return prepared

## Private: Write bytes to a temp path, optionally stopping mid-stream to simulate partial writes.
static func _write_bytes(
        path: String,
        bytes: PackedByteArray,
        simulate_partial_write: bool
) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {
            "ok": false,
            "reason": "open_failed",
            "code": FileAccess.get_open_error(),
            "path": path
        }

    var to_write: PackedByteArray = bytes
    if simulate_partial_write:
        to_write = bytes.slice(0, int(bytes.size() / 2))

    file.store_buffer(to_write)
    file.flush()
    file = null

    if simulate_partial_write:
        return {"ok": false, "reason": "simulated_partial_write", "path": path}

    return {"ok": true, "path": path}

## Private: Stamp checksum for nested command_log without altering original payload.
static func _stamp_command_log_checksum(payload: Dictionary) -> Dictionary:
    var prepared: Dictionary = payload.duplicate(true)
    var match_block: Variant = prepared.get("match", null)
    if match_block is Dictionary:
        var match_dict: Dictionary = match_block
        if match_dict.has("command_log") and match_dict["command_log"] is Dictionary:
            var command_log: Dictionary = match_dict["command_log"].duplicate(true)
            command_log.erase("checksum")
            var log_checksum: String = _compute_checksum(command_log)
            command_log["checksum"] = log_checksum
            match_dict["command_log"] = command_log
            prepared["match"] = match_dict
    return prepared

## Private: Validate a command_log checksum if present; gracefully allow missing checksums.
static func _validate_command_log_checksum(payload: Dictionary) -> Dictionary:
    var match_block: Variant = payload.get("match", null)
    if not (match_block is Dictionary):
        return {"ok": true, "expected": "", "computed": ""}

    var match_dict: Dictionary = match_block
    if not (match_dict.has("command_log") and match_dict["command_log"] is Dictionary):
        return {"ok": true, "expected": "", "computed": ""}

    var log_dict: Dictionary = match_dict["command_log"]
    var expected: String = log_dict.get("checksum", "")
    var log_copy: Dictionary = log_dict.duplicate(true)
    log_copy.erase("checksum")
    var computed: String = _compute_checksum(log_copy)
    var ok: bool = expected == "" or expected == computed
    return {"ok": ok, "expected": expected, "computed": computed}

## Private: Ensure meta section exists with baseline keys.
static func _ensure_meta_dict(payload: Dictionary) -> Dictionary:
    var prepared: Dictionary = payload.duplicate(true)
    var meta: Variant = prepared.get("meta", {})
    if not (meta is Dictionary):
        meta = {}
    if not meta.has("compressed"):
        meta["compressed"] = false
    prepared["meta"] = meta
    return prepared

## Private: Stamp checksum into meta without size_bytes updates.
static func _stamp_meta_checksum(payload: Dictionary) -> Dictionary:
    var prepared: Dictionary = payload.duplicate(true)
    var meta: Variant = prepared.get("meta", {})
    if not (meta is Dictionary):
        meta = {}
    meta.erase("checksum")
    prepared["meta"] = meta
    var checksum: String = _compute_checksum_without_meta_checksum(prepared)
    meta["checksum"] = checksum
    prepared["meta"] = meta
    return prepared

## Private: Update meta size_bytes field based on JSON-encoded bytes.
static func _stamp_size_bytes(payload: Dictionary) -> Dictionary:
    var prepared: Dictionary = payload.duplicate(true)
    var meta: Variant = prepared.get("meta", {})
    if not (meta is Dictionary):
        meta = {}
    var json_text: String = JSON.stringify(prepared, "  ")
    meta["size_bytes"] = json_text.to_utf8_buffer().size()
    prepared["meta"] = meta
    return prepared

## Private: Compute checksum ignoring any existing meta checksum to break circular dependency.
static func _compute_checksum_without_meta_checksum(payload: Dictionary) -> String:
    var copy: Dictionary = payload.duplicate(true)
    var meta: Variant = copy.get("meta", {})
    if meta is Dictionary:
        meta = meta.duplicate(true)
        meta.erase("checksum")
        copy["meta"] = meta
    return _compute_checksum(copy)

## Private: Compute canonical checksum for any Variant.
static func _compute_checksum(value: Variant) -> String:
    var canonical: Variant = _canonicalize(value)
    var json_text: String = JSON.stringify(canonical)
    var ctx: HashingContext = HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(json_text.to_utf8_buffer())
    var digest: PackedByteArray = ctx.finish()
    return CHECKSUM_PREFIX + digest.hex_encode()

## Private: Canonicalize ordering and numeric normalization prior to hashing.
static func _canonicalize(value: Variant) -> Variant:
    if value is float:
        var int_value: int = int(value)
        if float(int_value) == value:
            return int_value
        return value
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

## Private: Ensure target directory exists before writes.
static func _ensure_parent_directory(path: String) -> int:
    var dir_path: String = ProjectSettings.globalize_path(path.get_base_dir())
    var err: int = DirAccess.make_dir_recursive_absolute(dir_path)
    if err == ERR_ALREADY_EXISTS or err == OK:
        return OK
    return err
