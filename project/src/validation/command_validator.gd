###############################################################
# project/src/validation/command_validator.gd
# Key Classes      • CommandValidator – rules/shape validation for commands
# Key Functions    • validate() – public command validation entry
# Critical Consts  • ALLOWED_TYPES, DEFAULT_BOARD
# Editor Exports   • (none)
# Dependencies     • (none)
# Last Major Rev   • 25-01-07 – Documented validator responsibilities
###############################################################
class_name CommandValidator
extends RefCounted

const ALLOWED_TYPES := [
    "deploy",
    "move",
    "attack",
    "melee",
    "first_aid",
    "hold",
    "reroll",
    "advantage_use",
    "event_use",
    "quick_start_move"
]

const DEFAULT_BOARD := {
    "columns": 15,
    "rows": 9,
    "home_zones": [
        {"player_id": "P1", "col_start": 1, "col_end": 2, "row_start": 1, "row_end": 9},
        {"player_id": "P2", "col_start": 14, "col_end": 15, "row_start": 1, "row_end": 9}
    ]
}

## Public API: Validate a command against the provided state/config, returning error
## details and preview data.
func validate(command_data: Dictionary, state: Dictionary, data_config: Dictionary) -> Dictionary:
    var errors: Array = []
    var preview: Dictionary = {}

    var cmd_type: String = command_data.get("type", "")
    if not ALLOWED_TYPES.has(cmd_type):
        errors.append(
            _error("invalid_type", "Unsupported command type: %s" % cmd_type, "AQ-007")
        )

    if command_data.get("sequence", null) == null:
        errors.append(_error("missing_sequence", "Command missing sequence", "MP-001"))

    var payload: Variant = command_data.get("payload", null)
    if payload == null or not (payload is Dictionary):
        errors.append(_error("invalid_payload", "Payload must be an object", "MP-001"))

    var board: Dictionary = _get_board_layout(data_config)
    var optional_rules: Dictionary = state.get(
        "optional_rules", data_config.get("optional_rules", {})
    )
    var units_by_id: Dictionary = _build_unit_map(state)
    var terrain_blocks: Dictionary = _collect_terrain_blocks(state, data_config)
    var occupied_cells: Array = _collect_occupied_cells(state)

    _gates(cmd_type, optional_rules, errors)

    match cmd_type:
        "deploy":
            preview = _validate_deploy(command_data, payload, board, state, errors)
        "move":
            preview = _validate_move(
                command_data,
                payload,
                board,
                terrain_blocks,
                occupied_cells,
                state,
                data_config,
                errors,
                false
            )
        "attack":
            preview = _validate_attack(
                command_data,
                payload,
                board,
                terrain_blocks,
                occupied_cells,
                state,
                data_config,
                errors
            )
        "melee":
            preview = _validate_melee(
                command_data,
                payload,
                board,
                terrain_blocks,
                occupied_cells,
                state,
                data_config,
                errors
            )
        "first_aid":
            preview = _validate_first_aid(
                command_data,
                payload,
                board,
                terrain_blocks,
                occupied_cells,
                state,
                data_config,
                errors
            )
        "hold":
            preview = {"reason": payload.get("reason", "hold")}
        "reroll":
            _validate_reroll(command_data, payload, units_by_id, errors)
        "advantage_use":
            _validate_advantage(command_data, optional_rules, errors)
        "event_use":
            _validate_event(command_data, optional_rules, errors)
        "quick_start_move":
            preview = _validate_quick_start(
                command_data,
                payload,
                board,
                terrain_blocks,
                occupied_cells,
                state,
                data_config,
                errors
            )
        _:
            pass

    var ok: bool = errors.is_empty()
    return {
        "ok": ok,
        "errors": errors,
        "preview": preview
    }

