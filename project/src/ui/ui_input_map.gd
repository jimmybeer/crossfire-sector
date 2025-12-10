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
        "preview_path": UIContracts.input_binding("preview_path", "mouse_left_drag", "move", {}),
        "confirm_move": UIContracts.input_binding("confirm_move", "key_enter", "move", {}),
        "attack_target": UIContracts.input_binding("attack_target", "mouse_right", "attack", {}),
        "melee_target": UIContracts.input_binding("melee_target", "key_m", "melee", {}),
        "first_aid": UIContracts.input_binding("first_aid", "key_f", "first_aid", {}),
        "hold": UIContracts.input_binding("hold", "key_h", "hold", {"reason": "hold"}),
        "reroll": UIContracts.input_binding("reroll", "key_r", "reroll", {"source": "ui"}),
        "quick_start_move":
        UIContracts.input_binding("quick_start_move", "key_q", "quick_start_move", {})
    }
