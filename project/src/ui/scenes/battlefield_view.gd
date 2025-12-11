###############################################################
# project/src/ui/scenes/battlefield_view.gd
# Key Classes      • BattlefieldView – lightweight scene bridge for UI DTOs
# Key Functions    • render_snapshot(), render_events()
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • UIContracts
# Last Major Rev   • 25-11-29 – Stage 1 UI scene scaffold
###############################################################
class_name BattlefieldView
extends Control

const UIContracts = preload("res://project/src/ui/ui_contracts.gd")

var debug_view_enabled: bool = false

@onready var grid_layer: Node2D = $Grid
@onready var tile_layer: Node2D = $Grid/Tiles
@onready var reach_layer: Node2D = $Grid/Reachability
@onready var ray_layer: Node2D = $Grid/Rays
@onready var unit_layer: Node2D = $Grid/Units
@onready var log_panel: RichTextLabel = $LogPanel/Margin/LogText
@onready var status_label: Label = $StatusLabel


## Public: Render a snapshot DTO into placeholder UI nodes. This is intentionally
## minimal and will be expanded with real rendering in Stage 2.
func render_snapshot(snapshot: Dictionary) -> void:
    status_label.text = "Snapshot v%s" % snapshot.get("version", UIContracts.SNAPSHOT_VERSION)
    _render_board(snapshot.get("board", {}))
    _render_units(snapshot.get("units", []))
    var los_data: Array = snapshot.get("los", [])
    var rays: Array = []
    if los_data is Array and not los_data.is_empty():
        for entry in los_data:
            if entry is Dictionary and entry.has("rays"):
                rays += entry.get("rays", [])
    _render_rays(rays)
    _render_reachability(snapshot.get("reachability", []))
    _render_logs(snapshot.get("logs", []))


## Public: Render incoming event stream.
func render_events(events: Array) -> void:
    for ev in events:
        log_panel.append_text("[event] %s\n" % ev.get("type", "unknown"))


## Private: Stub grid rendering using board dimensions.
func _render_board(board: Dictionary) -> void:
    _clear_children(tile_layer)
    var columns: int = int(board.get("columns", 0))
    var rows: int = int(board.get("rows", 0))
    if columns <= 0 or rows <= 0:
        columns = 15
        rows = 9
    var light_color: Color = Color(0.24, 0.26, 0.32, 0.6)
    var dark_color: Color = Color(0.14, 0.15, 0.18, 0.6)
    for col in range(columns):
        for row in range(rows):
            var tile: ColorRect = ColorRect.new()
            var is_light: bool = ((col + row) % 2) == 0
            tile.color = light_color if is_light else dark_color
            tile.position = Vector2(col * 32, row * 32)
            tile.size = Vector2(32, 32)
            tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
            tile_layer.add_child(tile)


## Private: Stub unit rendering using minimal markers.
func _render_units(units: Array) -> void:
    _clear_children(unit_layer)
    for unit_data in units:
        var token := ColorRect.new()
        var pos: Dictionary = unit_data.get("position", {})
        token.position = Vector2(
            (int(pos.get("col", 0)) - 1) * 32, (int(pos.get("row", 0)) - 1) * 32
        )
        token.size = Vector2(32, 32)
        token.color = Color(0.2, 0.6, 1.0, 0.7)
        token.mouse_filter = Control.MOUSE_FILTER_IGNORE
        unit_layer.add_child(token)


## Private: Dump log lines for quick smoke visibility.
func _render_logs(logs: Array) -> void:
    if log_panel == null:
        return
    log_panel.clear()
    for log_entry in logs:
        log_panel.append_text("%s\n" % str(log_entry))


## Private: Highlight reachable tiles.
func _render_reachability(reachability: Array) -> void:
    _clear_children(reach_layer)
    for tile in reachability:
        var marker := ColorRect.new()
        var tile_color: Color = Color(0.2, 1.0, 0.4, 0.35)
        if tile is Dictionary and tile.has("color"):
            tile_color = tile.get("color")
        marker.color = tile_color
        marker.position = Vector2(
            (int(tile.get("col", 0)) - 1) * 32, (int(tile.get("row", 0)) - 1) * 32
        )
        marker.size = Vector2(32, 32)
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        reach_layer.add_child(marker)


## Private: Render ray segments as overlays.
func _render_rays(rays: Array) -> void:
    _clear_children(ray_layer)
    if not debug_view_enabled:
        return
    for ray_data in rays:
        var line := Line2D.new()
        line.width = float(ray_data.get("width", 2.0))
        line.default_color = ray_data.get("color", Color(0.2, 0.9, 0.5, 0.7))
        line.add_point(ray_data.get("from", Vector2.ZERO))
        line.add_point(ray_data.get("to", Vector2.ZERO))
        ray_layer.add_child(line)


## Private: Convert GUI-local coordinates to the grid-local position.
func gui_to_grid_position(gui_pos: Vector2) -> Vector2:
    return gui_pos - grid_layer.position


## Utility: Clear children from a node.
func _clear_children(target: Node) -> void:
    for child in target.get_children():
        child.queue_free()
