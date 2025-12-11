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

signal reference_loaded(data: Dictionary)
signal reference_failed(message: String)

const DEFAULT_PATH := "res://docs/data-definition/exports/ui_reference.json"

@onready var text_block: RichTextLabel = $ReferenceText


## Public: Load reference JSON and render a short summary.
func load_reference(path: String = DEFAULT_PATH) -> void:
    text_block.bbcode_enabled = true
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        var missing := "[b][reference][/b] missing file: %s" % path
        text_block.text = missing
        reference_failed.emit(missing)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        var rendered := _render_reference(parsed)
        text_block.text = rendered
        reference_loaded.emit(parsed)
    else:
        var err := "[b][reference][/b] failed to parse JSON"
        text_block.text = err
        reference_failed.emit(err)


## Private: Render a styled RichText summary for glossary display.
func _render_reference(data: Dictionary) -> String:
    var lines: Array[String] = []
    var version: String = data.get("version", "0.0.0")
    lines.append("[b]Reference v%s[/b]" % version)
    lines.append("")

    _append_section(lines, "Factions", data.get("factions", []), Callable(self, "_format_faction"))
    _append_section(lines, "Actions", data.get("actions", []), Callable(self, "_format_action"))
    _append_section(lines, "Missions", data.get("missions", []), Callable(self, "_format_mission"))

    var opt_rules: Dictionary = data.get("optional_rules", {})
    _append_section(
        lines,
        "Commander Traits",
        opt_rules.get("commander_traits", []),
        Callable(self, "_format_commander")
    )
    _append_section(
        lines, "Battle Events", opt_rules.get("battle_events", []), Callable(self, "_format_event")
    )

    _append_section(lines, "Glossary", data.get("glossary", []), Callable(self, "_format_glossary"))

    return "\n".join(lines)


## Private: Append a section with BBCode header and formatted entries.
func _append_section(
    lines: Array[String], title: String, entries: Array, format_fn: Callable
) -> void:
    if entries.is_empty():
        return
    lines.append("[b]%s[/b]" % title)
    for entry in entries:
        if not (entry is Dictionary):
            continue
        lines.append(format_fn.call(entry))
    lines.append("")


## Private: Prefer localized text if available (defaults to raw field).
func _loc(entry: Dictionary, field: String) -> String:
    var locs: Dictionary = entry.get("localizations", {})
    if locs.has("en") and locs["en"] is Dictionary and locs["en"].has(field):
        return str(locs["en"].get(field, ""))
    return str(entry.get(field, ""))


## Private: Render requirement tags inline.
func _reqs_text(reqs: Array) -> String:
    if reqs.is_empty():
        return ""
    return " [color=gray](%s)[/color]" % _join_array(reqs)


## Private: Join array elements as comma-separated string.
func _join_array(items: Array) -> String:
    var parts: Array[String] = []
    for item in items:
        parts.append(str(item))
    return ", ".join(parts)


## Format helpers
func _format_faction(entry: Dictionary) -> String:
    var name: String = _loc(entry, "name")
    var stats: Dictionary = entry.get("stats", {})
    var move: Variant = stats.get("move", "")
    var rng: Variant = stats.get("range", "")
    var aq: Variant = stats.get("aq", "")
    var defense: Variant = stats.get("defense", "")
    var notes: String = _loc(entry, "notes")
    var reqs: Array = entry.get("requirements", [])
    var note_text: String = "" if notes == "" else " — %s" % notes
    return (
        "- [b]%s[/b] (Move %s, Range %s, AQ %s, Def %s)%s%s"
        % [name, str(move), str(rng), str(aq), str(defense), note_text, _reqs_text(reqs)]
    )


func _format_action(entry: Dictionary) -> String:
    var name: String = _loc(entry, "name")
    var desc: String = _loc(entry, "description")
    var reqs: Array = entry.get("requirements", [])
    return "- [b]%s[/b]: %s%s" % [name, desc, _reqs_text(reqs)]


func _format_mission(entry: Dictionary) -> String:
    var name: String = _loc(entry, "name")
    var summary: String = _loc(entry, "summary")
    var scoring: String = _loc(entry, "scoring")
    var deltas: Array = entry.get("per_round_deltas", [])
    var reqs: Array = entry.get("requirements", [])
    var delta_str: String = (" (per-round: %s)" % _join_array(deltas)) if deltas.size() > 0 else ""
    var scoring_text: String = "" if scoring == "" else " — %s" % scoring
    return "- [b]%s[/b]: %s%s%s" % [name, summary, scoring_text, delta_str + _reqs_text(reqs)]


func _format_commander(entry: Dictionary) -> String:
    var name: String = _loc(entry, "name")
    var effect: String = _loc(entry, "effect")
    var reqs: Array = entry.get("requirements", [])
    return "- [b]%s[/b]: %s%s" % [name, effect, _reqs_text(reqs)]


func _format_event(entry: Dictionary) -> String:
    var name: String = _loc(entry, "name")
    var effect: String = _loc(entry, "effect")
    var reqs: Array = entry.get("requirements", [])
    return "- [b]%s[/b]: %s%s" % [name, effect, _reqs_text(reqs)]


func _format_glossary(entry: Dictionary) -> String:
    var title: String = _loc(entry, "title")
    var body: String = _loc(entry, "body")
    var reqs: Array = entry.get("requirements", [])
    return "- [b]%s[/b]: %s%s" % [title, body, _reqs_text(reqs)]
