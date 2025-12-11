###############################################################
# project/src/ui/scenes/los_bbox_slice.gd
# Key Classes      • LoSBBoxSlice – Bounding box LoS visualization sandbox
# Key Functions    • _compute_raycast_visibility(), _build_highlight_tiles()
# Critical Consts  • CELL_SIZE, SAMPLE_OFFSETS, SCENARIOS
# Editor Exports   • (none)
# Dependencies     • BattlefieldView, CommandValidator, UIContracts
# Last Major Rev   • 25-02-08 – Bounding-box raycast prototype scene
###############################################################
class_name LoSBBoxSlice
extends Control

const BattlefieldView := preload("res://project/src/ui/scenes/battlefield_view.gd")
const CommandValidator := preload("res://project/src/validation/command_validator.gd")
const UIContracts := preload("res://project/src/ui/ui_contracts.gd")

const CELL_SIZE: float = 32.0
const SAMPLE_OFFSETS: Array = [
	Vector2(0.15, 0.15),
	Vector2(0.5, 0.15),
	Vector2(0.85, 0.15),
	Vector2(0.15, 0.5),
	Vector2(0.5, 0.5),
	Vector2(0.85, 0.5),
	Vector2(0.15, 0.85),
	Vector2(0.5, 0.85),
	Vector2(0.85, 0.85)
]

const BOARD_LAYOUT := {"columns": 15, "rows": 9}
const TERRAIN_TEMPLATES := [
	{
		"id": "blocking_rock",
		"blocks_los": true,
		"provides_cover": true,
		"impassable": true
	}
]

const SCENARIOS := [
	{
		"title": "Open Field Line",
		"description": "No terrain: clear LoS from attacker to target across the board.",
		"attacker_id": "unit_a",
		"target_id": "unit_b",
		"attacker_pos": {"col": 2, "row": 4},
		"target_pos": {"col": 12, "row": 4},
		"terrain": []
	},
	{
		"title": "Direct Block",
		"description": "A blocking rock sits directly between attacker and target along the same row.",
		"attacker_id": "unit_a",
		"target_id": "unit_b",
		"attacker_pos": {"col": 3, "row": 3},
		"target_pos": {"col": 11, "row": 3},
		"terrain": [
			{
				"template_id": "blocking_rock",
				"cells": [
					{"col": 7, "row": 3}
				]
			}
		]
	},
	{
		"title": "Corner Block",
		"description": "Two rocks create a corner; LoS should not cut through the corner.",
		"attacker_id": "unit_a",
		"target_id": "unit_b",
		"attacker_pos": {"col": 5, "row": 2},
		"target_pos": {"col": 9, "row": 6},
		"terrain": [
			{
				"template_id": "blocking_rock",
				"cells": [
					{"col": 6, "row": 3},
					{"col": 7, "row": 4}
				]
			},
			{
				"template_id": "blocking_rock",
				"cells": [
					{"col": 8, "row": 5}
				]
			}
		]
	},
	{
		"title": "Target in Cover",
		"description": "Rock adjacent to the target should provide cover even if LoS reaches the square.",
		"attacker_id": "unit_a",
		"target_id": "unit_b",
		"attacker_pos": {"col": 2, "row": 8},
		"target_pos": {"col": 10, "row": 8},
		"terrain": [
			{
				"template_id": "blocking_rock",
				"cells": [
					{"col": 10, "row": 7}
				]
			}
		]
	},
	{
		"title": "Diagonal Obstruction",
		"description": "Stone near the diagonal path should block LoS before reaching the target.",
		"attacker_id": "unit_a",
		"target_id": "unit_b",
		"attacker_pos": {"col": 4, "row": 5},
		"target_pos": {"col": 11, "row": 2},
		"terrain": [
			{
				"template_id": "blocking_rock",
				"cells": [
					{"col": 7, "row": 4}
				]
			}
		]
	},
	{
		"title": "Dense Cover",
		"description": "Multiple rocks shield the target and add adjacent cover markers.",
		"attacker_id": "unit_a",
		"target_id": "unit_b",
		"attacker_pos": {"col": 6, "row": 1},
		"target_pos": {"col": 12, "row": 3},
		"terrain": [
			{
				"template_id": "blocking_rock",
				"cells": [
					{"col": 11, "row": 2},
					{"col": 11, "row": 3},
					{"col": 12, "row": 2}
				]
			}
		]
	},
	{
		"title": "Randomized Sample",
		"description": "Each select randomizes unit positions and 4 blocking rocks.",
		"attacker_id": "unit_a",
		"target_id": "unit_b",
		"attacker_pos": {"col": 1, "row": 1},
		"target_pos": {"col": 15, "row": 9},
		"terrain": [],
		"random": true
	}
]

