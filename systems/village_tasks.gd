class_name VillageTasks
extends RefCounted
## Task assignment, travel-then-resolve execution, and idle wandering for a
## Village's Villagers.

const SLEEP_DURATION_HOURS: float = 8.0

## Always the lowest-priority Task by construction, so it never outranks a
## real need.
const IDLE_PRIORITY: float = 0.0
const IDLE_WANDER_RADIUS: float = 12.0
const IDLE_STAND_SECONDS_MIN: float = 3.0
const IDLE_STAND_SECONDS_MAX: float = 8.0

var _rng: RandomNumberGenerator
var _needs: VillageNeeds

var _sleep_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
var _idle_targets: Dictionary = {}  # Villager -> Vector3
var _idle_stand_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
## Shared, reused across every idle Villager — Task is immutable once
## constructed, and Idle's real per-Villager state lives in the
## dictionaries above, never on the Task itself.
var _idle_task: Task = null


func _init(rng: RandomNumberGenerator, needs: VillageNeeds) -> void:
	_rng = rng
	_needs = needs


## Never null — falls back to a shared Idle Task once neither Eat nor
## Sleep applies.
func query_next_task(villager: Villager) -> Task:
	var eat_task := _needs.eat_task_for(villager)
	var sleep_task := _needs.sleep_task_for(villager)
	if eat_task == null and sleep_task == null:
		if _idle_task == null:
			_idle_task = Task.new(Task.KIND_IDLE, IDLE_PRIORITY)
		return _idle_task
	if eat_task == null:
		return sleep_task
	if sleep_task == null:
		return eat_task
	return eat_task if eat_task.priority >= sleep_task.priority else sleep_task


## A running Idle Task is preempted by any non-Idle candidate; anything
## else only accepts a Must-do candidate.
func should_interrupt(current_task: Task, candidate: Task) -> bool:
	if candidate == null:
		return false
	if current_task == null:
		return true
	if current_task.kind == Task.KIND_IDLE:
		return candidate.kind != Task.KIND_IDLE
	return candidate.is_must_do()


## Returns true if the assignment actually changed, so the caller knows to
## redirect its Mover.
func advance_task_assignment(villager: Villager) -> bool:
	var candidate := query_next_task(villager)
	if not should_interrupt(villager.current_task, candidate):
		return false
	if villager.current_task != null:
		interrupt_task(villager)
	villager.current_task = candidate
	villager.task_resolving = false
	return true


## Sleep prefers the Villager's own House position when set, else falls
## back to `site_position` (also used for Eat, "the store").
func task_destination(task: Task, villager: Villager, site_position: Vector3) -> Vector3:
	if task.kind == Task.KIND_SLEEP and villager.house != null:
		return villager.house.position
	return site_position


static func has_reached_destination(
	position: Vector3, destination: Vector3, arrival_threshold: float = 0.1
) -> bool:
	return position.distance_to(destination) <= arrival_threshold


## Called once a Task's destination is reached. Eat resolves immediately;
## Sleep/Idle instead start their own countdown (see advance_sleeping()/
## advance_idle()).
func begin_resolving_task(villager: Villager, resources: Dictionary, day_speed: float) -> void:
	var task := villager.current_task
	if task == null:
		return
	villager.task_resolving = true
	match task.kind:
		Task.KIND_EAT:
			_needs.resolve_eat(villager, resources)
			_finish_task(villager)
		Task.KIND_SLEEP:
			_sleep_seconds_remaining[villager] = _sleep_duration_seconds(day_speed)
		Task.KIND_IDLE:
			_idle_stand_seconds_remaining[villager] = _random_idle_stand_seconds()
		_:
			_finish_task(villager)


func advance_sleeping(villager: Villager, delta: float) -> void:
	var task := villager.current_task
	if task == null or task.kind != Task.KIND_SLEEP or not villager.task_resolving:
		return
	if not _sleep_seconds_remaining.has(villager):
		return
	var remaining: float = _sleep_seconds_remaining[villager] - delta
	if remaining <= 0.0:
		_needs.recover_tiredness(villager)
		_sleep_seconds_remaining.erase(villager)
		_finish_task(villager)
	else:
		_sleep_seconds_remaining[villager] = remaining


## Returns true exactly on the frame a fresh wander leg starts (Idle never
## finishes on its own — only an interruption ends it).
func advance_idle(villager: Villager, delta: float, site_position: Vector3) -> bool:
	var task := villager.current_task
	if task == null or task.kind != Task.KIND_IDLE or not villager.task_resolving:
		return false
	if not _idle_stand_seconds_remaining.has(villager):
		return false
	var remaining: float = _idle_stand_seconds_remaining[villager] - delta
	if remaining <= 0.0:
		_idle_stand_seconds_remaining.erase(villager)
		_idle_targets[villager] = _random_idle_point(site_position)
		villager.task_resolving = false
		return true
	_idle_stand_seconds_remaining[villager] = remaining
	return false


func idle_destination(villager: Villager, site_position: Vector3) -> Vector3:
	if not _idle_targets.has(villager):
		_idle_targets[villager] = _random_idle_point(site_position)
	return _idle_targets[villager]


func interrupt_task(villager: Villager) -> void:
	_sleep_seconds_remaining.erase(villager)
	_idle_stand_seconds_remaining.erase(villager)
	_idle_targets.erase(villager)
	_finish_task(villager)


func _finish_task(villager: Villager) -> void:
	villager.current_task = null
	villager.task_resolving = false


func _sleep_duration_seconds(day_speed: float) -> float:
	return SLEEP_DURATION_HOURS / day_speed if day_speed > 0.0 else 0.0


## Uniform over the wander disc (angle uniform, radius scaled by sqrt() to
## avoid center-biasing), on the same ground plane as site_position.
func _random_idle_point(site_position: Vector3) -> Vector3:
	var angle := _rng.randf_range(0.0, TAU)
	var radius := IDLE_WANDER_RADIUS * sqrt(_rng.randf())
	return site_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _random_idle_stand_seconds() -> float:
	return _rng.randf_range(IDLE_STAND_SECONDS_MIN, IDLE_STAND_SECONDS_MAX)
