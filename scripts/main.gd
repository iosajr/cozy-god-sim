extends Node3D
## Main
## Root of the starter scene. Wires up quit/pause and is a natural place
## to eventually kick off game setup (loading a save, spawning villagers...).
##
## Also hosts a temporary debug hook verifying DialogueBox's God-facing
## side (issue #12's User Story 11): pressing F1 opens `$DialogueBox`
## with the first God in `GameState.pantheon`'s roster (`god_name`/
## `flavor` — real, already-designed data, no invented dialogue writing).
## No real in-world trigger exists for a God this slice, or is planned to
## — nothing in the world to click for one (issue #12's Out of Scope) —
## so this key binding, or the `run` skill, is the only way to exercise
## that half of the component. Safe to remove once a real trigger exists.
##
## Also pauses CameraRig's WASD/edge-pan/zoom/rotate/drag-pan controls
## while the dialogue box is open (issue #12's User Story 12 — "return to
## normal play", not "keep panning the camera underneath a modal
## conversation"), and is a defensive backstop for Escape: DialogueBox's
## own `_unhandled_input` also binds "ui_cancel" to close itself, and
## (being this node's child) is expected to receive and consume that
## event first — but this quit handler double-checks `_dialogue_box.
## visible` anyway rather than depending solely on that ordering.

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