var validator: CommandValidator = CommandValidator.new()
var current_state: Dictionary = {}
var current_highlights: Array = []
var current_rays: Array = []
var log_lines: Array = []
var current_scenario_idx: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var battlefield_view: BattlefieldView = $BattlefieldView
@onready var scenario_list: ItemList = $Sidebar/ScenarioListContainer/ScenarioList
@onready var scenario_description: RichTextLabel = $Sidebar/ScenarioDescription
@onready var coverage_label: Label = $Sidebar/CoverageLabel

func _ready() -> void:
	rng.randomize()
	for scenario in SCENARIOS:
		scenario_list.add_item(scenario["title"])
	scenario_list.select(0)
	scenario_list.connect("item_selected", Callable(self, "_on_scenario_selected"))
	battlefield_view.gui_input.connect(Callable(self, "_on_battlefield_input"))
	scenario_description.bbcode_enabled = true
	_load_scenario(0)

func _on_scenario_selected(index: int) -> void:
	if index < 0 or index >= SCENARIOS.size():
		return
	_load_scenario(index)

func _load_scenario(index: int) -> void:
	current_scenario_idx = index
	var scenario: Dictionary = SCENARIOS[index]
	if scenario.get("random", false):
		scenario = _build_random_scenario(scenario)
	scenario_description.bbcode_text = "[b]%s[/b]\n%s" % [scenario["title"], scenario["description"]]
	coverage_label.text = "Coverage: --"
	log_lines = []
	current_state = _build_state_from_scenario(scenario)
	current_highlights = []
	current_rays = []
	_enqueue_log("[scenario] %s" % scenario["title"])
	_evaluate_unit(scenario["attacker_id"])

func _build_state_from_scenario(scenario: Dictionary) -> Dictionary:
	var units: Array = []
	units.append(_unit_entry(scenario["attacker_id"], scenario["attacker_pos"], "P1"))
	units.append(_unit_entry(scenario["target_id"], scenario["target_pos"], "P2"))
	return {
		"board": BOARD_LAYOUT.duplicate(true),
		"unit_states": units,
		"terrain": scenario["terrain"]
	}


func _build_random_scenario(template: Dictionary) -> Dictionary:
	var board: Dictionary = BOARD_LAYOUT
	var taken: Array = []
	var attacker_pos: Dictionary = _random_cell(board, taken)
	taken.append(attacker_pos)
	var target_pos: Dictionary = _random_cell(board, taken)
	taken.append(target_pos)
	var terrain_cells: Array = []
	for i in range(4):
		var cell: Dictionary = _random_cell(board, taken)
		taken.append(cell)
		terrain_cells.append(cell)
	var description: String = "Random layout: attacker %d,%d | target %d,%d | rocks: %s" % [
		int(attacker_pos.get("col", 0)),
		int(attacker_pos.get("row", 0)),
		int(target_pos.get("col", 0)),
		int(target_pos.get("row", 0)),
		_describe_cells(terrain_cells)
	]
	return {
		"title": template.get("title", "Randomized Sample"),
		"description": description,
		"attacker_id": template.get("attacker_id", "unit_a"),
		"target_id": template.get("target_id", "unit_b"),
		"attacker_pos": attacker_pos,
		"target_pos": target_pos,
		"terrain": [
			{
				"template_id": "blocking_rock",
				"cells": terrain_cells
			}
		]
	}


func _random_cell(board: Dictionary, taken: Array) -> Dictionary:
	var cols: int = int(board.get("columns", BOARD_LAYOUT["columns"]))
	var rows: int = int(board.get("rows", BOARD_LAYOUT["rows"]))
	while true:
		var col: int = rng.randi_range(1, cols)
		var row: int = rng.randi_range(1, rows)
		var candidate: Dictionary = {"col": col, "row": row}
		if not _cell_taken(candidate, taken):
			return candidate
	return {"col": 1, "row": 1}