## Private: Top-level optional rules gatekeeping before per-command validation.
func _gates(cmd_type: String, optional_rules: Dictionary, errors: Array) -> void:
    if cmd_type in ["advantage_use", "quick_start_move"] and not optional_rules.get(
        "campaign", true
    ):
        errors.append(
            _error(
                "campaign_disabled",
                "Command not allowed when campaign mode disabled",
                "GR-040"
            )
        )
    if cmd_type == "event_use" and not optional_rules.get("events", false):
        errors.append(_error("events_disabled", "Battle events are disabled", "GR-042"))
    if cmd_type == "advantage_use" and not optional_rules.get("campaign", true):
        errors.append(
            _error("advantage_disabled", "Winner's Advantage requires campaign mode", "GR-040")
        )

## Private: Validate deployment placement and home-zone adherence.
func _validate_deploy(
        command_data: Dictionary,
        payload: Dictionary,
        board: Dictionary,
        state: Dictionary,
        errors: Array
) -> Dictionary:
    var actor_id: String = command_data.get("actor_unit_id", "")
    var position: Dictionary = payload.get("position", {})
    if actor_id == "":
        errors.append(_error("missing_actor", "Deploy requires actor_unit_id", "GR-012"))
    if position.is_empty():
        errors.append(_error("missing_position", "Deploy requires position", "GR-012"))
    if not _is_within_bounds(position, board):
        errors.append(_error("out_of_bounds", "Deployment out of board bounds", "GR-012"))
    var owner_id: String = _unit_owner(actor_id, state)
    if owner_id != "":
        if not _within_home_zone(position, owner_id, board):
            errors.append(_error("home_zone_violation", "Deployment outside home zone", "GR-012"))
    return {"reachable_tiles": [position]}

## Private: Validate a move path, applying allowances and terrain checks. Optionally
## halves move for combos.
func _validate_move(
        command_data: Dictionary,
        payload: Dictionary,
        board: Dictionary,
        terrain_blocks: Dictionary,
        occupied: Array,
        state: Dictionary,
        data_config: Dictionary,
        errors: Array,
        half_move: bool
) -> Dictionary:
    var actor_id: String = command_data.get("actor_unit_id", "")
    var unit_state: Dictionary = _get_unit_state(actor_id, state)
    if unit_state.is_empty():
        errors.append(
            _error("missing_unit", "Move requires valid actor unit", "GR-017")
        )
        return {}
    var move_path: Array = payload.get("path", payload.get("move_path", []))
    if move_path.is_empty():
        errors.append(_error("missing_path", "Move requires path", "GR-018"))
        return {}
    var move_limit: int = _get_move_allowance(unit_state, state, data_config, half_move)
    _validate_path(move_path, board, terrain_blocks, occupied, errors)
    if move_limit > 0 and move_path.size() > move_limit:
        errors.append(_error("move_too_far", "Path exceeds move allowance", "GR-018"))
    var end_cell: Dictionary = move_path.back()
    if _is_occupied(end_cell, occupied):
        errors.append(
            _error("occupied_destination", "Cannot end move on occupied cell", "GR-032.1")
        )
    return {"reachable_tiles": move_path}

## Private: Validate ranged attack including LOS, range budget, and cover preview.
func _validate_attack(
        command_data: Dictionary,
        payload: Dictionary,
        board: Dictionary,
        terrain_blocks: Dictionary,
        occupied: Array,
        state: Dictionary,
        data_config: Dictionary,
        errors: Array
) -> Dictionary:
    var actor_id: String = command_data.get("actor_unit_id", "")
    var target_cell: Dictionary = payload.get("target_cell", {})
    if actor_id == "" or target_cell.is_empty():
        errors.append(_error("missing_actor_target", "Attack requires actor and target", "GR-019"))
        return {}
    var move_preview: Dictionary = _validate_move(
        command_data,
        payload,
        board,
        terrain_blocks,
        occupied,
        state,
        data_config,
        errors,
        true
    )
    var final_tiles: Array = move_preview.get("reachable_tiles", [])
    var final_pos: Dictionary = final_tiles.back() if final_tiles.size() > 0 else _unit_position(
        actor_id, state
    )
    var unit_range: int = _get_unit_stat(actor_id, state, data_config, "range")
    var distance: int = _manhattan_distance(final_pos, target_cell)
    if unit_range > 0 and distance > unit_range:
        errors.append(_error("out_of_range", "Attack exceeds range", "GR-019"))
    var los_ok: bool = _has_line_of_sight(final_pos, target_cell, terrain_blocks, occupied, board)
    if not los_ok:
        errors.append(_error("los_blocked", "Line of sight blocked", "GR-031"))
    var cover: bool = _has_cover(target_cell, terrain_blocks, occupied)
    return {
        "reachable_tiles": move_preview.get("reachable_tiles", []),
        "los": los_ok,
        "cover": cover,
        "range_cost": distance
    }

