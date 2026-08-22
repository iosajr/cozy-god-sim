class_name FolkDebugInfo
extends Node
## Child of a spawned Folk's root node, kept in sync each frame by that
## Folk's spawner. Exposes live data as @export vars so it's visible in
## the editor's Remote Scene Tree/Inspector while the game is running.

@export var display_name: String = ""
@export var favored: float = 0.0
@export var has_faith: bool = false
@export var is_renowned: bool = false
@export var age_years: int = 0
@export var current_thought: String = ""
@export var hunger_state: String = ""
@export var tiredness_state: String = ""
@export var current_task_kind: String = ""


func sync(folk: Folk) -> void:
	display_name = folk.id
	favored = folk.favored
	has_faith = folk.has_faith
	is_renowned = folk.is_renowned
	age_years = folk.age_years
	if folk is Villager:
		var villager: Villager = folk
		current_thought = villager.current_thought
		hunger_state = villager.hunger_state
		tiredness_state = villager.tiredness_state
		current_task_kind = villager.current_task.kind if villager.current_task != null else ""
