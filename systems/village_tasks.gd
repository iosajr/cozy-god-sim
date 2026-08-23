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

## Passtime-tier, same as Idle — above Idle so an idle Villager picks farm
## work up, below Eat/Sleep's hunger/tiredness priorities so real needs
## always win (see docs/systems-overview.md's Task Priority section).
const COLLECT_PRIORITY: float = 10.0
const DELIVER_PRIORITY: float = 10.0

var _rng: RandomNumberGenerator
var _needs: VillageNeeds
var _farm_labor: VillageFarmLabor

var _sleep_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
var _idle_targets: Dictionary = {}  # Villager -> Vector3
var _idle_stand_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
## Shared, reused across every idle/collecting/delivering Villager — Task
## is immutable once constructed, and each kind's real per-Villager state
## lives in dictionaries (above, or on VillageFarmLabor), never on the
## Task itself.
var _idle_task: Task = null
var _collect_task: Task = null
var _deliver_task: Task = null


func _init(rng: RandomNumberGenerator, needs: VillageNeeds, farm_labor: VillageFarmLabor) -> void:
	_rng = rng
	_needs = needs
	_farm_labor = farm_labor


## Never null — falls back through Deliver (if carrying) / Collect (if a
## Farm is ready and unclaimed) / a shared Idle Task once neither Eat nor
## Sleep applies.
func query_next_task(villager: Villager, farms: Array[Farm]) -> Task:
	var eat_task := _needs.eat_task_for(villager)
	var sleep_task := _needs.sleep_task_for(villager)
	if eat_task != null and sleep_task != null:
		return eat_task if eat_task.priority >= sleep_task.priority else sleep_task
	if eat_task != null:
		return eat_task
	if sleep_task != null:
		return sleep_task
	if _farm_labor.is_carrying(villager):
		if _deliver_task == null:
			_deliver_task = Task.new(Task.KIND_DELIVER, DELIVER_PRIORITY)
		return _deliver_task
	if _farm_labor.has_collectible(farms):
		if _collect_task == null:
			_collect_task = Task.new(Task.KIND_COLLECT, COLLECT_PRIORITY)
		return _collect_task
	if _idle_task == null:
		_idle_task = Task.new(Task.KIND_IDLE, IDLE_PRIORITY)
	return _idle_task


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
func advance_task_assignment(villager: Villager, farms: Array[Farm]) -> bool:
	var candidate := query_next_task(villager, farms)
	if not should_interrupt(villager.current_task, candidate):
		return false
	if villager.current_task != null:
		interrupt_task(villager)
	villager.current_task = candidate
	villager.task_resolving = false
	if candidate.kind == Task.KIND_COLLECT:
		_farm_labor.claim_farm(villager, farms)
	return true


## Sleep prefers the Villager's own House position when set, else falls
## back to `site_position` (also used for Eat, "the store", and Deliver —
## the store and Deliver's destination are the same place). Collect goes
## to the claimed Farm's position.
func task_destination(task: Task, villager: Villager, site_position: Vector3) -> Vector3:
	if task.kind == Task.KIND_SLEEP and villager.house != null:
		return villager.house.position
	if task.kind == Task.KIND_COLLECT:
		var farm := _farm_labor.farm_for(villager)
		return farm.position if farm != null else site_position
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
		Task.KIND_COLLECT:
			# Resolves instantly, same as Eat — the follow-up Deliver Task
			# isn't assigned directly (that would bypass the mover-redirect
			# that only fires through advance_task_assignment()); instead
			# it naturally resurfaces the next time query_next_task() is
			# asked, same pattern Eat/Sleep already use for a still-pending
			# need (see docs/systems-overview.md's Task execution section).
			_farm_labor.resolve_collect(villager)
			_finish_task(villager)
		Task.KIND_DELIVER:
			var amount := _farm_labor.take_carrying(villager)
			resources["food"] = resources.get("food", 0) + amount
			_farm_labor.release_claim(villager)
			_finish_task(villager)
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


## Releases any Farm claim/carried cargo unconditionally, whatever the
## interrupted Task's kind — see issue #33: a Farm claim is "released once
## they finish delivering or are interrupted".
func interrupt_task(villager: Villager) -> void:
	_sleep_seconds_remaining.erase(villager)
	_idle_stand_seconds_remaining.erase(villager)
	_idle_targets.erase(villager)
	_farm_labor.release_claim(villager)
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