## Private: Validate melee adjacency requirement after movement.
func _validate_melee(
        command_data: Dictionary,
        payload: Dictionary,
        board: Dictionary,
        terrain_blocks: Dictionary,
        occupied: Array,
        state: Dictionary,
        data_config: Dictionary,
        errors: Array
) -> Dictionary:
    var target_cell: Dictionary = payload.get("target_cell", {})
    if target_cell.is_empty():
        errors.append(_error("missing_target", "Melee requires target cell", "GR-027"))
    var move_preview: Dictionary = _validate_move(
        command_data,
        payload,
        board,
        terrain_blocks,
        occupied,
        state,
        data_config,
        errors,
        true
    )
    var final_tiles: Array = move_preview.get("reachable_tiles", [])
    var final_pos: Dictionary = final_tiles.back() if final_tiles.size() > 0 else _unit_position(
        command_data.get("actor_unit_id", ""),
        state
    )
    if _manhattan_distance(final_pos, target_cell) != 1:
        errors.append(_error("not_adjacent", "Melee requires adjacency", "GR-027"))
    return move_preview

## Private: Validate First Aid adjacency and target presence.
func _validate_first_aid(
        command_data: Dictionary,
        payload: Dictionary,
        board: Dictionary,
        terrain_blocks: Dictionary,
        occupied: Array,
        state: Dictionary,
        data_config: Dictionary,
        errors: Array
) -> Dictionary:
    var target_unit: String = command_data.get(
        "target_unit_id", payload.get("target_unit_id", "")
    )
    if target_unit == "":
        errors.append(_error("missing_target_unit", "First Aid requires target unit", "GR-020"))
    var move_preview: Dictionary = _validate_move(
        command_data,
        payload,
        board,
        terrain_blocks,
        occupied,
        state,
        data_config,
        errors,
        true
    )
    var final_tiles: Array = move_preview.get("reachable_tiles", [])
    var final_pos: Dictionary = final_tiles.back() if final_tiles.size() > 0 else _unit_position(
        command_data.get("actor_unit_id", ""),
        state
    )
    var target_pos: Dictionary = _unit_position(target_unit, state)
    if _manhattan_distance(final_pos, target_pos) != 1:
        errors.append(_error("not_adjacent", "First Aid requires adjacency", "GR-020"))
    return move_preview

## Private: Validate reroll availability and payload shape.
func _validate_reroll(
        command_data: Dictionary,
        payload: Dictionary,
        units_by_id: Dictionary,
        errors: Array
) -> void:
    if not payload.has("source"):
        errors.append(_error("missing_source", "Reroll requires source", "GR-045"))
    var actor_id: String = command_data.get("actor_unit_id", "")
    var unit_state: Dictionary = units_by_id.get(actor_id, {})
    if unit_state.is_empty():
        return
    var rerolls_left: int = unit_state.get("rerolls_available", 0)
    if rerolls_left <= 0:
        errors.append(_error("no_rerolls", "No rerolls available", "GR-045"))

## Private: Validate campaign-gated advantages.
func _validate_advantage(
        _command_data: Dictionary,
        optional_rules: Dictionary,
        errors: Array
) -> void:
    # TODO: Revisit whether advantage validation needs command context.
    _ = _command_data
    if not optional_rules.get("campaign", true):
        errors.append(_error("campaign_disabled", "Advantages require campaign", "GR-040"))