func _cell_taken(candidate: Dictionary, taken: Array) -> bool:
	for cell in taken:
		var same_col: bool = int(cell.get("col", -1)) == int(candidate.get("col", -2))
		var same_row: bool = int(cell.get("row", -1)) == int(candidate.get("row", -2))
		if same_col and same_row:
			return true
	return false


func _describe_cells(cells: Array) -> String:
	var parts: Array = []
	for cell in cells:
		parts.append("%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))])
	return String(", ").join(parts)

func _unit_entry(unit_id: String, position: Dictionary, owner_id: String) -> Dictionary:
	return {
		"id": unit_id,
		"unit_id": unit_id,
		"owner_id": owner_id,
		"position": {"col": int(position.get("col", 1)), "row": int(position.get("row", 1))},
		"status": "alive"
	}

func _on_battlefield_input(event: InputEvent) -> void:
	var left_click: bool = (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	)
	if not left_click:
		return
	var grid_click: Vector2 = battlefield_view.gui_to_grid_position(event.position)
	var col: int = int(floor(grid_click.x / CELL_SIZE)) + 1
	var row: int = int(floor(grid_click.y / CELL_SIZE)) + 1
	var board: Dictionary = current_state.get("board", BOARD_LAYOUT)
	var board_cols: int = int(board.get("columns", BOARD_LAYOUT["columns"]))
	var board_rows: int = int(board.get("rows", BOARD_LAYOUT["rows"]))
	var outside: bool = (
		grid_click.x < 0.0
		or grid_click.y < 0.0
		or col < 1
		or row < 1
		or col > board_cols
		or row > board_rows
	)
	if outside:
		_enqueue_log(
			"[input] click outside board (gui=%.1f,%.1f)" % [event.position.x, event.position.y]
		)
		return
	var found: String = _unit_at(col, row)
	var message: String = "[input] selected col=%d row=%d" % [col, row]
	if found != "":
		message += " unit=%s" % found
		_enqueue_log(message)
		_evaluate_unit(found)
	else:
		_enqueue_log("%s no unit there" % message)

func _evaluate_unit(unit_id: String) -> void:
	var target_id: String = _other_unit(unit_id)
	if target_id == "":
		return
	var board: Dictionary = current_state.get("board", BOARD_LAYOUT)
	var terrain_blocks: Dictionary = validator._collect_terrain_blocks(
		current_state, {"terrain_templates": TERRAIN_TEMPLATES, "board_layout": board}
	)
	var occupied: Array = validator._collect_occupied_cells(current_state)
	var blockers: Array = _build_blockers(unit_id, target_id, terrain_blocks)
	var result: Dictionary = _compute_raycast_visibility(unit_id, target_id, blockers)
	var coverage_fraction: float = result.get("coverage", 0.0)
	var percent_visible: float = coverage_fraction * 100.0
	coverage_label.text = "Coverage: %.0f%% (%d/%d samples)" % [
		percent_visible,
		int(result.get("visible_samples", 0)),
		int(result.get("sample_count", 0))
	]
	current_highlights = _build_highlight_tiles(unit_id, target_id, terrain_blocks, blockers)
	current_rays = _build_rays(result)
	_update_battlefield_snapshot()
	var message: String = "[bbox-los] %s -> %s coverage=%.0f%%" % [unit_id, target_id, percent_visible]
	_enqueue_log(message)
	for ray in result.get("rays", []):
		if ray.get("blocked", false):
			var blocker: Dictionary = ray.get("hit", {}).get("blocker", {})
			var blocker_cell: Dictionary = blocker.get("cell", {})
			var blocker_kind: String = blocker.get("kind", "unknown")
			_enqueue_log(
				"[ray] sample %s blocked by %s at col=%d row=%d" % [
					_format_sample(ray.get("sample_point", Vector2.ZERO)),
					blocker_kind,
					int(blocker_cell.get("col", 0)),
					int(blocker_cell.get("row", 0))
				]
			)
		else:
			_enqueue_log(
				"[ray] sample %s clear" % _format_sample(ray.get("sample_point", Vector2.ZERO))
			)

func _compute_raycast_visibility(
	attacker_id: String, target_id: String, blockers: Array
) -> Dictionary:
	var attacker_center: Vector2 = _unit_center(attacker_id)
	var target_box: Rect2 = _unit_box(target_id)
	var sample_points: Array = _sample_target_box(target_box)
	var rays: Array = []
	var visible_samples: int = 0
	for point in sample_points:
		var hit: Dictionary = _first_blocker_hit(attacker_center, point, blockers)
		var blocked: bool = hit.get("hit", false)
		if not blocked:
			visible_samples += 1
		rays.append({
			"sample_point": point,
			"blocked": blocked,
			"hit": hit,
			"sample_cell": _world_to_cell(point)
		})
	var coverage_fraction: float = 0.0
	if sample_points.size() > 0:
		coverage_fraction = float(visible_samples) / float(sample_points.size())
	return {
		"rays": rays,
		"coverage": coverage_fraction,
		"visible_samples": visible_samples,
		"sample_count": sample_points.size(),
		"origin": attacker_center,
		"target_box": target_box
	}

func _build_blockers(
	attacker_id: String, target_id: String, terrain_blocks: Dictionary
) -> Array:
	var blockers: Array = []
	for cell in terrain_blocks.get("blocking", []):
		blockers.append({
			"rect": _cell_box(cell),
			"cell": _normalize_cell(cell),
			"kind": "terrain"
		})
	for unit in current_state.get("unit_states", []):
		var uid: String = str(unit.get("id", unit.get("unit_id", "")))
		if uid == attacker_id or uid == target_id:
			continue
		var cell: Dictionary = unit.get("position", {})
		blockers.append({
			"rect": _cell_box(cell),
			"cell": _normalize_cell(cell),
			"kind": "unit"
		})
	return blockers

func _first_blocker_hit(origin: Vector2, target_point: Vector2, blockers: Array) -> Dictionary:
	var nearest_distance: float = INF
	var payload: Dictionary = {"hit": false}
	for blocker in blockers:
		var rect: Rect2 = blocker.get("rect", Rect2())
		var hit: Dictionary = _segment_hits_rect(origin, target_point, rect)
		if hit.get("hit", false):
			var distance: float = hit.get("distance", INF)
			if distance < nearest_distance:
				nearest_distance = distance
				payload = {
					"hit": true,
					"point": hit.get("point", origin),
					"distance": distance,
					"blocker": blocker
				}
	return payload

func _segment_hits_rect(origin: Vector2, target_point: Vector2, rect: Rect2) -> Dictionary:
	var corners: Array = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y)
	]
	var edges: Array = [
		[corners[0], corners[1]],
		[corners[1], corners[2]],
		[corners[2], corners[3]],
		[corners[3], corners[0]]
	]
	var closest_distance: float = INF
	var closest_point: Vector2 = Vector2.ZERO
	var found: bool = false
	for edge in edges:
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			origin, target_point, edge[0], edge[1]
		)
		if intersection is Vector2:
			var intersection_point: Vector2 = intersection
			var distance: float = origin.distance_to(intersection_point)
			if distance < closest_distance:
				closest_distance = distance
				closest_point = intersection_point
				found = true
	if found:
		return {"hit": true, "point": closest_point, "distance": closest_distance}
	if rect.has_point(origin):
		return {"hit": true, "point": origin, "distance": 0.0}
	return {"hit": false}

