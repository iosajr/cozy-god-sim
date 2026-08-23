extends GutTest
## Tests for Farm claim/carry state (systems/village_farm_labor.gd), driven
## directly since it's a plain collaborator, not itself a TaskProvider.


func test_defaults_carry_capacity_to_five() -> void:
	var labor := VillageFarmLabor.new()

	assert_eq(labor.carry_capacity, 5)


func test_defaults_capacity_to_four() -> void:
	var labor := VillageFarmLabor.new()

	assert_eq(labor.capacity, 4)


# --- has_collectible()/claim_farm() ---


func test_has_collectible_is_false_with_no_farms() -> void:
	var labor := VillageFarmLabor.new()

	assert_false(labor.has_collectible([]))


func test_has_collectible_is_false_when_no_farm_is_ready_to_harvest() -> void:
	var labor := VillageFarmLabor.new()
	var farm := Farm.new()

	assert_false(labor.has_collectible([farm]))


func test_has_collectible_is_true_for_an_unclaimed_ready_to_harvest_farm() -> void:
	var labor := VillageFarmLabor.new()
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)

	assert_true(labor.has_collectible([farm]))


func test_has_collectible_is_true_while_a_ready_farm_is_still_under_capacity() -> void:
	var labor := VillageFarmLabor.new()
	labor.capacity = 4
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager_a := Villager.new("v1", true, "")
	labor.claim_farm(villager_a, [farm])

	assert_true(labor.has_collectible([farm]))


func test_has_collectible_is_false_once_a_ready_farm_reaches_capacity() -> void:
	var labor := VillageFarmLabor.new()
	labor.capacity = 1
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager_a := Villager.new("v1", true, "")
	labor.claim_farm(villager_a, [farm])

	assert_false(labor.has_collectible([farm]))


