class_name VillagerNameplate
extends Label3D
## VillagerNameplate
## Thin presentation seam (Seam 2, see issue #2): a billboarded
## thought-bubble-styled nameplate over a Villager's head. One public
## entry point — `show_thought()` — sets the displayed text and nothing
## else is exposed. No visual/bubble styling lives here yet; that's a
## disposable placeholder detail, same spirit as world_gen.gd.


func show_thought(thought_text: String) -> void:
	text = thought_text
