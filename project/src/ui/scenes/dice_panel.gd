###############################################################
# project/src/ui/scenes/dice_panel.gd
# Key Classes      • DicePanel – displays recent dice rolls
# Key Functions    • set_rolls()
# Critical Consts  • (none)
# Editor Exports   • (none)
# Dependencies     • (none)
# Last Major Rev   • 25-11-29 – Stage 1 UI scene scaffold
###############################################################
class_name DicePanel
extends Control

@onready var rolls_label: RichTextLabel = $Rolls


## Public: Render dice roll results and totals.
func set_rolls(rolls: Array, total: int, context: String = "") -> void:
    rolls_label.clear()
    rolls_label.append_text("%s rolls: %s (total %d)\n" % [context, str(rolls), total])
