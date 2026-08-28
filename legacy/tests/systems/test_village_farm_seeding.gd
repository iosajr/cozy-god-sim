extends GutTest
## Tests for Farm claim state for the Seed Task (systems/
## village_farm_seeding.gd), driven directly since it's a plain
## collaborator, not itself a TaskProvider — mirrors
## test_village_farm_labor.gd's conventions.


# --- has_seedable()/claim_farm() ---


func test_has_seedable_is_false_with_no_farms() -> void:
	var seeding := VillageFarmSeeding.new()

	assert_false(seeding.has_seedable([]))


func test_has_seedable_is_false_when_no_farm_is_awaiting_planting() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new()
	farm.plant()

	assert_false(seeding.has_seedable([farm]))


func test_has_seedable_is_true_for_an_unclaimed_awaiting_planting_farm() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new()

	assert_true(seeding.has_seedable([farm]))


func test_has_seedable_is_false_once_the_only_awaiting_planting_farm_is_claimed() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new()
	var villager_a := Villager.new("v1", true, "")
	seeding.claim_farm(villager_a, [farm])

	assert_false(seeding.has_seedable([farm]))


func test_claim_farm_returns_and_binds_the_first_eligible_farm() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new(Vector3(3, 0, 4))
	var villager := Villager.new("v1", true, "")

	var claimed := seeding.claim_farm(villager, [farm])

	assert_same(claimed, farm)
	assert_same(seeding.farm_for(villager), farm)


func test_claim_farm_skips_a_farm_already_claimed_by_someone_else() -> void:
	var seeding := VillageFarmSeeding.new()
	var claimed_farm := Farm.new(Vector3.ZERO)
	var free_farm := Farm.new(Vector3.ONE)
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	seeding.claim_farm(villager_a, [claimed_farm])

	var claimed := seeding.claim_farm(villager_b, [claimed_farm, free_farm])

	assert_same(claimed, free_farm)


func test_claim_farm_skips_a_farm_that_is_not_awaiting_planting() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new()
	farm.plant()
	var villager := Villager.new("v1", true, "")

	var claimed := seeding.claim_farm(villager, [farm])

	assert_null(claimed)


func test_claim_farm_returns_null_when_nothing_is_eligible() -> void:
	var seeding := VillageFarmSeeding.new()
	var villager := Villager.new("v1", true, "")

	var claimed := seeding.claim_farm(villager, [])

	assert_null(claimed)


func test_farm_for_is_null_for_a_villager_with_no_claim() -> void:
	var seeding := VillageFarmSeeding.new()
	var villager := Villager.new("v1", true, "")

	assert_null(seeding.farm_for(villager))


# --- resolve_seed() ---


func test_resolve_seed_plants_the_claimed_farm_and_releases_the_claim() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new()
	var villager := Villager.new("v1", true, "")
	seeding.claim_farm(villager, [farm])

	seeding.resolve_seed(villager)

	assert_eq(farm.stage, Farm.FARM_SEEDED)
	assert_null(seeding.farm_for(villager))
	assert_true(seeding.has_seedable([farm]) == false)


func test_resolve_seed_is_a_no_op_for_a_villager_with_no_claim() -> void:
	var seeding := VillageFarmSeeding.new()
	var villager := Villager.new("v1", true, "")

	seeding.resolve_seed(villager)  # should not error.

	assert_null(seeding.farm_for(villager))


# --- release_claim() ---


func test_release_claim_frees_the_farm_for_a_new_claimant() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new()
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	seeding.claim_farm(villager_a, [farm])

	seeding.release_claim(villager_a)

	assert_null(seeding.farm_for(villager_a))
	assert_true(seeding.has_seedable([farm]))
	var claimed := seeding.claim_farm(villager_b, [farm])
	assert_same(claimed, farm)


func test_release_claim_leaves_the_farm_untouched() -> void:
	var seeding := VillageFarmSeeding.new()
	var farm := Farm.new()
	var villager := Villager.new("v1", true, "")
	seeding.claim_farm(villager, [farm])

	seeding.release_claim(villager)

	assert_eq(farm.stage, Farm.FARM_AWAITING_PLANTING)


func test_release_claim_is_a_no_op_for_a_villager_with_no_claim() -> void:
	var seeding := VillageFarmSeeding.new()
	var villager := Villager.new("v1", true, "")

	seeding.release_claim(villager)  # should not error.

	assert_null(seeding.farm_for(villager))
