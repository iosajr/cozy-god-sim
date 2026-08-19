extends Node3D
## Main
## Root of the starter scene. Wires up quit/pause and is a natural place
## to eventually kick off game setup (loading a save, spawning villagers...).


func _ready() -> void:
	print("Cozy God Sim — starter scene loaded.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
