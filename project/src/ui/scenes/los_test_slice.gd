###############################################################
# project/src/ui/scenes/los_test_slice.gd
# Key Classes      • LoSTestSlice – LoS/cover visualization sandbox
# Key Functions    • _load_scenario(), _evaluate_unit(), _build_highlight_tiles()
# Critical Consts  • BOARD_LAYOUT, TERRAIN_TEMPLATES, SCENARIOS
# Editor Exports   • (none)
# Dependencies     • BattlefieldView, CommandValidator, UIContracts
# Last Major Rev   • 25-11-30 – LoS visualization spike prototype
###############################################################
class_name LoSTestSlice
extends Control

const BattlefieldView = preload("res://project/src/ui/scenes/battlefield_view.gd")
const CommandValidator = preload("res://project/src/validation/command_validator.gd")
const UIContracts = preload("res://project/src/ui/ui_contracts.gd")

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
	}
]

var validator: CommandValidator = CommandValidator.new()
var current_state: Dictionary = {}
var current_highlights: Array = []
var log_lines: Array = []
var current_scenario_idx: int = 0

@onready var battlefield_view: BattlefieldView = $BattlefieldView
@onready var scenario_list: ItemList = $Sidebar/ScenarioListContainer/ScenarioList
@onready var scenario_description: RichTextLabel = $Sidebar/ScenarioDescription

func _ready() -> void:
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
	scenario_description.bbcode_text = "[b]%s[/b]\n%s" % [scenario["title"], scenario["description"]]
	log_lines = []
	current_state = _build_state_from_scenario(scenario)
	current_highlights = []
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

func _unit_entry(unit_id: String, position: Dictionary, owner_id: String) -> Dictionary:
	return {
		"id": unit_id,
		"unit_id": unit_id,
		"owner_id": owner_id,
		"position": {"col": int(position.get("col", 1)), "row": int(position.get("row", 1))},
		"status": "alive"
	}

func _on_battlefield_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var grid_click: Vector2 = battlefield_view.gui_to_grid_position(event.position)
	var col: int = int(floor(grid_click.x / 32)) + 1
	var row: int = int(floor(grid_click.y / 32)) + 1
	var scenario_index: int = current_scenario_idx
	var scenario: Dictionary = SCENARIOS[scenario_index]
	var board: Dictionary = current_state.get("board", BOARD_LAYOUT)
	var board_cols: int = int(board.get("columns", BOARD_LAYOUT["columns"]))
	var board_rows: int = int(board.get("rows", BOARD_LAYOUT["rows"]))
	if grid_click.x < 0 or grid_click.y < 0 or col < 1 or row < 1 or col > board_cols or row > board_rows:
		_enqueue_log("[input] click outside board (gui=%.1f,%.1f)" % [event.position.x, event.position.y])
		return
	var found: String = _unit_at(col, row)
	var message: String = "[input] selected col=%d row=%d" % [col, row]
	if found != "":
		message += " unit=%s" % found
		_enqueue_log(message)
		var highlight_note: String = _describe_highlight(col, row)
		if highlight_note != "":
			_enqueue_log(highlight_note)
		_evaluate_unit(found)
	else:
		_enqueue_log("%s no unit there" % message)
		var highlight_note: String = _describe_highlight(col, row)
		if highlight_note != "":
			_enqueue_log(highlight_note)

func _evaluate_unit(unit_id: String) -> void:
	var target_id: String = _other_unit(unit_id)
	if target_id == "":
		return
	var board: Dictionary = current_state.get("board", BOARD_LAYOUT)
	var data_config: Dictionary = {
		"terrain_templates": TERRAIN_TEMPLATES,
		"board_layout": board
	}
	var terrain_blocks: Dictionary = validator._collect_terrain_blocks(current_state, data_config)
	var occupied: Array = validator._collect_occupied_cells(current_state)
	var attacker_pos: Dictionary = _unit_position(unit_id)
	var target_pos: Dictionary = _unit_position(target_id)
	var los_path: Array = validator._bresenham_line(attacker_pos, target_pos)
	var los_ok: bool = validator._has_line_of_sight(attacker_pos, target_pos, terrain_blocks, occupied, board)
	var cover: bool = validator._has_cover(target_pos, terrain_blocks, occupied)
	var truncation: Dictionary = _truncate_path_at_blocker(los_path, terrain_blocks, occupied)
	var path_until_block: Array = truncation.get("path", [])
	var blocker_cell: Dictionary = truncation.get("blocker", {})
	current_highlights = _build_highlight_tiles(attacker_pos, target_pos, path_until_block, terrain_blocks, occupied, blocker_cell)
	_update_battlefield_snapshot()
	var message: String = "[los] %s -> %s %s; cover=%s" % [
		unit_id,
		target_id,
		"visible" if los_ok else "blocked",
		"yes" if cover else "no"
	]
	if not los_ok and blocker_cell.size() > 0:
		var block_type: String = "terrain" if validator._is_impassable(blocker_cell, terrain_blocks) else "unit"
		message += " (blocked by %s at col=%d row=%d)" % [
			block_type,
			int(blocker_cell.get("col", 0)),
			int(blocker_cell.get("row", 0))
		]
	_enqueue_log(message)

