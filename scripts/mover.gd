class_name Mover
extends Node3D
## Mover
## Generic, reusable "move toward a target position over real time"
## component (issue #14) — any spawned body can attach one to travel in
## a straight line at a constant speed, matching this project's total
## lack of pathfinding/navigation elsewhere (no NavigationServer, no
## obstacle avoidance). Completely ignorant of what it's moving or why:
## no Villager/Sheep/Farm-specific logic lives here — whatever calls
## move_to() decides what "arrived" means for it via the `arrived`
## signal, mirroring how presence_light.gd stays a thin, content-free
## presentation seam.
##
## No consumer is wired up this slice (issue #14's Out of Scope) —
## village_spawner.gd/sheep_spawner.gd don't attach one yet.
##
## Calling move_to() again before a previous target is reached simply
## replaces the current target — no queueing, no interruption handling
## beyond that (issue #14's User Story 8, flagged there as an
## implementer's call, not explicitly confirmed by the user).

## Emitted exactly once per move_to() call, the moment this body's
## position comes within `arrival_threshold` of the target it was told
## to move to. Not emitted again until the next move_to() call starts a
## fresh approach — see _physics_process()'s `_moving` guard below.
signal arrived

## Constant travel speed, world units/second. Tunable placeholder, same
## spirit as camera_rig.gd's pan_speed / village_spawner.gd's
## favored_gain_rate — an implementer's-call default, not a tuned design
## value (issue #14's Implementation Decisions: speed as an @export on
## the component, rather than passed per-call).
@export var speed: float = 4.0
## How close (world units) counts as "arrived" — an implementer's-call
## tunable, same spirit as camera_rig.gd's click_threshold_px.
@export var arrival_threshold: float = 0.1

var _target: Vector3 = Vector3.ZERO
## True from a move_to() call until `arrived` fires for it. Guards
## _physics_process() so a body sitting at its last-reached target
## doesn't keep re-evaluating (and re-emitting) every frame — `arrived`
## is a one-shot notification per move_to() call, not a continuous
## "am I there" signal (issue #14's User Story 4).
var _moving: bool = false


## Tells this body to travel toward `target_position` in a straight
## line at `speed`. Replacing any target already in progress — see this
## script's top-level doc comment.
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


## Pure straight-line movement math (issue #14's User Story 5) — no
## Node, no scene tree, mirroring scripts/ground_ray.gd's
## intersect_ground_plane() shape exactly, so it's directly unit
## testable via GUT (see tests/scripts/test_mover.gd). Advances
## `current_position` toward `target_position` by at most `speed * delta`
## world units, via Godot's own Vector3.move_toward() (which already
## clamps to the target rather than overshooting past it), and reports
## whether the result lands within `arrival_threshold` of the target.
## Returns a Dictionary with:
##   "position": Vector3 — the new position after this step.
##   "arrived": bool — true if "position" is within `arrival_threshold`
##              of `target_position`.
## Zero delta or an already-reached target are both handled gracefully:
## the former simply produces no movement, the latter reports arrived
## immediately without moving.
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
