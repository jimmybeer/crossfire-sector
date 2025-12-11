###############################################################
# project/src/ui/scenes/stage01_slice.gd
# Key Classes      • Stage01Slice – wires Stage 1 UI scaffolding to fixtures
# Key Functions    • _load_fixture(), run_demo_command()
# Critical Consts  • FIXTURE_PATH
# Editor Exports   • (none)
# Dependencies     • UISliceLoader, BattlefieldView, ActionPicker, DicePanel, ReferencePanel
# Last Major Rev   • 25-11-29 – Stage 1 integration slice scaffold
###############################################################
class_name Stage01Slice
extends Control

const UISliceLoader = preload("res://project/src/ui/ui_slice_loader.gd")
const BattlefieldView = preload("res://project/src/ui/scenes/battlefield_view.gd")
const ActionPicker = preload("res://project/src/ui/scenes/action_picker.gd")
const DicePanel = preload("res://project/src/ui/scenes/dice_panel.gd")
const ReferencePanel = preload("res://project/src/ui/scenes/reference_panel.gd")
const UIInputMap = preload("res://project/src/ui/ui_input_map.gd")

const FIXTURE_PATH := "res://docs/data-definition/fixtures/save_match.json"

var slice_loader: UISliceLoader
var last_snapshot: Dictionary = {}
var last_preview: Dictionary = {}
var input_bindings: Dictionary = {}
var selected_unit_id: String = ""
var selected_target_id: String = ""
var selected_action: String = "move"
var ui_input_map: UIInputMap

@onready var battlefield_view: BattlefieldView = $BattlefieldView
@onready var action_picker: ActionPicker = $Sidebar/ActionPanel/ActionPicker
@onready var dice_panel: DicePanel = $Sidebar/DicePanelContainer/DicePanel
@onready var reference_panel: ReferencePanel = $Sidebar/ReferencePanelContainer/ReferencePanel
@onready var demo_button: Button = $Sidebar/DemoCommandButtonContainer/DemoCommandButton
@onready var debug_toggle: CheckBox = $Sidebar/DebugToggleContainer/DebugToggle


func _ready() -> void:
    reference_panel.load_reference()
    ui_input_map = UIInputMap.new()
    input_bindings = ui_input_map.default_desktop_bindings()
    slice_loader = UISliceLoader.new({}, 0, {})
    _load_fixture()
    demo_button.pressed.connect(_on_demo_command_pressed)
    debug_toggle.toggled.connect(_on_debug_toggled)
    _connect_inputs()


## Private: Load the fixture state and render initial snapshot.
func _load_fixture() -> void:
    var parsed: Variant = _read_json(FIXTURE_PATH)
    var fixture_state: Dictionary = {}
    if parsed is Dictionary:
        fixture_state = parsed
    fixture_state = _normalize_fixture_units(fixture_state)
    var load_result: Dictionary = slice_loader.load_fixture(fixture_state)
    last_snapshot = load_result.get("snapshot", {})
    _update_views(last_snapshot, [])
    _select_first_unit()


## Private: Handle demo command button to exercise validator/resolver path.
func _on_demo_command_pressed() -> void:
    var actor_id: String = selected_unit_id
    if actor_id == "":
        _select_first_unit()
        actor_id = selected_unit_id
    var command: Dictionary = {
        "type": "hold", "payload": {"reason": "demo_hold"}, "actor_unit_id": actor_id, "sequence": 1
    }
    var result: Dictionary = slice_loader.process_command(command)
    last_snapshot = result.get("snapshot", last_snapshot)
    _update_views(last_snapshot, result.get("events", []))
    _preview_for_selected_unit()


## Private: Render snapshot + event stream across panels.
func _update_views(snapshot: Dictionary, events: Array) -> void:
    if not snapshot.has("logs"):
        snapshot["logs"] = []
    for ev in events:
        snapshot["logs"].append(_format_event(ev))
    battlefield_view.render_snapshot(snapshot)
    battlefield_view.render_events(events)
    if events.size() > 0:
        var last_event: Dictionary = events.back()
        dice_panel.set_rolls(
            last_event.get("payload", {}).get("rolls", []),
            last_event.get("payload", {}).get("total", 0),
            last_event.get("type", "event")
        )
    action_picker.set_actions(
        [
            {"id": "hold", "label": "Hold"},
            {"id": "move", "label": "Move"},
            {"id": "attack", "label": "Attack"},
            {"id": "melee", "label": "Melee"},
            {"id": "first_aid", "label": "First Aid"}
        ]
    )


