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
const SEED_PRIORITY: float = 10.0
const WATER_PRIORITY: float = 10.0
const COLLECT_PRIORITY: float = 10.0
const DELIVER_PRIORITY: float = 10.0

var _rng: RandomNumberGenerator
var _needs: VillageNeeds
var _farm_labor: VillageFarmLabor
var _farm_seeding: VillageFarmSeeding
var _farm_watering: VillageFarmWatering

var _sleep_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
var _idle_targets: Dictionary = {}  # Villager -> Vector3
var _idle_stand_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
## Shared, reused across every idle/seeding/watering/collecting/
## delivering Villager — Task is immutable once constructed, and each
## kind's real per-Villager state lives in dictionaries (above, or on
## VillageFarmSeeding/VillageFarmWatering/VillageFarmLabor), never on the
## Task itself.
var _idle_task: Task = null
var _seed_task: Task = null
var _water_task: Task = null
var _collect_task: Task = null
var _deliver_task: Task = null


func _init(
	rng: RandomNumberGenerator,
	needs: VillageNeeds,
	farm_labor: VillageFarmLabor,
	farm_seeding: VillageFarmSeeding,
	farm_watering: VillageFarmWatering
) -> void:
	_rng = rng
	_needs = needs
	_farm_labor = farm_labor
	_farm_seeding = farm_seeding
	_farm_watering = farm_watering


## Never null — falls back through Deliver (if carrying) / Seed (if
## villager has farming Interest and a Farm is awaiting planting and
## unclaimed) / Water (if farming Interest and a planted Farm is below
## its growth threshold and unclaimed) / Collect (if farming Interest and
## a Farm is ready and unclaimed) / a shared Idle Task once neither Eat
## nor Sleep applies. Seed/Water/Collect are gated behind
## Villager.is_farmer (issue #39) — a non-farmer is never offered one of
## these, whatever the Farm state; Deliver isn't gated separately since
## only a Villager who already completed a Collect Task can be carrying.
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
	if villager.is_farmer:
		if _farm_seeding.has_seedable(farms):
			if _seed_task == null:
				_seed_task = Task.new(Task.KIND_SEED, SEED_PRIORITY)
			return _seed_task
		if _farm_watering.has_waterable(farms):
			if _water_task == null:
				_water_task = Task.new(Task.KIND_WATER, WATER_PRIORITY)
			return _water_task
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
	if candidate.kind == Task.KIND_SEED:
		_farm_seeding.claim_farm(villager, farms)
	elif candidate.kind == Task.KIND_WATER:
		_farm_watering.claim_farm(villager, farms)
	elif candidate.kind == Task.KIND_COLLECT:
		_farm_labor.claim_farm(villager, farms)
	return true


## Sleep prefers the Villager's own House position when set, else falls
## back to `site_position` (also used for Eat, "the store", and Deliver —
## the store and Deliver's destination are the same place). Seed/Collect
## go to the claimed Farm's position. Water goes to `water_source_position`
## until the fetch leg completes (VillageFarmWatering.has_collected_water()),
## then to the claimed Farm — same two-leg shape query_next_task()/
## begin_resolving_task() already thread through.
func task_destination(
	task: Task, villager: Villager, site_position: Vector3, water_source_position: Vector3
) -> Vector3:
	if task.kind == Task.KIND_SLEEP and villager.house != null:
		return villager.house.position
	if task.kind == Task.KIND_SEED:
		var farm := _farm_seeding.farm_for(villager)
		return farm.position if farm != null else site_position
	if task.kind == Task.KIND_WATER:
		var farm := _farm_watering.farm_for(villager)
		if farm != null and _farm_watering.has_collected_water(villager):
			return farm.position
		return water_source_position
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
## advance_idle()). Water is a special case (see below): reaching the
## water source doesn't resolve anything yet, so it returns before
## task_resolving is ever set.
func begin_resolving_task(villager: Villager, resources: Dictionary, day_speed: float) -> void:
	var task := villager.current_task
	if task == null:
		return
	if task.kind == Task.KIND_WATER and not _farm_watering.has_collected_water(villager):
		# First leg of the fetch-then-deposit round trip (issue #38):
		# reached the water source, not yet the claimed Farm. Mark the
		# fetch done and return without finishing the Task or entering
		# task_resolving — the next task_destination() query sends
		# villager on to the Farm instead, and the caller (village_
		# spawner.gd) redirects its Mover there.
		_farm_watering.mark_collected_water(villager)
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
		Task.KIND_SEED:
			# Resolves instantly, same as Eat/Collect — plants the claimed
			# Farm and releases the claim in one visit, no countdown (issue
			# #36's "done in one visit").
			_farm_seeding.resolve_seed(villager)
			_finish_task(villager)
		Task.KIND_WATER:
			# Second leg: reached the claimed Farm with water in hand —
			# deposits one dose and releases the claim, no countdown (same
			# instant-resolve shape as Seed/Collect once a Task's real
			# destination is reached).
			_farm_watering.resolve_water(villager)
			_finish_task(villager)
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
## they finish delivering or are interrupted" (issue #36/#38 extend this
## to the Seed/Water claims the same way — mid-fetch-leg included).
func interrupt_task(villager: Villager) -> void:
	_sleep_seconds_remaining.erase(villager)
	_idle_stand_seconds_remaining.erase(villager)
	_idle_targets.erase(villager)
	_farm_seeding.release_claim(villager)
	_farm_watering.release_claim(villager)
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
