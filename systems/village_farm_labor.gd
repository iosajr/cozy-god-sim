class_name VillageFarmLabor
extends RefCounted
## Farm-work claim/carry state for a Village's Villagers — the Collect/
## Deliver half of Task-based Farm Labor (issue #33). Watering (rain-driven
## Farm growth) is a separate concern, still owned by systems/
## village_farms.gd; this file only covers the harvest-and-deliver side.
##
## A Farm is claimed by at most one Villager at a time, from the moment a
## Collect Task is assigned until that Villager either finishes delivering
## or is interrupted — see VillageTasks.interrupt_task()/begin_resolving_task().

## How much a single Villager harvests per Collect Task, tunable (matches
## the old standalone delivery walker's default carry_capacity).
var carry_capacity: int = 5

var _claims_by_farm: Dictionary = {}  # Farm -> Villager
var _claimed_farm_by_villager: Dictionary = {}  # Villager -> Farm
var _carrying: Dictionary = {}  # Villager -> int amount pending delivery


## Pure query — true if any Farm is Ready-to-Harvest and not already
## claimed by another Villager.
func has_collectible(farms: Array[Farm]) -> bool:
	for farm in farms:
		if farm.stage == Farm.FARM_READY_TO_HARVEST and not _claims_by_farm.has(farm):
			return true
	return false


## Claims the first eligible Farm (see has_collectible()) for `villager`,
## returning it — null if none are eligible any more (defensive; callers
## should already have checked has_collectible()).
func claim_farm(villager: Villager, farms: Array[Farm]) -> Farm:
	for farm in farms:
		if farm.stage == Farm.FARM_READY_TO_HARVEST and not _claims_by_farm.has(farm):
			_claims_by_farm[farm] = villager
			_claimed_farm_by_villager[villager] = farm
			return farm
	return null


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


## Releases villager's claim (if any) and drops any uncarried/undelivered
## amount — called both on a normal Deliver resolution and on interruption
## (see issue #33: "released once they finish delivering or are
## interrupted"). Dropped cargo simply vanishing is a known, temporary
## simplification — see docs/systems-overview.md's Farm Labor section.
func release_claim(villager: Villager) -> void:
	var farm: Farm = _claimed_farm_by_villager.get(villager)
	if farm != null:
		_claims_by_farm.erase(farm)
	_claimed_farm_by_villager.erase(villager)
	_carrying.erase(villager)
