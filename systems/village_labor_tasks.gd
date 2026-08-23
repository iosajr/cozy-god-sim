class_name VillageLaborTasks
extends RefCounted
## Candidate/claim/destination/resolve dispatch for every labor-pipeline
## Task kind (Seed/Water/Collect/Deliver/Recover) — the "which Farm-Labor-
## or-Recovery collaborator owns this Task.kind" routing that used to live
## inline across VillageTasks's own methods, one growing branch per farm-
## cluster issue (#33/#36/#38/#39/#40/#35/#37). Extracted once that
## per-method fan-out across five distinct Task kinds became more than one
## person should have to hold in their head at once (issue #37's own
## module-hygiene pass) — mirrors how systems/village_needs.gd already
## owns the same shape of thing for Eat/Sleep, just for this cluster's
## Task kinds instead. VillageTasks stays the actual TaskProvider-facing
## orchestrator: it still owns should_interrupt()/the Eat-vs-Sleep-vs-
## labor-vs-Idle priority merge, and every non-labor Task kind's own
## execution (Sleep's countdown, Idle's wander, Eat's resolution via
## VillageNeeds).
##
## Not itself a TaskProvider — a plain collaborator VillageTasks composes,
## same relationship VillageFarmSeeding/VillageFarmWatering/
## VillageFarmLabor/VillageResourceRecovery already have with it. Owns no
## state of its own beyond the five cached Task instances below; all real
## per-Villager/per-Farm/per-entry state still lives on the four
## claim-state collaborators it wires together.

const SEED_PRIORITY: float = 10.0
const WATER_PRIORITY: float = 10.0
const COLLECT_PRIORITY: float = 10.0
const DELIVER_PRIORITY: float = 10.0
## Same Passtime tier as Collect — a Recover Task is its generic, non-
## farming counterpart (issue #37), not a higher- or lower-priority chore.
const RECOVER_PRIORITY: float = 10.0

var _farm_labor: VillageFarmLabor
var _farm_seeding: VillageFarmSeeding
var _farm_watering: VillageFarmWatering
var _resource_recovery: VillageResourceRecovery

## Shared, reused across every seeding/watering/collecting/delivering/
## recovering Villager — Task is immutable once constructed, and each
## kind's real per-Villager state lives on whichever claim-state
## collaborator owns it, never on the Task itself.
var _seed_task: Task = null
var _water_task: Task = null
var _collect_task: Task = null
var _deliver_task: Task = null
var _recover_task: Task = null


func _init(
	farm_labor: VillageFarmLabor,
	farm_seeding: VillageFarmSeeding,
	farm_watering: VillageFarmWatering,
	resource_recovery: VillageResourceRecovery
) -> void:
	_farm_labor = farm_labor
	_farm_seeding = farm_seeding
	_farm_watering = farm_watering
	_resource_recovery = resource_recovery


func is_carrying(villager: Villager) -> bool:
	return _farm_labor.is_carrying(villager) or _resource_recovery.is_carrying(villager)


## Pass-throughs for the Water Task's two-leg fetch/deposit shape (issue
## #38) — VillageTasks.begin_resolving_task() needs to special-case the
## first leg (reaching the water source) before any labor Task's normal
## instant-resolve dispatch applies.
func has_collected_water(villager: Villager) -> bool:
	return _farm_watering.has_collected_water(villager)


func mark_collected_water(villager: Villager) -> void:
	_farm_watering.mark_collected_water(villager)


## Null if no labor Task applies right now — callers fall through to
## their own next-lowest candidate (Idle). Deliver (if carrying, from
## either source) / Seed (if villager has farming Interest and a Farm is
## awaiting planting and unclaimed) / Water (if farming Interest and a
## planted Farm is below its growth threshold and unclaimed) / Collect
## (if farming Interest and a Farm is ready and unclaimed) / Recover (if
## a Known Territory resource entry is unclaimed) — in that order.
## Seed/Water/Collect are gated behind Villager.is_farmer (issue #39); a
## non-farmer is never offered one of these, whatever the Farm state.
## Recover isn't gated the same way (issue #37) — recovering a known
## resource is generic work, offered to any idle Villager, farmer or not;
## it's checked after farm work so a farmer with real farm work pending
## still does that first. Deliver isn't gated separately since only a
## Villager who already completed a Collect or Recover Task can be
## carrying.
func candidate_for(
	villager: Villager, farms: Array[Farm], known_resources: Array[LocationResource]
) -> Task:
	if is_carrying(villager):
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
	if _resource_recovery.has_recoverable(known_resources):
		if _recover_task == null:
			_recover_task = Task.new(Task.KIND_RECOVER, RECOVER_PRIORITY)
		return _recover_task
	return null


