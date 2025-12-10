###############################################################
# project/src/ui/scenes/reference_panel.gd
# Key Classes      • ReferencePanel – loads JSON reference data into UI
# Key Functions    • load_reference()
# Critical Consts  • DEFAULT_PATH
# Editor Exports   • (none)
# Dependencies     • JSON, FileAccess
# Last Major Rev   • 25-11-29 – Stage 1 reference feed scaffold
###############################################################
class_name ReferencePanel
extends Control

const DEFAULT_PATH := "res://docs/data-definition/exports/ui_reference.json"

@onready var text_block: RichTextLabel = $ReferenceText


## Public: Load reference JSON and render a short summary.
func load_reference(path: String = DEFAULT_PATH) -> void:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        text_block.text = "[reference] missing file: %s" % path
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        text_block.text = _render_summary(parsed)
    else:
        text_block.text = "[reference] failed to parse JSON"


## Private: Render a minimal summary for glossary display.
func _render_summary(data: Dictionary) -> String:
    var lines: Array[String] = []
    lines.append("Reference v%s" % data.get("version", "0.0.0"))
    var factions: Array = data.get("factions", [])
    if factions.size() > 0:
        lines.append("Factions:")
        for faction in factions:
            lines.append(" - %s" % faction.get("name", "unknown"))
    var missions: Array = data.get("missions", [])
    if missions.size() > 0:
        lines.append("Missions:")
        for mission in missions:
            lines.append(" - %s" % mission.get("name", "unknown"))
    var actions: Array = data.get("actions", [])
    if actions.size() > 0:
        lines.append("Actions:")
        for action in actions:
            lines.append(" - %s" % action.get("name", "unknown"))
    return "\n".join(lines)
