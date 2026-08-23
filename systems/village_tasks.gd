class_name VillageTasks
extends RefCounted
## Task assignment, travel-then-resolve execution, and idle wandering for a
## Village's Villagers. Merges Eat/Sleep candidates (VillageNeeds) against
## every labor-pipeline candidate (VillageLaborTasks — Seed/Water/Collect/
## Deliver/Recover) and the Reproduce candidate (VillageReproduction, issue
## #42) by priority, and owns Sleep/Idle's own countdown execution directly;
## everything else about a labor Task kind (claiming, destination,
## resolving) is delegated to VillageLaborTasks — see that file's doc
## comment for why it's a separate collaborator rather than more inline
## branches here. Reproduce's gestation countdown works the same way Sleep's
## does (see advance_gestation()), just delegated to VillageReproduction
## since, unlike Sleep, completion needs to add a new Villager — Village.gd
## itself does that (see Village.advance_gestation()), the same "Village
## owns what VillageTasks can't reach" split known_resources/farms already
## have.

const SLEEP_DURATION_HOURS: float = 8.0

## Always the lowest-priority Task by construction, so it never outranks a
## real need.
const IDLE_PRIORITY: float = 0.0
const IDLE_WANDER_RADIUS: float = 12.0
const IDLE_STAND_SECONDS_MIN: float = 3.0
const IDLE_STAND_SECONDS_MAX: float = 8.0

var _rng: RandomNumberGenerator
var _needs: VillageNeeds
var _labor: VillageLaborTasks
var _reproduction: VillageReproduction

var _sleep_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
var _idle_targets: Dictionary = {}  # Villager -> Vector3
var _idle_stand_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining
## Shared, reused across every idling Villager — Task is immutable once
## constructed, and Idle's real per-Villager state lives in the
## dictionaries above.
var _idle_task: Task = null


func _init(
	rng: RandomNumberGenerator,
	needs: VillageNeeds,
	farm_labor: VillageFarmLabor,
	farm_seeding: VillageFarmSeeding,
	farm_watering: VillageFarmWatering,
	resource_recovery: VillageResourceRecovery
) -> void:
	_rng = rng
	_needs = needs
	_labor = VillageLaborTasks.new(farm_labor, farm_seeding, farm_watering, resource_recovery)
	_reproduction = VillageReproduction.new()


## Never null — falls back through Eat/Sleep (VillageNeeds, whichever's
## higher priority when both apply) / whatever VillageLaborTasks offers
## (Deliver if carrying / Seed / Water / Collect / Recover, see its
## candidate_for() doc comment for the full ordering and is_farmer gating)
## / Reproduce (VillageReproduction, if villager is a pair's designated
## parent — checked after labor so real village work always comes first,
## an implementer's call since issue #42 doesn't specify the ordering) /
## a shared Idle Task once nothing else applies.
func query_next_task(
	villager: Villager, farms: Array[Farm], known_resources: Array[LocationResource]
) -> Task:
	var eat_task := _needs.eat_task_for(villager)
	var sleep_task := _needs.sleep_task_for(villager)
	if eat_task != null and sleep_task != null:
		return eat_task if eat_task.priority >= sleep_task.priority else sleep_task
	if eat_task != null:
		return eat_task
	if sleep_task != null:
		return sleep_task
	var labor_task := _labor.candidate_for(villager, farms, known_resources)
	if labor_task != null:
		return labor_task
	var reproduce_task := _reproduction.candidate_for(villager)
	if reproduce_task != null:
		return reproduce_task
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
## redirect its Mover. `observed_at` is only ever consumed when this
## assignment interrupts a running Task while cargo is dropped (see
## interrupt_task()) — forwarded straight through, a no-op the rest of the
## time.
func advance_task_assignment(
	villager: Villager,
	farms: Array[Farm],
	known_resources: Array[LocationResource],
	observed_at: float = 0.0
) -> bool:
	var candidate := query_next_task(villager, farms, known_resources)
	if not should_interrupt(villager.current_task, candidate):
		return false
	if villager.current_task != null:
		interrupt_task(villager, known_resources, observed_at)
	villager.current_task = candidate
	villager.task_resolving = false
	_labor.claim(candidate, villager, farms, known_resources)
	return true