## Private: Validate event usage when events enabled and id present.
func _validate_event(command_data: Dictionary, optional_rules: Dictionary, errors: Array) -> void:
    if not optional_rules.get("events", false):
        errors.append(_error("events_disabled", "Events disabled", "GR-042"))
    if not command_data.get("payload", {}).has("event_id"):
        errors.append(_error("missing_event_id", "Event requires event_id", "GR-042"))

## Private: Validate campaign quick start group moves before round 1.
func _validate_quick_start(
        command_data: Dictionary,
        payload: Dictionary,
        board: Dictionary,
        terrain_blocks: Dictionary,
        occupied: Array,
        state: Dictionary,
        data_config: Dictionary,
        errors: Array
) -> Dictionary:
    # TODO: Confirm whether quick start needs the full command_data context.
    _ = command_data
    var unit_ids: Array = payload.get("unit_ids", [])
    if unit_ids.is_empty():
        errors.append(_error("missing_unit_ids", "Quick Start requires unit_ids", "DA-017"))
    var round_state: Dictionary = state.get("round_state", {})
    if round_state.get("round_number", 1) > 1:
        errors.append(_error("wrong_timing", "Quick Start only before round 1", "DA-017"))
    var previews: Array = []
    var payload_paths: Variant = payload.get("paths", [])
    var has_paths: bool = payload_paths is Array and payload_paths.size() == unit_ids.size()
    for unit_id in unit_ids:
        var unit_state: Dictionary = _get_unit_state(unit_id, state)
        var path: Array = []
        if has_paths:
            path = payload_paths[unit_ids.find(unit_id)]
        var move_cmd: Dictionary = {
            "actor_unit_id": unit_id,
            "payload": {"path": path}
        }
        var preview: Dictionary = _validate_move(
            move_cmd,
            move_cmd.payload,
            board,
            terrain_blocks,
            occupied,
            state,
            data_config,
            errors,
            false
        )
        previews.append(preview)
    return {"quick_start_previews": previews}

## Private: Choose board layout from data_config with fallback to default board spec.
func _get_board_layout(data_config: Dictionary) -> Dictionary:
    return data_config.get("board_layout", DEFAULT_BOARD)

## Private: Build unit lookup keyed by id for fast validation checks.
func _build_unit_map(state: Dictionary) -> Dictionary:
    var units: Dictionary = {}
    var unit_states: Array = state.get("unit_states", [])
    for unit_state in unit_states:
        if unit_state is Dictionary:
            units[unit_state.get("id", "")] = unit_state
    return units

## Private: Collect terrain cells that block LoS or provide cover based on templates.
func _collect_terrain_blocks(state: Dictionary, data_config: Dictionary) -> Dictionary:
    var blocks: Dictionary = {"blocking": [], "cover": []}
    var terrain_instances: Array = state.get("terrain", [])
    var templates: Dictionary = _terrain_templates(data_config)
    for instance in terrain_instances:
        var template_id: String = instance.get("template_id", "")
        var template: Dictionary = templates.get(template_id, {})
        var cells: Array = instance.get("cells", [])
        if template.get("blocks_los", true):
            blocks["blocking"].append_array(cells)
        if template.get("provides_cover", true):
            blocks["cover"].append_array(cells)
    return blocks

## Private: Build terrain templates keyed by id for quick lookup.
func _terrain_templates(data_config: Dictionary) -> Dictionary:
    var templates: Dictionary = {}
    var list: Array = data_config.get("terrain_templates", [])
    for template in list:
        templates[template.get("id", "")] = template
    return templates

## Private: Gather occupied cells (non-destroyed units) for blocking movement/LoS checks.
func _collect_occupied_cells(state: Dictionary) -> Array:
    var occupied: Array = []
    var unit_states: Array = state.get("unit_states", [])
    for unit_state in unit_states:
        if unit_state is Dictionary and unit_state.get("status", "alive") != "destroyed":
            occupied.append(unit_state.get("position", {}))
    return occupied