func _build_highlight_tiles(
	attacker_id: String,
	target_id: String,
	terrain_blocks: Dictionary,
	blockers: Array
) -> Array:
	var tiles: Array = []
	var attacker_cell: Dictionary = _unit_position(attacker_id)
	var target_cell: Dictionary = _unit_position(target_id)
	var target_tint: Color = Color(1.0, 0.8, 0.0, 0.65)
	tiles.append(_highlight_tile(attacker_cell, Color(0.1, 0.2, 0.9, 0.8), "attacker"))
	tiles.append(_highlight_tile(target_cell, target_tint, "target"))
	for blocking_cover in terrain_blocks.get("cover", []):
		tiles.append(_highlight_tile(_normalize_cell(blocking_cover), Color(0.9, 0.9, 0.0, 0.6), "cover"))
	for blocker in blockers:
		tiles.append(
			_highlight_tile(
				blocker.get("cell", {}),
				Color(0.3, 0.3, 0.35, 0.65),
				blocker.get("kind", "blocker")
			)
		)
	return tiles


func _build_rays(result: Dictionary) -> Array:
	var rays: Array = []
	var origin: Vector2 = result.get("origin", Vector2.ZERO)
	for ray in result.get("rays", []):
		var blocked: bool = ray.get("blocked", false)
		var end_point: Vector2 = ray.get("sample_point", Vector2.ZERO)
		if blocked:
			end_point = ray.get("hit", {}).get("point", end_point)
		var color: Color = Color(0.2, 0.9, 0.5, 0.8)
		if blocked:
			color = Color(0.95, 0.35, 0.8, 0.8)
		rays.append({
			"from": origin,
			"to": end_point,
			"color": color,
			"width": 3.0 if blocked else 2.0
		})
	return rays

