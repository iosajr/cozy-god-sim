class_name VillageFarmWatering
extends RefCounted
## Farm claim + fetch-leg state for the Water Task (issue #38) — the
## manual-watering half of Farm Labor, sibling to systems/
## village_farm_seeding.gd (Seed claim state) and village_farm_labor.gd
## (Collect/Deliver claim+carry state). Rain-driven watering stays on
## systems/village_farms.gd, untouched by this file — Farm.water() is
## agnostic about which caller reached it.
##
## A Farm is claimed by at most one Villager at a time, from the moment a
## Water Task is assigned until that Villager either deposits its dose or
## is interrupted — mirrors VillageFarmSeeding's claim lifecycle. Unlike
## Seed/Collect's single-visit resolve, a Water Task is a fetch-then-
## deposit round trip: a claimed Villager visits the water source first,
## then the claimed Farm — has_collected_water()/mark_collected_water()
## track which leg a claim is currently on.

const DEFAULT_WATER_DOSE_AMOUNT: float = 1.0

## Fixed amount deposited per Water Task visit — tunable, matching
## VillageFarmLabor.carry_capacity's pattern.
var water_dose_amount: float = DEFAULT_WATER_DOSE_AMOUNT

var _claims_by_farm: Dictionary = {}  # Farm -> Villager
var _claimed_farm_by_villager: Dictionary = {}  # Villager -> Farm
var _collected_water_by_villager: Dictionary = {}  # Villager -> bool


## Pure query — true if any Farm is planted but below its growth
## threshold (Seeded or Growing) and not already claimed by another
## Villager. Excludes Awaiting-Planting (needs a Seed Task first, issue
## #36) and Ready-to-Harvest (nothing left to water).
func has_waterable(farms: Array[Farm]) -> bool:
	for farm in farms:
		if _is_waterable_stage(farm.stage) and not _claims_by_farm.has(farm):
			return true
	return false


## Claims the first eligible Farm (see has_waterable()) for `villager`,
## returning it — null if none are eligible any more (defensive; callers
## should already have checked has_waterable()).
func claim_farm(villager: Villager, farms: Array[Farm]) -> Farm:
	for farm in farms:
		if _is_waterable_stage(farm.stage) and not _claims_by_farm.has(farm):
			_claims_by_farm[farm] = villager
			_claimed_farm_by_villager[villager] = farm
			_collected_water_by_villager[villager] = false
			return farm
	return null


## The Farm `villager` currently holds a Water claim on, null if none.
func farm_for(villager: Villager) -> Farm:
	return _claimed_farm_by_villager.get(villager)


## True once villager has visited the water source for their current
## claim — false before that, and once no claim is held at all.
func has_collected_water(villager: Villager) -> bool:
	return _collected_water_by_villager.get(villager, false)


## Marks the fetch leg done, so the next task_destination() query sends
## villager on to the claimed Farm instead of the water source. A no-op
## for a villager with no claim.
func mark_collected_water(villager: Villager) -> void:
	if _claimed_farm_by_villager.has(villager):
		_collected_water_by_villager[villager] = true


## Deposits one dose on villager's claimed Farm and releases the claim.
## A no-op if villager holds no claim.
func resolve_water(villager: Villager) -> void:
	var farm: Farm = _claimed_farm_by_villager.get(villager)
	if farm == null:
		return
	farm.water(water_dose_amount)
	release_claim(villager)


## Releases villager's claim (if any) — called both on a normal Water
## resolution and on interruption. Leaves the Farm itself untouched
## (whatever water_progress it already had stays), unlike
## VillageFarmLabor's release, which also drops carried cargo — there's
## nothing carried here.
func release_claim(villager: Villager) -> void:
	var farm: Farm = _claimed_farm_by_villager.get(villager)
	if farm != null:
		_claims_by_farm.erase(farm)
	_claimed_farm_by_villager.erase(villager)
	_collected_water_by_villager.erase(villager)


func _is_waterable_stage(stage: String) -> bool:
	return stage == Farm.FARM_SEEDED or stage == Farm.FARM_GROWING