## Sleep prefers the Villager's own House position when set, else falls
## back to `site_position` (also used for Eat, Idle, and any labor Task
## kind VillageLaborTasks doesn't currently have a claimed destination
## for — see its destination_for() doc comment).
func task_destination(
	task: Task, villager: Villager, site_position: Vector3, water_source_position: Vector3
) -> Vector3:
	if task.kind == Task.KIND_SLEEP and villager.house != null:
		return villager.house.position
	return _labor.destination_for(task, villager, site_position, water_source_position)


static func has_reached_destination(
	position: Vector3, destination: Vector3, arrival_threshold: float = 0.1
) -> bool:
	return position.distance_to(destination) <= arrival_threshold


## Called once a Task's destination is reached. Eat resolves immediately;
## Sleep/Idle instead start their own countdown (see advance_sleeping()/
## advance_idle()). Water is a special case (see below): reaching the
## water source doesn't resolve anything yet, so it returns before
## task_resolving is ever set.
func begin_resolving_task(
	villager: Villager,
	resources: Dictionary,
	day_speed: float,
	known_resources: Array[LocationResource]
) -> void:
	var task := villager.current_task
	if task == null:
		return
	if task.kind == Task.KIND_WATER and not _labor.has_collected_water(villager):
		# First leg of the fetch-then-deposit round trip (issue #38):
		# reached the water source, not yet the claimed Farm. Mark the
		# fetch done and return without finishing the Task or entering
		# task_resolving — the next task_destination() query sends
		# villager on to the Farm instead, and the caller (village_
		# spawner.gd) redirects its Mover there.
		_labor.mark_collected_water(villager)
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
		Task.KIND_REPRODUCE:
			_reproduction.begin_gestation(villager)
		_:
			# Seed/Water(2nd leg)/Collect/Recover/Deliver all resolve
			# instantly and finish, same shape as Eat — delegated to
			# VillageLaborTasks since each one's actual effect belongs to
			# a labor-pipeline collaborator, not VillageTasks itself. A
			# genuinely unknown kind (shouldn't happen) just finishes,
			# same as before this delegation existed.
			_labor.resolve(task, villager, resources, known_resources)
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


## Same countdown shape as advance_sleeping(), but this class can't itself
## produce the new Villager a completed gestation implies (it only knows
## about farms/known_resources, not villagers/populate()) — returns true
## exactly on the call where gestation completes so Village.advance_gestation()
## knows to add one, mirroring how advance_idle()'s bool return tells its
## caller to redirect the Mover.
func advance_gestation(villager: Villager, delta: float) -> bool:
	var task := villager.current_task
	if task == null or task.kind != Task.KIND_REPRODUCE or not villager.task_resolving:
		return false
	if not _reproduction.advance_gestation(villager, delta):
		return false
	_finish_task(villager)
	return true


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


## Releases any Farm/resource claim unconditionally, whatever the
## interrupted Task's kind — see issue #33: a Farm claim is "released once
## they finish delivering or are interrupted" (issue #36/#38 extend this
## to the Seed/Water claims the same way — mid-fetch-leg included; issue
## #37 adds the Recover claim). Carried cargo is handled first, separately
## (see _drop_carried_cargo()) — issue #37 revises the old "carried cargo
## simply vanishes" behavior: a nonzero carry becomes a recoverable
## resource entry instead of being silently dropped by release_all_claims()
## below. `observed_at` is stamped onto that entry's last_observed marker,
## a bare value not yet consumed by anything (see LocationResource's doc
## comment) — a no-op while carrying nothing.
func interrupt_task(
	villager: Villager, known_resources: Array[LocationResource], observed_at: float = 0.0
) -> void:
	_drop_carried_cargo(villager, known_resources, observed_at)
	_sleep_seconds_remaining.erase(villager)
	_idle_stand_seconds_remaining.erase(villager)
	_idle_targets.erase(villager)
	_labor.release_all_claims(villager)
	_reproduction.release(villager)
	_finish_task(villager)


## Records a Villager's carried amount (from either source, via
## VillageLaborTasks.take_and_clear_carrying()) as a fresh Known Territory
## resource entry at their current position, then clears the carry.
## No-op while carrying nothing — e.g. an interrupted Seed/Water/Collect/
## Recover Task, which never reaches a nonzero carry (issue #37's
## acceptance criteria: "carrying zero ... does not add an entry").
func _drop_carried_cargo(
	villager: Villager, known_resources: Array[LocationResource], observed_at: float
) -> void:
	var amount := _labor.take_and_clear_carrying(villager)
	if amount <= 0:
		return
	known_resources.append(LocationResource.new(villager.position, amount, observed_at))


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