func _sample_target_box(box: Rect2) -> Array:
	var samples: Array = []
	for offset in SAMPLE_OFFSETS:
		var point: Vector2 = box.position + Vector2(box.size.x * offset.x, box.size.y * offset.y)
		samples.append(point)
	return samples

func _unit_box(unit_id: String) -> Rect2:
	var position: Dictionary = _unit_position(unit_id)
	return _cell_box(position)

func _cell_box(cell: Dictionary) -> Rect2:
	var col: float = float(cell.get("col", 1))
	var row: float = float(cell.get("row", 1))
	var top_left: Vector2 = Vector2((col - 1.0) * CELL_SIZE, (row - 1.0) * CELL_SIZE)
	return Rect2(top_left, Vector2(CELL_SIZE, CELL_SIZE))

func _unit_center(unit_id: String) -> Vector2:
	var box: Rect2 = _unit_box(unit_id)
	return box.position + (box.size * 0.5)

func _world_to_cell(world: Vector2) -> Dictionary:
	return {
		"col": int(floor(world.x / CELL_SIZE)) + 1,
		"row": int(floor(world.y / CELL_SIZE)) + 1
	}

func _normalize_cell(cell: Dictionary) -> Dictionary:
	return {
		"col": int(cell.get("col", 0)),
		"row": int(cell.get("row", 0))
	}

func _highlight_tile(cell: Dictionary, tint: Color, kind: String = "los") -> Dictionary:
	return {
		"col": int(cell.get("col", 0)),
		"row": int(cell.get("row", 0)),
		"kind": kind,
		"color": tint
	}

func _unit_position(unit_id: String) -> Dictionary:
	for unit in current_state.get("unit_states", []):
		if str(unit.get("id", unit.get("unit_id", ""))) == unit_id:
			return unit.get("position", {}).duplicate(true)
	return {"col": 0, "row": 0}

func _other_unit(unit_id: String) -> String:
	for unit in current_state.get("unit_states", []):
		var uid: String = str(unit.get("id", unit.get("unit_id", "")))
		if uid != unit_id:
			return uid
	return ""

func _unit_at(col: int, row: int) -> String:
	for unit in current_state.get("unit_states", []):
		var pos: Dictionary = unit.get("position", {})
		if int(pos.get("col", 0)) == col and int(pos.get("row", 0)) == row:
			return str(unit.get("id", unit.get("unit_id", "")))
	return ""

func _format_sample(point: Vector2) -> String:
	var cell: Dictionary = _world_to_cell(point)
	return "col=%d row=%d (%.1f,%.1f)" % [
		int(cell.get("col", 0)),
		int(cell.get("row", 0)),
		point.x,
		point.y
	]

func _update_battlefield_snapshot() -> void:
	var snapshot: Dictionary = {
		"version": UIContracts.SNAPSHOT_VERSION,
		"board": current_state.get("board", BOARD_LAYOUT),
		"units": current_state.get("unit_states", []),
		"rays": current_rays,
		"reachability": current_highlights,
		"logs": log_lines.duplicate(true)
	}
	battlefield_view.render_snapshot(snapshot)

func _enqueue_log(message: String) -> void:
	log_lines.insert(0, message)
	_update_battlefield_snapshot()
