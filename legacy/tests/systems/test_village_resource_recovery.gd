extends GutTest
## Tests for Known Territory resource-entry claim/carry state (systems/
## village_resource_recovery.gd), driven directly since it's a plain
## collaborator, not itself a TaskProvider — mirrors
## test_village_farm_labor.gd's conventions.


func test_defaults_carry_capacity_to_five() -> void:
	var recovery := VillageResourceRecovery.new()

	assert_eq(recovery.carry_capacity, 5)


# --- has_recoverable()/claim_entry() ---


func test_has_recoverable_is_false_with_no_entries() -> void:
	var recovery := VillageResourceRecovery.new()

	assert_false(recovery.has_recoverable([]))


func test_has_recoverable_is_true_for_an_unclaimed_entry() -> void:
	var recovery := VillageResourceRecovery.new()
	var entry := LocationResource.new(Vector3.ZERO, 5)

	assert_true(recovery.has_recoverable([entry]))


func test_has_recoverable_is_false_once_the_only_entry_is_claimed() -> void:
	var recovery := VillageResourceRecovery.new()
	var entry := LocationResource.new(Vector3.ZERO, 5)
	var villager := Villager.new("v1", true, "")
	recovery.claim_entry(villager, [entry])

	assert_false(recovery.has_recoverable([entry]))


func test_claim_entry_returns_and_binds_the_first_eligible_entry() -> void:
	var recovery := VillageResourceRecovery.new()
	var entry := LocationResource.new(Vector3(3, 0, 4), 5)
	var villager := Villager.new("v1", true, "")

	var claimed := recovery.claim_entry(villager, [entry])

	assert_same(claimed, entry)
	assert_same(recovery.entry_for(villager), entry)


func test_claim_entry_skips_an_already_claimed_entry() -> void:
	var recovery := VillageResourceRecovery.new()
	var claimed_entry := LocationResource.new(Vector3.ZERO, 5)
	var free_entry := LocationResource.new(Vector3.ONE, 5)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	recovery.claim_entry(villager_a, [claimed_entry])

	var claimed := recovery.claim_entry(villager_b, [claimed_entry, free_entry])

	assert_same(claimed, free_entry)


func test_claim_entry_returns_null_when_nothing_is_eligible() -> void:
	var recovery := VillageResourceRecovery.new()
	var villager := Villager.new("v1", true, "")

	var claimed := recovery.claim_entry(villager, [])

	assert_null(claimed)


func test_entry_for_is_null_for_a_villager_with_no_claim() -> void:
	var recovery := VillageResourceRecovery.new()
	var villager := Villager.new("v1", true, "")

	assert_null(recovery.entry_for(villager))


# --- resolve_recover()/is_carrying()/take_carrying() ---


func test_resolve_recover_takes_up_to_carry_capacity_and_marks_carrying() -> void:
	var recovery := VillageResourceRecovery.new()
	recovery.carry_capacity = 5
	var entry := LocationResource.new(Vector3.ZERO, 20)
	var villager := Villager.new("v1", true, "")
	recovery.claim_entry(villager, [entry])

	var taken := recovery.resolve_recover(villager, [entry])

	assert_eq(taken, 5)
	assert_eq(entry.amount, 15)
	assert_true(recovery.is_carrying(villager))


func test_resolve_recover_caps_at_whatever_the_entry_has_left() -> void:
	var recovery := VillageResourceRecovery.new()
	recovery.carry_capacity = 5
	var entry := LocationResource.new(Vector3.ZERO, 3)
	var villager := Villager.new("v1", true, "")
	recovery.claim_entry(villager, [entry])

	var taken := recovery.resolve_recover(villager, [entry])

	assert_eq(taken, 3)
	assert_eq(entry.amount, 0)


func test_resolve_recover_removes_the_entry_once_fully_drained() -> void:
	var recovery := VillageResourceRecovery.new()
	recovery.carry_capacity = 5
	var entry := LocationResource.new(Vector3.ZERO, 5)
	var villager := Villager.new("v1", true, "")
	var known_resources: Array[LocationResource] = [entry]
	recovery.claim_entry(villager, known_resources)

	recovery.resolve_recover(villager, known_resources)

	assert_false(entry in known_resources)