## Private: Read JSON file contents safely.
func _read_json(path: String) -> Variant:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    return JSON.parse_string(file.get_as_text())


## Private: Format event/log entries for display.
func _format_event(ev: Dictionary) -> String:
    var ev_type: String = ev.get("type", "event")
    var payload: Dictionary = ev.get("payload", {})
    if payload.has("rolls"):
        return (
            "[%s] rolls=%s total=%s"
            % [ev_type, str(payload.get("rolls", [])), str(payload.get("total", ""))]
        )
    if payload.has("unit_id"):
        return "[%s] unit=%s" % [ev_type, payload.get("unit_id", "")]
    return "[%s]" % ev_type


## Private: Record UI messages so the log panel reflects interactions.
func _log_event(message: String) -> void:
    if not last_snapshot.has("logs") or not last_snapshot["logs"] is Array:
        last_snapshot["logs"] = []
    var logs: Array = last_snapshot.get("logs", [])
    logs.append(message)
    last_snapshot["logs"] = logs


## Private: Connect input signals for selection and command application.
func _connect_inputs() -> void:
    battlefield_view.gui_input.connect(_on_battlefield_input)
    action_picker.actions_list.item_selected.connect(_on_action_selected)


## Private: Select first unit by default.
func _select_first_unit() -> void:
    var units: Array = last_snapshot.get("units", [])
    if units.is_empty():
        selected_unit_id = ""
        return
    var unit: Dictionary = units[0]
    selected_unit_id = str(unit.get("id", unit.get("unit_id", "")))
    _preview_for_selected_unit()


func _on_debug_toggled(enabled: bool) -> void:
    battlefield_view.debug_view_enabled = enabled
    # Force redraw of rays based on last snapshot
    _update_views(last_snapshot, [])


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F9:
            debug_toggle.button_pressed = not debug_toggle.button_pressed
            _on_debug_toggled(debug_toggle.button_pressed)


## Private: Preview a move for the selected unit using a simple adjacent target.
func _preview_for_selected_unit() -> void:
    if selected_unit_id == "":
        return
    var unit_state: Dictionary = _find_unit(selected_unit_id)
    if unit_state.is_empty():
        return
    var command: Dictionary = _build_preview_command(unit_state)
    var preview_result: Dictionary = slice_loader.preview_command(command)
    last_preview = preview_result
    var preview: Dictionary = preview_result.get("preview", {})
    last_snapshot["reachability"] = preview.get("reachable_tiles", [])
    if not preview_result.get("ok", true):
        var error_lines: Array = []
        for err in preview_result.get("errors", []):
            error_lines.append("[error] %s" % err.get("message", "Invalid command"))
        last_snapshot["logs"] = last_snapshot.get("logs", []) + error_lines
    _update_views(last_snapshot, [])


## Private: Handle battlefield input for unit selection.
func _on_battlefield_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var gui_click: Vector2 = event.position
        var grid_click: Vector2 = battlefield_view.gui_to_grid_position(gui_click)
        var col: int = int(floor(grid_click.x / 32)) + 1
        var row: int = int(floor(grid_click.y / 32)) + 1
        var board: Dictionary = last_snapshot.get("board", {})
        var board_cols: int = int(board.get("columns", 15))
        var board_rows: int = int(board.get("rows", 9))
        var message: String = (
            "[input] gui=(%d,%d) grid=(%d,%d)" % [int(gui_click.x), int(gui_click.y), col, row]
        )
        if (
            grid_click.x < 0
            or grid_click.y < 0
            or col < 1
            or row < 1
            or col > board_cols
            or row > board_rows
        ):
            _log_event("%s outside board bounds" % message)
            _update_views(last_snapshot, [])
            return
        var found: String = _unit_at(col, row)
        if found != "":
            var unit_state: Dictionary = _find_unit(found)
            if not unit_state.is_empty():
                var unit_pos: Dictionary = unit_state.get("position", {})
                message += (
                    " unit=%s pos=(%d,%d)"
                    % [found, int(unit_pos.get("col", 0)), int(unit_pos.get("row", 0))]
                )
            else:
                message += " unit=%s" % found
            _log_event(message)
            selected_unit_id = found
            _preview_for_selected_unit()
        else:
            _log_event("%s no unit there" % message)
            _update_views(last_snapshot, [])


