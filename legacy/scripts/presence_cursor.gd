extends Node3D
## Every frame, raycasts the mouse against the ground plane and moves the
## PresenceLight child there. Uses the viewport's active camera directly,
## no dependency on CameraRig.

@onready var _light: PresenceLight = $PresenceLight


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var hit := GroundRay.intersect_ground_plane(ray_origin, ray_direction)
	if hit["hit"]:
		_light.move_to(hit["point"])
