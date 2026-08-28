class_name VillageReproduction
extends RefCounted
## Reproduce Task candidacy + gestation countdown for a Village's paired
## Villagers (issue #42) -- the "Task, then gestation-duration, then a new
## Villager" half of Reproducing; #41's VillagePairing is the data/detection
## half only (no Task, no offspring). A plain collaborator, not itself a
## TaskProvider -- tested directly, same pattern as VillagePairing/
## VillageLaborTasks. Owned by VillageTasks, mirroring how VillageTasks
## already owns VillageLaborTasks.
##
## Actually adding the newborn Villager to Village.villagers is NOT this
## class's job -- Village.gd owns that (it already owns populate(), which
## generating a newborn the same way reuses), so advance_gestation() just
## reports completion; see Village.advance_gestation().

## Passtime tier, same as every VillageLaborTasks Task kind -- "ambient,
## never urgent, never competing with real survival needs" per issue #42,
## well below Eat/Sleep's Important-tier priorities and PRIORITY_MUST_DO_
## THRESHOLD.
const REPRODUCE_PRIORITY: float = 10.0

## How long (in seconds) a resolving Reproduce Task takes before a new
## Villager is added. Tunable, not defended, same spirit as
## VillageTasks.SLEEP_DURATION_HOURS/VillagePairing.pairing_duration.
const GESTATION_DURATION_SECONDS: float = 60.0

## Shared, reused across every gesting Villager -- Task is immutable once
## constructed, and the real per-Villager state is _gestation_remaining
## below (mirrors every other cached Task instance in this codebase).
var _reproduce_task: Task = null

## Villager -> float seconds remaining, only present while a Reproduce Task
## is actively resolving for that Villager.
var _gestation_remaining: Dictionary = {}


## Null unless `villager` is the designated parent of a pair (see
## _is_designated_parent()) -- a bare unpaired Villager, or the non-
## designated partner of a pair, is never offered one.
##
## Nothing unpairs a couple or cools their eligibility down after a
## newborn arrives, so the same pair is offered a fresh Reproduce Task
## again immediately -- issue #42 doesn't specify a fertility limit,
## one-birth-per-pairing rule, or cooldown, and repeated ambient
## population growth from a standing pair reads as the intended shape of
## "population is static ... this is meant to happen autonomously in the
## background" (issue #23's problem statement), not a bug to silently
## guard against. Flagged as a real, deliberate gap for a future ticket
## if unbounded growth turns out to be unwanted, not invented scope here.
func candidate_for(villager: Villager) -> Task:
	if not _is_designated_parent(villager):
		return null
	if _reproduce_task == null:
		_reproduce_task = Task.new(Task.KIND_REPRODUCE, REPRODUCE_PRIORITY)
	return _reproduce_task


## Gestation is tracked once per pair, not once per Villager -- if both
## partners were independently offered a Reproduce Task, both would
## independently gestate and each add a newborn, doubling every pairing's
## output. Only the partner with the lexicographically smaller id is ever
## offered the Task; the arbitrary tie-break mirrors VillagePairing's own
## pair-key ordering (_pair_key()). An implementer's call, same spirit as
## VillagePairing's own documented decisions -- the issue doesn't specify
## which/how many partners gestate.
static func _is_designated_parent(villager: Villager) -> bool:
	var partner := villager.paired_with
	return partner != null and villager.id < partner.id


func begin_gestation(villager: Villager) -> void:
	_gestation_remaining[villager] = GESTATION_DURATION_SECONDS


## Returns true exactly on the call where the countdown completes. A
## no-op (always false) for a Villager with no gestation in progress --
## begin_gestation() was never called, or release() cleared it.
func advance_gestation(villager: Villager, delta: float) -> bool:
	if not _gestation_remaining.has(villager):
		return false
	var remaining: float = _gestation_remaining[villager] - delta
	if remaining <= 0.0:
		_gestation_remaining.erase(villager)
		return true
	_gestation_remaining[villager] = remaining
	return false


## Cuts a resolving gestation short without completing it -- called on
## Task interruption, mirroring VillageTasks._sleep_seconds_remaining.erase().
func release(villager: Villager) -> void:
	_gestation_remaining.erase(villager)
