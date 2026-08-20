extends Node3D
## PresenceCursor
## Drives the cosmetic Presence-light preview (issue #5): every frame,
## dragging or not, raycasts the current mouse position against the
## ground plane via GroundRay and moves the PresenceLight child there.
## Purely a preview of Presence's eventual look — no Nudge, no
## Faith-gating, no Villager interaction of any kind (see CONTEXT.md's
## Presence entry and docs/systems-overview.md's UI/presentation notes).
##
## Uses the viewport's active camera directly (Viewport.get_camera_3d())
## rather than reaching into CameraRig, so this node has no dependency on
## camera_rig.gd's internals — just "whatever camera is currently live."

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