func test_claim_farm_returns_and_binds_the_first_eligible_farm() -> void:
	var labor := VillageFarmLabor.new()
	var farm := Farm.new(Vector3(3, 0, 4), 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager := Villager.new("v1", true, "")

	var claimed := labor.claim_farm(villager, [farm])

	assert_same(claimed, farm)
	assert_same(labor.farm_for(villager), farm)


func test_claim_farm_allows_multiple_villagers_on_the_same_farm_up_to_capacity() -> void:
	var labor := VillageFarmLabor.new()
	labor.capacity = 2
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")

	var claimed_a := labor.claim_farm(villager_a, [farm])
	var claimed_b := labor.claim_farm(villager_b, [farm])

	assert_same(claimed_a, farm)
	assert_same(claimed_b, farm)
	assert_same(labor.farm_for(villager_a), farm)
	assert_same(labor.farm_for(villager_b), farm)


func test_claim_farm_skips_a_farm_already_at_capacity() -> void:
	var labor := VillageFarmLabor.new()
	labor.capacity = 1
	var claimed_farm := Farm.new(Vector3.ZERO, 1.0, 20)
	claimed_farm.plant()
	claimed_farm.water(1.0)
	var free_farm := Farm.new(Vector3.ONE, 1.0, 20)
	free_farm.plant()
	free_farm.water(1.0)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	labor.claim_farm(villager_a, [claimed_farm])

	var claimed := labor.claim_farm(villager_b, [claimed_farm, free_farm])

	assert_same(claimed, free_farm)


func test_claim_farm_returns_null_when_nothing_is_eligible() -> void:
	var labor := VillageFarmLabor.new()
	var villager := Villager.new("v1", true, "")

	var claimed := labor.claim_farm(villager, [])

	assert_null(claimed)


func test_farm_for_is_null_for_a_villager_with_no_claim() -> void:
	var labor := VillageFarmLabor.new()
	var villager := Villager.new("v1", true, "")

	assert_null(labor.farm_for(villager))


# --- resolve_collect()/is_carrying()/take_carrying() ---


func test_resolve_collect_harvests_up_to_carry_capacity_and_marks_carrying() -> void:
	var labor := VillageFarmLabor.new()
	labor.carry_capacity = 5
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager := Villager.new("v1", true, "")
	labor.claim_farm(villager, [farm])

	var taken := labor.resolve_collect(villager)

	assert_eq(taken, 5)
	assert_eq(farm.remaining_harvest, 15)
	assert_true(labor.is_carrying(villager))


func test_resolve_collect_releases_the_claim_instead_of_sticking_when_carry_capacity_is_non_positive() -> void:
	var labor := VillageFarmLabor.new()
	labor.carry_capacity = 0
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager := Villager.new("v1", true, "")
	labor.claim_farm(villager, [farm])

	var taken := labor.resolve_collect(villager)

	assert_eq(taken, 0)
	assert_false(labor.is_carrying(villager))
	assert_null(labor.farm_for(villager))
	assert_true(labor.has_collectible([farm]))


func test_resolve_collect_lets_concurrent_claimants_each_independently_drain_the_shared_pool() -> void:
	var labor := VillageFarmLabor.new()
	labor.capacity = 2
	labor.carry_capacity = 5
	var farm := Farm.new(Vector3.ZERO, 1.0, 8)
	farm.plant()
	farm.water(1.0)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	labor.claim_farm(villager_a, [farm])
	labor.claim_farm(villager_b, [farm])

	var taken_a := labor.resolve_collect(villager_a)
	var taken_b := labor.resolve_collect(villager_b)

	assert_eq(taken_a, 5)
	assert_eq(taken_b, 3)
	assert_eq(taken_a + taken_b, 8)
	assert_eq(farm.remaining_harvest, 0)
	assert_true(labor.is_carrying(villager_a))
	assert_true(labor.is_carrying(villager_b))


func test_resolve_collect_returns_zero_for_a_villager_with_no_claim() -> void:
	var labor := VillageFarmLabor.new()
	var villager := Villager.new("v1", true, "")

	var taken := labor.resolve_collect(villager)

	assert_eq(taken, 0)
	assert_false(labor.is_carrying(villager))


func test_is_carrying_is_false_before_a_collect_resolves() -> void:
	var labor := VillageFarmLabor.new()
	var villager := Villager.new("v1", true, "")

	assert_false(labor.is_carrying(villager))


func test_take_carrying_returns_and_clears_the_amount() -> void:
	var labor := VillageFarmLabor.new()
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager := Villager.new("v1", true, "")
	labor.claim_farm(villager, [farm])
	labor.resolve_collect(villager)

	var taken := labor.take_carrying(villager)

	assert_eq(taken, 5)
	assert_false(labor.is_carrying(villager))
	assert_eq(labor.take_carrying(villager), 0)


# --- release_claim() ---


func test_release_claim_frees_the_farm_for_a_new_claimant() -> void:
	var labor := VillageFarmLabor.new()
	labor.capacity = 1  # otherwise has_collectible() would stay true regardless.
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	labor.claim_farm(villager_a, [farm])

	labor.release_claim(villager_a)

	assert_null(labor.farm_for(villager_a))
	assert_true(labor.has_collectible([farm]))
	var claimed := labor.claim_farm(villager_b, [farm])
	assert_same(claimed, farm)


func test_release_claim_also_drops_any_carried_amount() -> void:
	var labor := VillageFarmLabor.new()
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager := Villager.new("v1", true, "")
	labor.claim_farm(villager, [farm])
	labor.resolve_collect(villager)

	labor.release_claim(villager)

	assert_false(labor.is_carrying(villager))


func test_release_claim_only_frees_the_releasing_villagers_own_slot() -> void:
	var labor := VillageFarmLabor.new()
	labor.capacity = 2
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	labor.claim_farm(villager_a, [farm])
	labor.claim_farm(villager_b, [farm])
	assert_false(labor.has_collectible([farm]))  # farm is now at capacity

	labor.release_claim(villager_a)

	assert_null(labor.farm_for(villager_a))
	assert_same(labor.farm_for(villager_b), farm)  # villager_b's own claim is untouched
	assert_true(labor.has_collectible([farm]))  # a slot opened back up


func test_release_claim_is_a_no_op_for_a_villager_with_no_claim() -> void:
	var labor := VillageFarmLabor.new()
	var villager := Villager.new("v1", true, "")

	labor.release_claim(villager)  # should not error.

	assert_null(labor.farm_for(villager))
