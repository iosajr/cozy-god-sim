class_name VillagerNameplate
extends Label3D
## Billboarded thought-bubble nameplate over a Villager's head.

## Placeholder "more holy" tell for a Renowned Villager.
const RENOWNED_COLOR: Color = Color(1.0, 0.85, 0.3)
const ORDINARY_COLOR: Color = Color.WHITE


func show_thought(thought_text: String) -> void:
	text = thought_text


## The baseline display (issue #43): a Villager's Name and current
## age_years, shown whenever there's no active Thought.
static func format_baseline(villager_name: String, age_years: int) -> String:
	return "%s, %d" % [villager_name, age_years]


func show_baseline(villager_name: String, age_years: int) -> void:
	text = format_baseline(villager_name, age_years)


func set_renowned(is_renowned: bool) -> void:
	modulate = RENOWNED_COLOR if is_renowned else ORDINARY_COLOR