func test_resolve_recover_keeps_a_partially_drained_entry_in_place() -> void:
	var recovery := VillageResourceRecovery.new()
	recovery.carry_capacity = 5
	var entry := LocationResource.new(Vector3.ZERO, 20)
	var villager := Villager.new("v1", true, "")
	var known_resources: Array[LocationResource] = [entry]
	recovery.claim_entry(villager, known_resources)

	recovery.resolve_recover(villager, known_resources)

	assert_true(entry in known_resources)


func test_resolve_recover_releases_the_claim_so_the_entry_is_reclaimable() -> void:
	var recovery := VillageResourceRecovery.new()
	recovery.carry_capacity = 5
	var entry := LocationResource.new(Vector3.ZERO, 20)
	var villager_a := Villager.new("v1", true, "")
	var known_resources: Array[LocationResource] = [entry]
	recovery.claim_entry(villager_a, known_resources)
	recovery.resolve_recover(villager_a, known_resources)

	assert_null(recovery.entry_for(villager_a))
	var villager_b := Villager.new("v2", true, "")
	var claimed := recovery.claim_entry(villager_b, known_resources)
	assert_same(claimed, entry)


func test_resolve_recover_returns_zero_for_a_villager_with_no_claim() -> void:
	var recovery := VillageResourceRecovery.new()
	var villager := Villager.new("v1", true, "")

	var taken := recovery.resolve_recover(villager, [])

	assert_eq(taken, 0)
	assert_false(recovery.is_carrying(villager))


func test_is_carrying_is_false_before_a_recover_resolves() -> void:
	var recovery := VillageResourceRecovery.new()
	var villager := Villager.new("v1", true, "")

	assert_false(recovery.is_carrying(villager))


func test_take_carrying_returns_and_clears_the_amount() -> void:
	var recovery := VillageResourceRecovery.new()
	var entry := LocationResource.new(Vector3.ZERO, 20)
	var villager := Villager.new("v1", true, "")
	var known_resources: Array[LocationResource] = [entry]
	recovery.claim_entry(villager, known_resources)
	recovery.resolve_recover(villager, known_resources)

	var taken := recovery.take_carrying(villager)

	assert_eq(taken, 5)
	assert_false(recovery.is_carrying(villager))
	assert_eq(recovery.take_carrying(villager), 0)


# --- release_claim() ---


func test_release_claim_frees_the_entry_for_a_new_claimant() -> void:
	var recovery := VillageResourceRecovery.new()
	var entry := LocationResource.new(Vector3.ZERO, 5)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	recovery.claim_entry(villager_a, [entry])

	recovery.release_claim(villager_a)

	assert_null(recovery.entry_for(villager_a))
	var claimed := recovery.claim_entry(villager_b, [entry])
	assert_same(claimed, entry)


func test_release_claim_also_drops_any_carried_amount() -> void:
	var recovery := VillageResourceRecovery.new()
	var entry := LocationResource.new(Vector3.ZERO, 20)
	var villager := Villager.new("v1", true, "")
	var known_resources: Array[LocationResource] = [entry]
	recovery.claim_entry(villager, known_resources)
	recovery.resolve_recover(villager, known_resources)

	recovery.release_claim(villager)

	assert_false(recovery.is_carrying(villager))


func test_release_claim_leaves_the_entry_untouched_in_known_resources() -> void:
	var recovery := VillageResourceRecovery.new()
	var entry := LocationResource.new(Vector3.ZERO, 5)
	var villager := Villager.new("v1", true, "")
	var known_resources: Array[LocationResource] = [entry]
	recovery.claim_entry(villager, known_resources)

	recovery.release_claim(villager)

	assert_true(entry in known_resources)
	assert_eq(entry.amount, 5)


func test_release_claim_is_a_no_op_for_a_villager_with_no_claim() -> void:
	var recovery := VillageResourceRecovery.new()
	var villager := Villager.new("v1", true, "")

	recovery.release_claim(villager)  # should not error.

	assert_null(recovery.entry_for(villager))
