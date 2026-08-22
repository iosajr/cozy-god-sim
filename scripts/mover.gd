class_name Mover
extends Node3D
## Generic straight-line "move toward a target over time" component — no
## pathfinding, no knowledge of what it's moving. Calling move_to() again
## before arrival just replaces the current target.

## Emitted once per move_to() call, when this body comes within
## arrival_threshold of the target.
signal arrived

@export var speed: float = 4.0
@export var arrival_threshold: float = 0.1

var _target: Vector3 = Vector3.ZERO
## True from move_to() until arrived fires — keeps arrived a one-shot
## notification, not a continuous "am I there" signal.
var _moving: bool = false


func move_to(target_position: Vector3) -> void:
	_target = target_position
	_moving = true


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	var result := Mover.advance(global_position, _target, speed, delta, arrival_threshold)
	global_position = result["position"]
	if result["arrived"]:
		_moving = false
		arrived.emit()


## Pure movement math (no Node), unit-testable directly. Returns
## {"position": Vector3, "arrived": bool}.
static func advance(
	current_position: Vector3,
	target_position: Vector3,
	speed: float,
	delta: float,
	arrival_threshold: float
) -> Dictionary:
	var new_position := current_position.move_toward(target_position, speed * delta)
	var has_arrived := new_position.distance_to(target_position) <= arrival_threshold
	return {"position": new_position, "arrived": has_arrived}