func _build_highlight_tiles(attacker: Dictionary, target: Dictionary, path: Array, terrain_blocks: Dictionary, occupied: Array, blocker: Dictionary) -> Array:
	var tiles: Array = []
	tiles.append(_highlight_tile(attacker, Color(0.1, 0.2, 0.9, 0.8), "attacker"))
	for point in path:
		tiles.append(_highlight_tile(point, Color(0.2, 0.8, 1.0, 0.6), "los"))
	tiles.append(_highlight_tile(target, Color(1.0, 0.35, 0.0, 0.85), "target"))
	if blocker.size() > 0:
		tiles.append(_highlight_tile(blocker, Color(0.5, 0.0, 0.7, 0.9), "blocker"))
	var cover_sources: Array = _collect_cover_sources(target, terrain_blocks, occupied)
	for cover_cell in cover_sources:
		tiles.append(_highlight_tile(cover_cell, Color(1.0, 0.9, 0.0, 0.75), "cover"))
	return tiles

func _collect_cover_sources(target: Dictionary, terrain_blocks: Dictionary, occupied: Array) -> Array:
	var sources: Array = []
	var blocking_cover: Array = terrain_blocks.get("cover", [])
	for cell in blocking_cover:
		sources.append(_normalize_cell(cell))
	var adjacents: Array = [
		{"col": 1, "row": 0},
		{"col": -1, "row": 0},
		{"col": 0, "row": 1},
		{"col": 0, "row": -1}
	]
	for offset in adjacents:
		var neighbor: Dictionary = {
			"col": int(target.get("col", 0)) + int(offset.get("col", 0)),
			"row": int(target.get("row", 0)) + int(offset.get("row", 0))
		}
		if validator._cell_in_list(neighbor, terrain_blocks.get("blocking", [])) or validator._cell_in_list(neighbor, occupied):
			sources.append(neighbor)
	return sources

func _truncate_path_at_blocker(path: Array, terrain_blocks: Dictionary, occupied: Array) -> Dictionary:
	var truncated: Array = []
	var blocker: Dictionary = {}
	for cell in path:
		truncated.append(_normalize_cell(cell))
		if validator._is_impassable(cell, terrain_blocks) or validator._cell_in_list(cell, occupied):
			blocker = _normalize_cell(cell)
			break
	return {"path": truncated, "blocker": blocker}

func _describe_highlight(col: int, row: int) -> String:
	var kinds: Array = []
	for tile in current_highlights:
		if int(tile.get("col", -1)) == col and int(tile.get("row", -1)) == row:
			kinds.append(str(tile.get("kind", "unknown")))
	if kinds.size() == 0:
		return ""
	return "[tile] col=%d row=%d kinds=%s" % [col, row, String(", ").join(kinds)]

func _highlight_tile(cell: Dictionary, tint: Color, kind: String = "los") -> Dictionary:
	return {
		"col": int(cell.get("col", 0)),
		"row": int(cell.get("row", 0)),
		"kind": kind,
		"color": tint
	}

func _normalize_cell(cell: Dictionary) -> Dictionary:
	return {
		"col": int(cell.get("col", 0)),
		"row": int(cell.get("row", 0))
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

func _update_battlefield_snapshot() -> void:
	var snapshot: Dictionary = {
		"version": UIContracts.SNAPSHOT_VERSION,
		"board": current_state.get("board", BOARD_LAYOUT),
		"units": current_state.get("unit_states", []),
		"reachability": current_highlights,
		"logs": log_lines.duplicate(true)
	}
	battlefield_view.render_snapshot(snapshot)

func _enqueue_log(message: String) -> void:
	log_lines.insert(0, message)
	_update_battlefield_snapshot()
