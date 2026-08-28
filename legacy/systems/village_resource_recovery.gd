class_name VillageResourceRecovery
extends RefCounted
## Claim + carry state for the Recover Task (issue #37) -- the Collect-
## equivalent half of the recoverable-cargo pipeline, claiming a Village's
## known_resources LocationResource entries instead of a Farm. Sibling to
## systems/village_farm_labor.gd/village_farm_seeding.gd/
## village_farm_watering.gd, not folded into any of them -- a
## LocationResource is transient (removed once drained, see
## resolve_recover()) where a Farm is a permanent, re-seeding plot, and a
## Recover Task isn't gated behind Villager.is_farmer the way Seed/Water/
## Collect are (issue #39): recovering a known resource is generic work,
## not farming -- see issue #37's "any Villager can be offered ... it".
##
## A LocationResource is claimed by at most one Villager at a time, from
## the moment a Recover Task is assigned until that Villager either
## resolves it or is interrupted -- mirrors VillageFarmSeeding/
## VillageFarmWatering's single-claim lifecycle, not VillageFarmLabor's
## multi-claimant capacity: no acceptance criteria calls for concurrent
## recovery, so the simpler shape is all this needs.

const DEFAULT_CARRY_CAPACITY: int = 5

## How much a single Villager recovers per Recover Task, tunable, same
## spirit as VillageFarmLabor.carry_capacity.
var carry_capacity: int = DEFAULT_CARRY_CAPACITY

var _claims_by_entry: Dictionary = {}  # LocationResource -> Villager
var _claimed_entry_by_villager: Dictionary = {}  # Villager -> LocationResource
var _carrying: Dictionary = {}  # Villager -> int amount pending delivery


## Pure query -- true if any known_resources entry isn't already claimed.
func has_recoverable(known_resources: Array[LocationResource]) -> bool:
	for entry in known_resources:
		if entry.amount > 0 and not _claims_by_entry.has(entry):
			return true
	return false


## Claims the first eligible entry (see has_recoverable()) for `villager`,
## returning it -- null if none are eligible any more (defensive; callers
## should already have checked has_recoverable()).
func claim_entry(villager: Villager, known_resources: Array[LocationResource]) -> LocationResource:
	for entry in known_resources:
		if entry.amount > 0 and not _claims_by_entry.has(entry):
			_claims_by_entry[entry] = villager
			_claimed_entry_by_villager[villager] = entry
			return entry
	return null


## The LocationResource `villager` currently holds a Recover claim on,
## null if none.
func entry_for(villager: Villager) -> LocationResource:
	return _claimed_entry_by_villager.get(villager)


func is_carrying(villager: Villager) -> bool:
	return _carrying.get(villager, 0) > 0


## Drains up to carry_capacity from villager's claimed entry, marks the
## amount taken for the follow-up Deliver Task, removes the entry from
## known_resources once fully drained (issue #37's acceptance criteria),
## and releases the claim -- no follow-up leg needs it held, unlike
## VillageFarmLabor's Collect (see the class doc comment above). Returns
## the amount taken (0 if villager holds no claim).
func resolve_recover(villager: Villager, known_resources: Array[LocationResource]) -> int:
	var entry: LocationResource = _claimed_entry_by_villager.get(villager)
	if entry == null:
		return 0
	var taken := entry.collect(carry_capacity)
	release_claim(villager)
	if taken <= 0:
		return 0
	_carrying[villager] = taken
	if entry.amount <= 0:
		known_resources.erase(entry)
	return taken


## Returns and clears the amount `villager` is carrying (0 if none).
func take_carrying(villager: Villager) -> int:
	var amount: int = _carrying.get(villager, 0)
	_carrying.erase(villager)
	return amount


## Releases villager's claim (if any) and drops any uncarried amount --
## called both on a normal Recover resolution and on interruption, same
## shape as VillageFarmLabor.release_claim(). Leaves known_resources
## itself untouched -- an interrupted claim's entry stays exactly as it
## was, free for a fresh claimant.
func release_claim(villager: Villager) -> void:
	var entry: LocationResource = _claimed_entry_by_villager.get(villager)
	if entry != null:
		_claims_by_entry.erase(entry)
	_claimed_entry_by_villager.erase(villager)
	_carrying.erase(villager)