## Claims whatever `candidate` targets on villager's behalf — a no-op for
## Deliver (nothing left to claim, the follow-up leg of an already-held
## claim) or any non-labor kind.
func claim(
	candidate: Task, villager: Villager, farms: Array[Farm], known_resources: Array[LocationResource]
) -> void:
	if candidate.kind == Task.KIND_SEED:
		_farm_seeding.claim_farm(villager, farms)
	elif candidate.kind == Task.KIND_WATER:
		_farm_watering.claim_farm(villager, farms)
	elif candidate.kind == Task.KIND_COLLECT:
		_farm_labor.claim_farm(villager, farms)
	elif candidate.kind == Task.KIND_RECOVER:
		_resource_recovery.claim_entry(villager, known_resources)


## The claimed destination for a labor Task kind, `site_position` for
## anything this class doesn't own (Eat/Sleep-without-a-house/Idle/
## Deliver all resolve to "the store" already, so this doubles as their
## fallback too). Water is a fetch-then-deposit round trip (issue #38):
## the water source first, then the claimed Farm once
## VillageFarmWatering.has_collected_water() is true.
func destination_for(
	task: Task, villager: Villager, site_position: Vector3, water_source_position: Vector3
) -> Vector3:
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
	if task.kind == Task.KIND_RECOVER:
		var entry := _resource_recovery.entry_for(villager)
		return entry.position if entry != null else site_position
	return site_position


## Runs whichever labor collaborator owns `task.kind`'s actual effect —
## a no-op for any non-labor kind. Every labor kind resolves instantly
## (no countdown), so the caller always follows this with _finish_task().
func resolve(
	task: Task, villager: Villager, resources: Dictionary, known_resources: Array[LocationResource]
) -> void:
	match task.kind:
		Task.KIND_SEED:
			# Plants the claimed Farm and releases the claim in one visit,
			# no countdown (issue #36's "done in one visit").
			_farm_seeding.resolve_seed(villager)
		Task.KIND_WATER:
			# Second leg: reached the claimed Farm with water in hand —
			# deposits one dose and releases the claim.
			_farm_watering.resolve_water(villager)
		Task.KIND_COLLECT:
			# The follow-up Deliver Task isn't assigned directly here
			# (that would bypass the mover-redirect that only fires
			# through VillageTasks.advance_task_assignment()); instead it
			# naturally resurfaces the next time candidate_for() is asked,
			# same pattern Eat/Sleep already use for a still-pending need.
			_farm_labor.resolve_collect(villager)
		Task.KIND_RECOVER:
			# Resolves instantly, same as Collect — the follow-up Deliver
			# Task naturally resurfaces the same way (issue #37).
			_resource_recovery.resolve_recover(villager, known_resources)
		Task.KIND_DELIVER:
			# At most one of these is ever nonzero -- a Villager only ever
			# carries from a single source (a Farm harvest or a recovered
			# resource entry) at a time -- so summing both is a safe,
			# source-agnostic way to read whichever one produced it.
			var amount := take_and_clear_carrying(villager)
			resources["food"] = resources.get("food", 0) + amount
			release_all_claims(villager)


## Returns and clears whatever amount villager is carrying, from either
## source — used both by resolve()'s Deliver branch and by
## VillageTasks.interrupt_task()'s cargo-drop (issue #37).
func take_and_clear_carrying(villager: Villager) -> int:
	return _farm_labor.take_carrying(villager) + _resource_recovery.take_carrying(villager)


## Releases every labor claim villager might hold, whichever kind it
## actually is — called both on a normal Deliver resolution and on
## interruption (see issue #33/#36/#38/#37: a claim is "released once
## they finish [...] or are interrupted"). Releasing a claim villager
## never held is always a safe no-op, so calling all four unconditionally
## is simpler than tracking which one applies.
func release_all_claims(villager: Villager) -> void:
	_farm_seeding.release_claim(villager)
	_farm_watering.release_claim(villager)
	_farm_labor.release_claim(villager)
	_resource_recovery.release_claim(villager)
