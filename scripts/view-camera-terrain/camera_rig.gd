class_name CameraRig
extends Node3D
## RTS/god-sim camera: WASD/arrows to pan, wheel to zoom, right-drag to
## rotate+pitch, left-drag to pan 1:1 (grab point stays under the
## cursor). A plain left click (not a drag) on a body in
## DIALOGUE_CLICK_GROUP emits dialogue_target_clicked instead.
##
## Pitch only applies when the Camera3D has a separate Pivot parent —
## applying it to this node's own root would corrupt the yaw-only
## assumption the pan/drag math makes about global_transform.basis.

## Deliberately generic — CameraRig doesn't know what a hit body means,
## only that it was clicked (not dragged). Whoever adds bodies to this
## group owns that meaning.
const DIALOGUE_CLICK_GROUP := "dialogue_clickable"

signal dialogue_target_clicked(body: Node3D)

@export var pan_speed: float = 18.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 6.0
@export var max_zoom: float = 60.0
@export var rotate_sensitivity: float = 0.006
@export var pitch_sensitivity: float = 0.006
@export var min_pitch_deg: float = -80.0
@export var max_pitch_deg: float = -10.0
@export var edge_pan_enabled: bool = true
@export var edge_pan_margin: float = 12.0
## Max press-to-release mouse movement (px) still counted as a click.
@export var click_threshold_px: float = 6.0

var _camera: Camera3D
var _pivot: Node3D
var _zoom_distance: float = 24.0
var _pitch: float = 0.0
var _rotating: bool = false
var _dragging: bool = false
var _drag_grab_point: Vector3 = Vector3.ZERO
var _press_mouse_pos: Vector2 = Vector2.ZERO
var _press_hit_dialogue_body: Node3D = null
## Tracks the cursor actually crossing the OS window boundary — distinct
## from focus, so edge-pan stops the instant the cursor leaves even if
## the window stays focused.
var _cursor_in_window: bool = true


func _ready() -> void:
	_camera = _find_camera(self)
	if _camera:
		_zoom_distance = _camera.position.z if _camera.position.z > 0.1 else _zoom_distance
		_apply_zoom()

	var window := get_window()
	if window:
		window.mouse_entered.connect(func() -> void: _cursor_in_window = true)
		window.mouse_exited.connect(func() -> void: _cursor_in_window = false)

	_pivot = _find_pivot()
	if _pivot:
		_set_pitch(_pivot.rotation.x)


## Moves the point the camera orbits and looks at.
func focus_on(point: Vector3) -> void:
	global_position = point


func _find_camera(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found := _find_camera(child)
		if found:
			return found
	return null


## Null when the Camera3D is a direct child of this node (no separate
## Pivot) — that layout gets no pitch at all, see this script's doc
## comment.
func _find_pivot() -> Node3D:
	if not _camera:
		return null
	var parent := _camera.get_parent()
	if parent == self:
		return null
	return parent as Node3D


func _set_pitch(radians: float) -> void:
	_pitch = clamp(radians, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	_pivot.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(event.pressed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_distance = clamp(_zoom_distance - zoom_speed, min_zoom, max_zoom)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_distance = clamp(_zoom_distance + zoom_speed, min_zoom, max_zoom)
			_apply_zoom()
	elif event is InputEventMouseMotion and _rotating:
		rotate_y(-event.relative.x * rotate_sensitivity)
		if _pivot:
			_set_pitch(_pitch - event.relative.y * pitch_sensitivity)


func _on_left_click(pressed: bool) -> void:
	var viewport := get_viewport()
	var mouse_pos: Vector2 = viewport.get_mouse_position() if viewport else Vector2.ZERO

	if pressed:
		_press_mouse_pos = mouse_pos
		_press_hit_dialogue_body = _raycast_mouse_to_dialogue_target()

		var hit := _raycast_mouse_to_ground()
		if hit["hit"]:
			_dragging = true
			_drag_grab_point = hit["point"]
		return

	_dragging = false
	if _press_hit_dialogue_body != null and mouse_pos.distance_to(_press_mouse_pos) <= click_threshold_px:
		dialogue_target_clicked.emit(_press_hit_dialogue_body)
	_press_hit_dialogue_body = null


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")

	if edge_pan_enabled and input_dir == Vector2.ZERO:
		input_dir = _edge_pan_direction()

	if input_dir != Vector2.ZERO:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		var motion := (right * input_dir.x + forward * -input_dir.y) * pan_speed * delta
		global_position += motion

	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Safety net for a lost mouse-up (e.g. alt-tab mid-drag).
		_dragging = false

	if _dragging:
		_apply_drag_pan()


func _apply_drag_pan() -> void:
	var hit := _raycast_mouse_to_ground()
	if not hit["hit"]:
		return

	var current_point: Vector3 = hit["point"]
	var motion: Vector3 = _drag_grab_point - current_point
	motion.y = 0.0
	global_position += motion


func _mouse_ray() -> Dictionary:
	if not _camera:
		return {}
	var viewport := get_viewport()
	if not viewport:
		return {}

	var mouse_pos := viewport.get_mouse_position()
	return {
		"origin": _camera.project_ray_origin(mouse_pos),
		"direction": _camera.project_ray_normal(mouse_pos),
	}


func _raycast_mouse_to_ground() -> Dictionary:
	var ray := _mouse_ray()
	if ray.is_empty():
		return {"hit": false, "point": Vector3.ZERO}
	return GroundRay.intersect_ground_plane(ray["origin"], ray["direction"])


func _raycast_mouse_to_dialogue_target() -> Node3D:
	var ray := _mouse_ray()
	if ray.is_empty():
		return null
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return null

	var query := PhysicsRayQueryParameters3D.create(ray["origin"], ray["origin"] + ray["direction"] * 1000.0)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return null

	var collider: Object = result.get("collider")
	if collider is Node3D and collider.is_in_group(DIALOGUE_CLICK_GROUP):
		return collider
	return null


func _edge_pan_direction() -> Vector2:
	if not _cursor_in_window:
		return Vector2.ZERO
	var viewport := get_viewport()
	if not viewport:
		return Vector2.ZERO
	var mouse_pos := viewport.get_mouse_position()
	var size := viewport.get_visible_rect().size
	var dir := Vector2.ZERO
	if mouse_pos.x <= edge_pan_margin:
		dir.x -= 1.0
	elif mouse_pos.x >= size.x - edge_pan_margin:
		dir.x += 1.0
	if mouse_pos.y <= edge_pan_margin:
		dir.y -= 1.0
	elif mouse_pos.y >= size.y - edge_pan_margin:
		dir.y += 1.0
	return dir


func _apply_zoom() -> void:
	if _camera:
		_camera.position.z = _zoom_distance
