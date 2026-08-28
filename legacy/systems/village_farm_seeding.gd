class_name VillageFarmSeeding
extends RefCounted
## Farm claim state for the Seed Task (issue #36) — the "plant an
## Awaiting-Planting Farm" half of Farm Labor, sibling to systems/
## village_farm_labor.gd's Collect/Deliver claim+carry state. Kept as its
## own file rather than folded into VillageFarmLabor: Awaiting-Planting
## and Ready-to-Harvest are mutually exclusive Farm stages with no shared
## per-claim state (no carry_capacity, no delivery leg), and
## VillageFarmLabor's own doc comment already scopes it to "the
## harvest-and-deliver side" only.
##
## A Farm is claimed by at most one Villager at a time, from the moment a
## Seed Task is assigned until that Villager either plants it or is
## interrupted — mirrors VillageFarmLabor's claim lifecycle.

var _claims_by_farm: Dictionary = {}  # Farm -> Villager
var _claimed_farm_by_villager: Dictionary = {}  # Villager -> Farm


## Pure query — true if any Farm is Awaiting-Planting and not already
## claimed by another Villager.
func has_seedable(farms: Array[Farm]) -> bool:
	for farm in farms:
		if farm.stage == Farm.FARM_AWAITING_PLANTING and not _claims_by_farm.has(farm):
			return true
	return false


## Claims the first eligible Farm (see has_seedable()) for `villager`,
## returning it — null if none are eligible any more (defensive; callers
## should already have checked has_seedable()).
func claim_farm(villager: Villager, farms: Array[Farm]) -> Farm:
	for farm in farms:
		if farm.stage == Farm.FARM_AWAITING_PLANTING and not _claims_by_farm.has(farm):
			_claims_by_farm[farm] = villager
			_claimed_farm_by_villager[villager] = farm
			return farm
	return null


## The Farm `villager` currently holds a Seed claim on, null if none.
func farm_for(villager: Villager) -> Farm:
	return _claimed_farm_by_villager.get(villager)


## Plants villager's claimed Farm (see Farm.plant()) and releases the
## claim. A no-op if villager holds no claim.
func resolve_seed(villager: Villager) -> void:
	var farm: Farm = _claimed_farm_by_villager.get(villager)
	if farm == null:
		return
	farm.plant()
	release_claim(villager)


## Releases villager's claim (if any) — called both on a normal Seed
## resolution and on interruption. Leaves the Farm itself untouched
## (still Awaiting-Planting), unlike VillageFarmLabor's release, which
## also drops carried cargo — there's nothing carried here.
func release_claim(villager: Villager) -> void:
	var farm: Farm = _claimed_farm_by_villager.get(villager)
	if farm != null:
		_claims_by_farm.erase(farm)
	_claimed_farm_by_villager.erase(villager)
