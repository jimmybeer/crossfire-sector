###############################################################
# project/src/ui/ui_input_map.gd
# Key Classes      • UIInputMap – declarative map from inputs to command DTOs
# Key Functions    • default_desktop_bindings()
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • ui_contracts.gd
# Last Major Rev   • 25-11-29 – Stage 1 input map scaffolding
###############################################################
class_name UIInputMap
extends RefCounted

const UIContracts = preload("res://project/src/ui/ui_contracts.gd")


## Public: Default desktop binding set for pointer + keyboard controls.
func default_desktop_bindings() -> Dictionary:
    return {
        # Pointer
        "select": UIContracts.input_binding("select", "mouse_left", "ui_select", {}),
        "confirm": UIContracts.input_binding("confirm", "mouse_left", "ui_confirm", {}),
        "cancel": UIContracts.input_binding("cancel", "mouse_right", "ui_cancel", {}),
        # Keyboard actions (aligns with Stage 1 plan)
        "move": UIContracts.input_binding("move", "key_a|key_1", "move", {}),
        "attack": UIContracts.input_binding("attack", "key_s|key_2", "attack", {}),
        "melee": UIContracts.input_binding("melee", "key_d|key_3", "melee", {}),
        "first_aid": UIContracts.input_binding("first_aid", "key_f|key_4", "first_aid", {}),
        "hold": UIContracts.input_binding("hold", "key_h|key_0", "hold", {"reason": "hold"}),
        "reroll": UIContracts.input_binding("reroll", "key_r", "reroll", {"source": "ui"}),
        "quick_start_move":
        UIContracts.input_binding("quick_start_move", "key_q", "quick_start_move", {}),
        "ui_undo":
        UIContracts.input_binding("ui_undo", "key_ctrl+z", "ui_cancel", {"scope": "selection"})
    }