## Private: Get a single unit state by id (empty if not found).
func _get_unit_state(unit_id: String, state: Dictionary) -> Dictionary:
    var unit_states: Array = state.get("unit_states", [])
    for unit_state in unit_states:
        if unit_state.get("id", "") == unit_id:
            return unit_state
    return {}

## Private: Convenience to fetch a unit's position.
func _unit_position(unit_id: String, state: Dictionary) -> Dictionary:
    var unit_state: Dictionary = _get_unit_state(unit_id, state)
    return unit_state.get("position", {})

## Private: Resolve owning player id for a unit.
func _unit_owner(unit_id: String, state: Dictionary) -> String:
    var unit_state: Dictionary = _get_unit_state(unit_id, state)
    return unit_state.get("owner_id", "")

## Private: Fetch player state block by id.
func _get_player_state(player_id: String, state: Dictionary) -> Dictionary:
    var players: Array = state.get("player_states", [])
    for ps in players:
        if ps.get("player_id", "") == player_id:
            return ps
    return {}

## Private: Pull a stat from faction data, defaulting to 0.
func _get_unit_stat(
        unit_id: String,
        state: Dictionary,
        data_config: Dictionary,
        stat_name: String
) -> int:
    var owner_id: String = _unit_owner(unit_id, state)
    var player_state: Dictionary = _get_player_state(owner_id, state)
    var faction_id: String = player_state.get("faction_id", "")
    var factions: Dictionary = data_config.get("factions", {})
    var faction: Dictionary = factions.get(faction_id, {})
    var base_stats: Dictionary = faction.get("base_stats", {})
    var stat_val: Variant = base_stats.get(stat_name, 0)
    if stat_val is int:
        return stat_val
    return 0

## Private: Compute move allowance; halves allowed distance for certain validations.
func _get_move_allowance(
        unit_state: Dictionary,
        state: Dictionary,
        data_config: Dictionary,
        half_move: bool
) -> int:
    var move_stat: int = _get_unit_stat(unit_state.get("id", ""), state, data_config, "move")
    if half_move:
        return int(ceil(move_stat / 2.0))
    return move_stat

## Private: Validate every cell in a path for bounds, adjacency, and impassable terrain.
func _validate_path(
        path: Array,
        board: Dictionary,
        terrain_blocks: Dictionary,
        occupied: Array,
        errors: Array
) -> void:
    # TODO: Revisit whether occupied cells should influence path validation here.
    _ = occupied
    var previous: Dictionary = {}
    for idx in range(path.size()):
        var cell: Dictionary = path[idx]
        if not _is_within_bounds(cell, board):
            errors.append(_error("out_of_bounds", "Path leaves board bounds", "GR-018"))
        if _is_impassable(cell, terrain_blocks):
            errors.append(_error("impassable", "Path crosses impassable terrain", "GR-018"))
        if idx > 0 and not _is_adjacent(previous, cell):
            errors.append(_error("non_adjacent_step", "Path must move to adjacent cells", "GR-018"))
        previous = cell
    # allow pass-through occupied but not end; end check handled separately

## Private: Check board bounds for a cell.
func _is_within_bounds(cell: Dictionary, board: Dictionary) -> bool:
    var col: int = int(cell.get("col", -1))
    var row: int = int(cell.get("row", -1))
    return (
        col >= 1
        and col <= int(board.get("columns", 0))
        and row >= 1
        and row <= int(board.get("rows", 0))
    )

## Private: Ensure deployment stays within the player's home zone.
func _within_home_zone(cell: Dictionary, player_id: String, board: Dictionary) -> bool:
    var zones: Array = board.get("home_zones", [])
    for zone in zones:
        if zone.get("player_id", "") == player_id:
            var col: int = int(cell.get("col", -1))
            var row: int = int(cell.get("row", -1))
            if (
                col >= int(zone.get("col_start", 0))
                and col <= int(zone.get("col_end", 0))
                and row >= int(zone.get("row_start", 0))
                and row <= int(zone.get("row_end", 0))
            ):
                return true
    return false

