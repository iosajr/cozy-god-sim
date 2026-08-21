class_name CameraRig
extends Node3D
## CameraRig
## A simple RTS/god-sim style camera:
##   - WASD / arrow keys to pan across the ground plane
##   - Mouse wheel to zoom in/out
##   - Hold right mouse button and drag to rotate (yaw) and tilt (pitch,
##     issue #9) — one gesture for the whole "look around" feel.
##   - Hold left mouse button and drag to pan 1:1 — the ground point
##     grabbed at press-time stays under the cursor (issue #5), additive
##     to the WASD/edge-pan above, not a replacement.
##   - A plain left click (button down then up with barely any mouse
##     movement — see `click_threshold_px`) on a body in the
##     `DIALOGUE_CLICK_GROUP` group emits `dialogue_target_clicked`
##     instead (issue #12), so a click-to-open-dialogue and a drag-pan
##     that merely starts on top of the same body don't fight each other
##     (issue #12's User Story 7).
## Attach to a Node3D that contains a Pivot (Node3D) -> Camera3D chain,
## or just a direct Camera3D child — either works with this script. Pitch
## is only applied when a separate Pivot node exists: applying it to the
## CameraRig root itself (the direct-Camera3D-child layout) would
## contaminate the yaw-only assumption `_physics_process()`'s WASD/
## edge-pan/drag-pan math makes about `global_transform.basis`.

## Any StaticBody3D added to this group is a valid `dialogue_target_clicked`
## target (issue #12's Implementation Decisions). Deliberately generic:
## CameraRig doesn't know about Villagers, Renown, or dialogue content at
## all — only "was a body in this group hit by a plain click, not a
## drag?" Whoever adds bodies to this group (village_spawner.gd) and
## whoever listens to the signal (also village_spawner.gd) owns what that
## means; a future Renowned-sheep click (issue #11's natural follow-up)
## can reuse the same group with no CameraRig change at all.
const DIALOGUE_CLICK_GROUP := "dialogue_clickable"

## Emitted once per completed left-click — button down then up with total
## mouse movement no more than `click_threshold_px` (i.e. a click, not a
## drag; issue #12's User Story 7) — that started on a body in
## `DIALOGUE_CLICK_GROUP`. Carries that body so the listener can map it
## back to whatever it represents.
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
## Max mouse movement (pixels, press to release) for a left click to
## still count as a click rather than a drag (issue #12's User Story 7).
## Tunable placeholder, same spirit as pan_speed/rotate_sensitivity above.
@export var click_threshold_px: float = 6.0

var _camera: Camera3D
var _pivot: Node3D
var _zoom_distance: float = 24.0
var _pitch: float = 0.0
var _rotating: bool = false
var _dragging: bool = false
var _drag_grab_point: Vector3 = Vector3.ZERO
var _press_mouse_pos: Vector2 = Vector2.ZERO
## Set at left-button press time to whatever DIALOGUE_CLICK_GROUP body a
## physics raycast hit under the cursor, or null if none (see
## _raycast_mouse_to_dialogue_target()). Only acted on at release, and
## only if the click didn't turn into a drag (see _on_left_click()).
var _press_hit_dialogue_body: Node3D = null


func _ready() -> void:
	_camera = _find_camera(self)
	if _camera:
		_zoom_distance = _camera.position.z if _camera.position.z > 0.1 else _zoom_distance
		_apply_zoom()

	_pivot = _find_pivot()
	if _pivot:
		_set_pitch(_pivot.rotation.x)


func _find_camera(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found := _find_camera(child)
		if found:
			return found
	return null


## Resolves the Camera3D's parent as the pitch target — but only when
## that parent is a separate Pivot node, not the CameraRig root itself.
## A direct-Camera3D-child layout (no Pivot) is a valid scene shape per
## this script's own doc comment, and pitching the root would corrupt
## the yaw-only `global_transform.basis` assumption the WASD/edge-pan/
## drag-pan math relies on — so that layout gets no pitch at all.
func _find_pivot() -> Node3D:
	if not _camera:
		return null
	var parent := _camera.get_parent()
	if parent == self:
		return null
	return parent as Node3D


## Clamps radians to [min_pitch_deg, max_pitch_deg], stores it in _pitch,
## and applies it to the Pivot. Shared by the initial seed in _ready()
## and every per-frame update in _unhandled_input().
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
			# Pivot pitch is negative-down in this scene's authored layout
			# (Camera3D sits behind Pivot along +Z, looking down -Z), so
			# dragging the mouse down (relative.y > 0) should tilt further
			# down (more negative), and dragging up should tilt toward the
			# horizon (less negative) — an FPS-mouselook-style convention.
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

	# Released. A drag-pan may have run this whole time regardless (the
	# ground-plane raycast above doesn't know or care what else is under
	# the cursor) — whether this also counts as a "click" on a dialogue
	# target is decided here, purely by how far the mouse actually moved
	# (issue #12's User Story 7), not by what was hit at press-time alone.
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
		# Safety net for a lost mouse-up event (e.g. alt-tabbing away
		# mid-drag never delivers one to _unhandled_input) — without
		# this, _dragging could get stuck true and the camera would
		# keep chasing the last grab point indefinitely.
		_dragging = false

	if _dragging:
		_apply_drag_pan()


## Recomputes, fresh from the current camera transform, the XZ delta
## needed to bring the original grab point back under the cursor, and
## applies it. Never accumulates deltas across frames, so a long drag
## can't drift. If the current mouse ray doesn't meet the ground plane
## (GroundRay's defined not-a-hit case), the camera simply doesn't move
## this frame rather than erroring.
func _apply_drag_pan() -> void:
	var hit := _raycast_mouse_to_ground()
	if not hit["hit"]:
		return

	var current_point: Vector3 = hit["point"]
	var motion: Vector3 = _drag_grab_point - current_point
	motion.y = 0.0
	global_position += motion


## Computes the current mouse position's world-space ray (origin +
## direction) from `_camera`, shared by both raycast helpers below so
## the mouse-pos/project_ray_origin/project_ray_normal setup only lives
## in one place. Returns an empty Dictionary if `_camera` or the
## viewport isn't available yet.
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


## Raycasts the current mouse position against the y = 0 ground plane via
## GroundRay. Shared by drag-pan's press-time grab and its per-frame
## recompute.
func _raycast_mouse_to_ground() -> Dictionary:
	var ray := _mouse_ray()
	if ray.is_empty():
		return {"hit": false, "point": Vector3.ZERO}
	return GroundRay.intersect_ground_plane(ray["origin"], ray["direction"])


## Physics raycast (a real 3D query against actual colliders, distinct
## from `_raycast_mouse_to_ground()`'s pure ground-plane math above)
## against the current mouse position, used only to detect a
## DIALOGUE_CLICK_GROUP hit at left-click press time (issue #12). Returns
## the hit collider when it's in that group, else null — never errors on
## a missing camera/viewport/physics space, same defensive shape as
## `_raycast_mouse_to_ground()`.
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