## Private: Handle action selection to run a command for the selected unit.
func _on_action_selected(index: int) -> void:
    var action_id: String = action_picker.actions_list.get_item_text(index).to_lower()
    selected_action = action_id
    if selected_unit_id == "":
        return
    match action_id:
        "move":
            _preview_for_selected_unit()
        "hold":
            _execute_command("hold", {"reason": "user_hold"})
        "attack":
            _execute_attack()
        "melee":
            _execute_melee()
        "first aid":
            _execute_first_aid()
        _:
            pass


## Private: Find unit by id in the current snapshot.
func _find_unit(unit_id: String) -> Dictionary:
    for unit in last_snapshot.get("units", []):
        var uid: String = str(unit.get("id", unit.get("unit_id", "")))
        if uid == unit_id:
            return unit
    return {}


## Private: Locate unit occupying a cell.
func _unit_at(col: int, row: int) -> String:
    for unit in last_snapshot.get("units", []):
        var pos: Dictionary = unit.get("position", {})
        if int(pos.get("col", 0)) == col and int(pos.get("row", 0)) == row:
            return str(unit.get("id", unit.get("unit_id", "")))
    return ""


## Private: Normalize fixture state to include units array.
func _normalize_fixture_units(state: Dictionary) -> Dictionary:
    if state.has("units"):
        return state
    var units: Array = []
    for unit_state in state.get("unit_states", []):
        var pos: Dictionary = unit_state.get("position", {})
        units.append(
            {
                "id": unit_state.get("id", ""),
                "unit_id": unit_state.get("id", ""),
                "owner_id": unit_state.get("owner_id", ""),
                "position": {"col": int(pos.get("col", 0)), "row": int(pos.get("row", 0))},
                "status": unit_state.get("status", "alive")
            }
        )
    state["units"] = units
    return state


## Private: Execute a basic command with current selection.
func _execute_command(cmd_type: String, payload: Dictionary) -> void:
    var command: Dictionary = {
        "type": cmd_type, "payload": payload, "actor_unit_id": selected_unit_id, "sequence": 3
    }
    var result: Dictionary = slice_loader.process_command(command)
    last_snapshot = result.get("snapshot", last_snapshot)
    _update_views(last_snapshot, result.get("events", []))


## Private: Execute a simple attack against the first opposing unit.
func _execute_attack() -> void:
    var target: Dictionary = _find_opponent_unit()
    if target.is_empty():
        return
    selected_target_id = str(target.get("id", target.get("unit_id", "")))
    var command: Dictionary = _build_attack_command(target)
    var result: Dictionary = slice_loader.process_command(command)
    last_snapshot = result.get("snapshot", last_snapshot)
    _update_views(last_snapshot, result.get("events", []))


## Private: Execute a simple melee by moving adjacent if needed.
func _execute_melee() -> void:
    var target: Dictionary = _find_opponent_unit()
    if target.is_empty():
        return
    selected_target_id = str(target.get("id", target.get("unit_id", "")))
    var command: Dictionary = _build_melee_command(target)
    var result: Dictionary = slice_loader.process_command(command)
    last_snapshot = result.get("snapshot", last_snapshot)
    _update_views(last_snapshot, result.get("events", []))


## Private: Execute first aid on a friendly downed unit if present.
func _execute_first_aid() -> void:
    var target: Dictionary = _find_friendly_down_unit()
    if target.is_empty():
        return
    selected_target_id = str(target.get("id", target.get("unit_id", "")))
    var command: Dictionary = _build_first_aid_command(target)
    var result: Dictionary = slice_loader.process_command(command)
    last_snapshot = result.get("snapshot", last_snapshot)
    _update_views(last_snapshot, result.get("events", []))


## Private: Build preview command depending on selected action.
func _build_preview_command(unit_state: Dictionary) -> Dictionary:
    var command: Dictionary = _build_move_command(unit_state)
    match selected_action:
        "attack":
            var target: Dictionary = _find_opponent_unit()
            if not target.is_empty():
                command = _build_attack_command(target)
        "melee":
            var melee_target: Dictionary = _find_opponent_unit()
            if not melee_target.is_empty():
                command = _build_melee_command(melee_target)
        "first aid":
            var aid_target: Dictionary = _find_friendly_down_unit()
            if not aid_target.is_empty():
                command = _build_first_aid_command(aid_target)
        _:
            pass
    return command


