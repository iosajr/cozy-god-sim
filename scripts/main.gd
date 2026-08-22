extends Node3D
## Root of the starter scene. Wires up quit/pause. F1 opens a debug
## dialogue for the first God in GameState.pantheon (no real in-world
## trigger for a God exists yet). Pauses CameraRig's controls while the
## dialogue box is open.

@onready var _dialogue_box: DialogueBox = $DialogueBox
@onready var _camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	print("Cozy God Sim — starter scene loaded.")
	if _dialogue_box:
		_dialogue_box.visibility_changed.connect(_on_dialogue_box_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _dialogue_box and _dialogue_box.visible:
			return
		get_tree().quit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_debug_open_god_dialogue()


func _debug_open_god_dialogue() -> void:
	if not _dialogue_box or GameState.pantheon.gods.is_empty():
		return
	var god: God = GameState.pantheon.gods[0]
	_dialogue_box.show_dialogue(god.god_name, [god.flavor])


func _on_dialogue_box_visibility_changed() -> void:
	if not _camera_rig:
		return
	var dialogue_open := _dialogue_box.visible
	_camera_rig.set_physics_process(not dialogue_open)
	_camera_rig.set_process_unhandled_input(not dialogue_open)
