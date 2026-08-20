class_name PresenceLight
extends OmniLight3D
## PresenceLight
## Cosmetic-only preview of Presence (see CONTEXT.md: "not a hand or a
## body, but light"). Thin presentation seam mirroring
## villager_nameplate.gd's shape from issue #2: one public entry point —
## `move_to()` — sets the light's position and nothing else is exposed.
## No Nudge, no Faith-gating, no gameplay effect of any kind; a scene
## script (presence_cursor.gd) drives this every frame via GroundRay,
## regardless of whether the Player is dragging the camera.


func move_to(point: Vector3) -> void:
	position = point