## Private: Build a basic move command for previews.
func _build_move_command(unit_state: Dictionary) -> Dictionary:
    var pos: Dictionary = unit_state.get("position", {"col": 1, "row": 1})
    var target: Dictionary = {"col": int(pos.get("col", 1)) + 1, "row": int(pos.get("row", 1))}
    return {
        "type": "move",
        "payload": {"path": [pos, target], "source_position": pos},
        "actor_unit_id": selected_unit_id,
        "sequence": 2
    }


## Private: Build attack command payload.
func _build_attack_command(target: Dictionary) -> Dictionary:
    var actor: Dictionary = _find_unit(selected_unit_id)
    var pos: Dictionary = actor.get("position", {"col": 1, "row": 1})
    var target_pos: Dictionary = target.get("position", {"col": 1, "row": 1})
    return {
        "type": "attack",
        "payload":
        {
            "path": [pos],
            "source_position": pos,
            "target_cell":
            {"col": int(target_pos.get("col", 1)), "row": int(target_pos.get("row", 1))}
        },
        "actor_unit_id": selected_unit_id,
        "target_unit_id": str(target.get("id", target.get("unit_id", ""))),
        "sequence": 4
    }


## Private: Build melee command payload.
func _build_melee_command(target: Dictionary) -> Dictionary:
    var actor: Dictionary = _find_unit(selected_unit_id)
    var pos: Dictionary = actor.get("position", {"col": 1, "row": 1})
    var target_pos: Dictionary = target.get("position", {"col": 1, "row": 1})
    var path: Array = [pos]
    var dx: int = int(target_pos.get("col", 1)) - int(pos.get("col", 1))
    var dy: int = int(target_pos.get("row", 1)) - int(pos.get("row", 1))
    if abs(dx) + abs(dy) > 1:
        var step: Dictionary = {
            "col": int(target_pos.get("col", 1)) - int(sign(dx)),
            "row": int(target_pos.get("row", 1)) - int(sign(dy))
        }
        path.append(step)
    return {
        "type": "melee",
        "payload":
        {
            "path": path,
            "source_position": pos,
            "target_cell":
            {"col": int(target_pos.get("col", 1)), "row": int(target_pos.get("row", 1))}
        },
        "actor_unit_id": selected_unit_id,
        "target_unit_id": str(target.get("id", target.get("unit_id", ""))),
        "sequence": 5
    }


## Private: Build first aid command payload.
func _build_first_aid_command(target: Dictionary) -> Dictionary:
    var actor: Dictionary = _find_unit(selected_unit_id)
    var pos: Dictionary = actor.get("position", {"col": 1, "row": 1})
    var target_pos: Dictionary = target.get("position", {"col": 1, "row": 1})
    return {
        "type": "first_aid",
        "payload":
        {
            "path": [pos],
            "source_position": pos,
            "target_cell":
            {"col": int(target_pos.get("col", 1)), "row": int(target_pos.get("row", 1))},
            "target_unit_id": str(target.get("id", target.get("unit_id", "")))
        },
        "actor_unit_id": selected_unit_id,
        "target_unit_id": str(target.get("id", target.get("unit_id", ""))),
        "sequence": 6
    }


## Private: Find any opposing unit for targeting.
func _find_opponent_unit() -> Dictionary:
    if selected_unit_id == "":
        return {}
    var actor: Dictionary = _find_unit(selected_unit_id)
    var actor_owner: String = actor.get("owner_id", "")
    for unit in last_snapshot.get("units", []):
        if unit.get("owner_id", "") != "" and unit.get("owner_id", "") != actor_owner:
            return unit
    return {}


## Private: Find a friendly downed unit for first aid.
func _find_friendly_down_unit() -> Dictionary:
    if selected_unit_id == "":
        return {}
    var actor: Dictionary = _find_unit(selected_unit_id)
    var actor_owner: String = actor.get("owner_id", "")
    for unit in last_snapshot.get("units", []):
        if unit.get("owner_id", "") == actor_owner and unit.get("status", "") == "down":
            return unit
    return {}
