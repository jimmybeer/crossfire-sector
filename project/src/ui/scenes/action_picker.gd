###############################################################
# project/src/ui/scenes/action_picker.gd
# Key Classes      • ActionPicker – lists available actions for a unit
# Key Functions    • set_actions()
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • (none)
# Last Major Rev   • 25-11-29 – Stage 1 UI scene scaffold
###############################################################
class_name ActionPicker
extends Control

@onready var actions_list: OptionButton = $Actions


## Public: Populate the picker with available actions.
func set_actions(actions: Array) -> void:
    actions_list.clear()
    for action_data in actions:
        var label: String = action_data.get("label", action_data.get("id", "action"))
        actions_list.add_item(label)
