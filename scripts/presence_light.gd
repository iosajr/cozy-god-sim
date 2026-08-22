class_name PresenceLight
extends OmniLight3D
## Cosmetic-only preview of Presence — light, not a hand or body. One
## entry point; no gameplay effect of any kind.


func move_to(point: Vector3) -> void:
	global_position = point