## Private: Neighbor check using 8-direction adjacency.
func _is_adjacent(a: Dictionary, b: Dictionary) -> bool:
    if a.is_empty():
        return true
    var dc: int = abs(int(a.get("col", 0)) - int(b.get("col", 0)))
    var dr: int = abs(int(a.get("row", 0)) - int(b.get("row", 0)))
    return dc <= 1 and dr <= 1 and (dc + dr) > 0

## Private: Determine if a cell is blocked by terrain.
func _is_impassable(cell: Dictionary, terrain_blocks: Dictionary) -> bool:
    return _cell_in_list(cell, terrain_blocks.get("blocking", []))

## Private: Determine if a cell is already occupied.
func _is_occupied(cell: Dictionary, occupied: Array) -> bool:
    return _cell_in_list(cell, occupied)

## Private: Shared cell equality helper using col/row.
func _cell_in_list(cell: Dictionary, cells: Array) -> bool:
    for c in cells:
        if c.get("col", -1) == cell.get("col", -2) and c.get("row", -1) == cell.get("row", -2):
            return true
    return false

## Private: Manhattan distance for grid movement/range.
func _manhattan_distance(a: Dictionary, b: Dictionary) -> int:
    return (
        abs(int(a.get("col", 0)) - int(b.get("col", 0)))
        + abs(int(a.get("row", 0)) - int(b.get("row", 0)))
    )

## Private: Line-of-sight check walking a Bresenham line through terrain/occupied blockers.
func _has_line_of_sight(
        start_cell: Dictionary,
        target_cell: Dictionary,
        terrain_blocks: Dictionary,
        occupied: Array,
        board: Dictionary
) -> bool:
    var line: Array = _bresenham_line(start_cell, target_cell)
    for point in line:
        if not _is_within_bounds(point, board):
            return false
        if _is_impassable(point, terrain_blocks):
            return false
        if _is_occupied(point, occupied):
            return false
    return true

## Private: Bresenham line implementation to enumerate intermediate grid cells
## (excluding endpoints).
func _bresenham_line(start_cell: Dictionary, end_cell: Dictionary) -> Array:
    var points: Array = []
    var x0: int = int(start_cell.get("col", 0))
    var y0: int = int(start_cell.get("row", 0))
    var x1: int = int(end_cell.get("col", 0))
    var y1: int = int(end_cell.get("row", 0))
    var dx: int = abs(x1 - x0)
    var dy: int = -abs(y1 - y0)
    var sx: int = 1 if x0 < x1 else -1
    var sy: int = 1 if y0 < y1 else -1
    var err: int = dx + dy
    while true:
        if not (x0 == x1 and y0 == y1):
            points.append({"col": x0, "row": y0})
        if x0 == x1 and y0 == y1:
            break
        var e2: int = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    if points.size() > 0:
        points.pop_back() # exclude target
    if points.size() > 0:
        points.pop_front() # exclude start
    return points

## Private: Simple cover heuristic that checks blockers on or adjacent to the target cell.
func _has_cover(target_cell: Dictionary, terrain_blocks: Dictionary, occupied: Array) -> bool:
    if _cell_in_list(target_cell, terrain_blocks.get("cover", [])):
        return true
    # simple heuristic: cover if any blocker adjacent
    var adjacents: Array = [
        {"col": target_cell.get("col", 0) + 1, "row": target_cell.get("row", 0)},
        {"col": target_cell.get("col", 0) - 1, "row": target_cell.get("row", 0)},
        {"col": target_cell.get("col", 0), "row": target_cell.get("row", 0) + 1},
        {"col": target_cell.get("col", 0), "row": target_cell.get("row", 0) - 1}
    ]
    for adj in adjacents:
        if _cell_in_list(adj, terrain_blocks.get("blocking", [])) or _cell_in_list(adj, occupied):
            return true
    return false

## Private: Build an error payload with optional requirement trace id.
func _error(code: String, message: String, requirement_id: String = "") -> Dictionary:
    var error_dict: Dictionary = {"code": code, "message": message}
    if requirement_id != "":
        error_dict["requirement_id"] = requirement_id
    return error_dict
