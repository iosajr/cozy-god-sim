class_name VillageFarmLabor
extends RefCounted
## Farm-work claim/carry state for a Village's Villagers — the Collect/
## Deliver half of Task-based Farm Labor (issue #33). Watering (rain-driven
## Farm growth) is a separate concern, still owned by systems/
## village_farms.gd; this file only covers the harvest-and-deliver side.
##
## A Farm can be claimed by up to `capacity` Villagers at once (issue #35)
## — each holds its own independent claim, from the moment its Collect Task
## is assigned until that Villager either finishes delivering or is
## interrupted — see VillageTasks.interrupt_task()/begin_resolving_task().
## Concurrent claimants harvest from the same Farm.remaining_harvest pool,
## first-come-first-served; Farm.harvest() already caps each individual
## take at what's actually left, so sharing the pool needs no extra
## bookkeeping here — only letting more than one Villager hold a claim.

## How much a single Villager harvests per Collect Task, tunable (matches
## the old standalone delivery walker's default carry_capacity).
var carry_capacity: int = 5

## How many Villagers can hold a Collect Task claim against the same Farm
## at once, tunable (issue #35 — replaces the old strict one-worker claim;
## this, not a reservation lock, is what keeps an unbounded crowd off one
## patch).
var capacity: int = 4

var _claims_by_farm: Dictionary = {}  # Farm -> Array[Villager]
var _claimed_farm_by_villager: Dictionary = {}  # Villager -> Farm
var _carrying: Dictionary = {}  # Villager -> int amount pending delivery


## Pure query — true if any Farm is Ready-to-Harvest and holds fewer than
## `capacity` current claimants.
func has_collectible(farms: Array[Farm]) -> bool:
	for farm in farms:
		if farm.stage == Farm.FARM_READY_TO_HARVEST and _claim_count(farm) < capacity:
			return true
	return false


## Claims the first eligible Farm (see has_collectible()) for `villager`,
## returning it — null if none are eligible any more (defensive; callers
## should already have checked has_collectible()).
func claim_farm(villager: Villager, farms: Array[Farm]) -> Farm:
	for farm in farms:
		if farm.stage == Farm.FARM_READY_TO_HARVEST and _claim_count(farm) < capacity:
			if not _claims_by_farm.has(farm):
				_claims_by_farm[farm] = []
			_claims_by_farm[farm].append(villager)
			_claimed_farm_by_villager[villager] = farm
			return farm
	return null


func _claim_count(farm: Farm) -> int:
	return _claims_by_farm.get(farm, []).size()


## The Farm `villager` currently holds a claim on, null if none.
func farm_for(villager: Villager) -> Farm:
	return _claimed_farm_by_villager.get(villager)


func is_carrying(villager: Villager) -> bool:
	return _carrying.get(villager, 0) > 0


## Harvests up to carry_capacity from villager's claimed Farm and remembers
## the amount for the follow-up Deliver Task. Returns the amount taken (0
## if villager holds no claim). A non-positive take (e.g. carry_capacity
## misconfigured to <= 0) releases the claim immediately instead of
## leaving the Farm stuck claimed with nothing to ever deliver.
func resolve_collect(villager: Villager) -> int:
	var farm: Farm = _claimed_farm_by_villager.get(villager)
	if farm == null:
		return 0
	var taken := farm.harvest(carry_capacity)
	if taken <= 0:
		release_claim(villager)
		return 0
	_carrying[villager] = taken
	return taken


## Returns and clears the amount `villager` is carrying (0 if none).
func take_carrying(villager: Villager) -> int:
	var amount: int = _carrying.get(villager, 0)
	_carrying.erase(villager)
	return amount


## Releases villager's own claim slot (if any), leaving any other Villager
## concurrently claiming the same Farm untouched, and drops any uncarried/
## undelivered amount — called both on a normal Deliver resolution and on
## interruption (see issue #33: "released once they finish delivering or
## are interrupted"). Only clears this collaborator's own bookkeeping —
## whether an interruption turns the dropped amount into a recoverable
## Known Territory entry is VillageTasks.interrupt_task()'s concern (issue
## #37), not this method's; it just no-op-safely forgets the amount
## either way, same as before.
func release_claim(villager: Villager) -> void:
	var farm: Farm = _claimed_farm_by_villager.get(villager)
	if farm != null and _claims_by_farm.has(farm):
		_claims_by_farm[farm].erase(villager)
		if _claims_by_farm[farm].is_empty():
			_claims_by_farm.erase(farm)
	_claimed_farm_by_villager.erase(villager)
	_carrying.erase(villager)
