extends Node3D
## CameraRig
## A simple RTS/god-sim style camera:
##   - WASD / arrow keys to pan across the ground plane
##   - Mouse wheel to zoom in/out
##   - Hold right mouse button and drag to rotate (yaw)
## Attach to a Node3D that contains a Pivot (Node3D) -> Camera3D chain,
## or just a direct Camera3D child — either works with this script.

@export var pan_speed: float = 18.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 6.0
@export var max_zoom: float = 60.0
@export var rotate_sensitivity: float = 0.006
@export var edge_pan_enabled: bool = true
@export var edge_pan_margin: float = 12.0

var _camera: Camera3D
var _zoom_distance: float = 24.0
var _rotating: bool = false


func _ready() -> void:
	_camera = _find_camera(self)
	if _camera:
		_zoom_distance = _camera.position.z if _camera.position.z > 0.1 else _zoom_distance
		_apply_zoom()


func _find_camera(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found := _find_camera(child)
		if found:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_distance = clamp(_zoom_distance - zoom_speed, min_zoom, max_zoom)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_distance = clamp(_zoom_distance + zoom_speed, min_zoom, max_zoom)
			_apply_zoom()
	elif event is InputEventMouseMotion and _rotating:
		rotate_y(-event.relative.x * rotate_sensitivity)


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


func _edge_pan_direction() -> Vector2:
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
