extends GutTest
## Tests for Farm claim + fetch-leg state for the Water Task (systems/
## village_farm_watering.gd), driven directly since it's a plain
## collaborator, not itself a TaskProvider — mirrors
## test_village_farm_seeding.gd's conventions.


func test_defaults_water_dose_amount_to_one() -> void:
	var watering := VillageFarmWatering.new()

	assert_eq(watering.water_dose_amount, 1.0)


# --- has_waterable()/claim_farm() ---


func test_has_waterable_is_false_with_no_farms() -> void:
	var watering := VillageFarmWatering.new()

	assert_false(watering.has_waterable([]))


func test_has_waterable_is_false_for_an_awaiting_planting_farm() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()

	assert_false(watering.has_waterable([farm]))


func test_has_waterable_is_true_for_an_unclaimed_seeded_farm() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()
	farm.plant()

	assert_true(watering.has_waterable([farm]))


func test_has_waterable_is_true_for_an_unclaimed_growing_farm() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new(Vector3.ZERO, 5.0, 20)
	farm.plant()
	farm.water(1.0)  # -> Growing, still below the threshold.

	assert_true(watering.has_waterable([farm]))


func test_has_waterable_is_false_for_a_ready_to_harvest_farm() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new(Vector3.ZERO, 1.0, 20)
	farm.plant()
	farm.water(1.0)  # -> Ready-to-Harvest.

	assert_false(watering.has_waterable([farm]))


func test_has_waterable_is_false_once_the_only_waterable_farm_is_claimed() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()
	farm.plant()
	var villager_a := Villager.new("v1", true, "")
	watering.claim_farm(villager_a, [farm])

	assert_false(watering.has_waterable([farm]))


func test_claim_farm_returns_and_binds_the_first_eligible_farm() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new(Vector3(3, 0, 4))
	farm.plant()
	var villager := Villager.new("v1", true, "")

	var claimed := watering.claim_farm(villager, [farm])

	assert_same(claimed, farm)
	assert_same(watering.farm_for(villager), farm)


func test_claim_farm_starts_the_claim_on_the_fetch_leg() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()
	farm.plant()
	var villager := Villager.new("v1", true, "")

	watering.claim_farm(villager, [farm])

	assert_false(watering.has_collected_water(villager))


func test_claim_farm_skips_a_farm_already_claimed_by_someone_else() -> void:
	var watering := VillageFarmWatering.new()
	var claimed_farm := Farm.new(Vector3.ZERO)
	claimed_farm.plant()
	var free_farm := Farm.new(Vector3.ONE)
	free_farm.plant()
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	watering.claim_farm(villager_a, [claimed_farm])

	var claimed := watering.claim_farm(villager_b, [claimed_farm, free_farm])

	assert_same(claimed, free_farm)


func test_claim_farm_skips_a_farm_that_is_not_waterable() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()  # still Awaiting-Planting.
	var villager := Villager.new("v1", true, "")

	var claimed := watering.claim_farm(villager, [farm])

	assert_null(claimed)


func test_claim_farm_returns_null_when_nothing_is_eligible() -> void:
	var watering := VillageFarmWatering.new()
	var villager := Villager.new("v1", true, "")

	var claimed := watering.claim_farm(villager, [])

	assert_null(claimed)


func test_farm_for_is_null_for_a_villager_with_no_claim() -> void:
	var watering := VillageFarmWatering.new()
	var villager := Villager.new("v1", true, "")

	assert_null(watering.farm_for(villager))


# --- has_collected_water()/mark_collected_water() ---


func test_has_collected_water_is_false_for_a_villager_with_no_claim() -> void:
	var watering := VillageFarmWatering.new()
	var villager := Villager.new("v1", true, "")

	assert_false(watering.has_collected_water(villager))


func test_mark_collected_water_flips_has_collected_water_for_the_claim_holder() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()
	farm.plant()
	var villager := Villager.new("v1", true, "")
	watering.claim_farm(villager, [farm])

	watering.mark_collected_water(villager)

	assert_true(watering.has_collected_water(villager))


func test_mark_collected_water_is_a_no_op_for_a_villager_with_no_claim() -> void:
	var watering := VillageFarmWatering.new()
	var villager := Villager.new("v1", true, "")

	watering.mark_collected_water(villager)  # should not error.

	assert_false(watering.has_collected_water(villager))


# --- resolve_water() ---


func test_resolve_water_deposits_the_dose_and_releases_the_claim() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new(Vector3.ZERO, 5.0, 20)
	farm.plant()
	var villager := Villager.new("v1", true, "")
	watering.claim_farm(villager, [farm])
	watering.mark_collected_water(villager)

	watering.resolve_water(villager)

	assert_eq(farm.stage, Farm.FARM_GROWING)
	assert_eq(farm.water_progress, watering.water_dose_amount)
	assert_null(watering.farm_for(villager))
	assert_true(watering.has_waterable([farm]))  # unclaimed again, still below threshold.


func test_resolve_water_uses_the_tuned_dose_amount() -> void:
	var watering := VillageFarmWatering.new()
	watering.water_dose_amount = 2.5
	var farm := Farm.new(Vector3.ZERO, 5.0, 20)
	farm.plant()
	var villager := Villager.new("v1", true, "")
	watering.claim_farm(villager, [farm])

	watering.resolve_water(villager)

	assert_eq(farm.water_progress, 2.5)


func test_resolve_water_is_a_no_op_for_a_villager_with_no_claim() -> void:
	var watering := VillageFarmWatering.new()
	var villager := Villager.new("v1", true, "")

	watering.resolve_water(villager)  # should not error.

	assert_null(watering.farm_for(villager))


# --- release_claim() ---


func test_release_claim_frees_the_farm_for_a_new_claimant() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()
	farm.plant()
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")
	watering.claim_farm(villager_a, [farm])

	watering.release_claim(villager_a)

	assert_null(watering.farm_for(villager_a))
	assert_true(watering.has_waterable([farm]))
	var claimed := watering.claim_farm(villager_b, [farm])
	assert_same(claimed, farm)


func test_release_claim_leaves_the_farms_water_progress_untouched() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new(Vector3.ZERO, 5.0, 20)
	farm.plant()
	farm.water(1.0)
	var villager := Villager.new("v1", true, "")
	watering.claim_farm(villager, [farm])

	watering.release_claim(villager)

	assert_eq(farm.water_progress, 1.0)


func test_release_claim_clears_the_collected_water_flag() -> void:
	var watering := VillageFarmWatering.new()
	var farm := Farm.new()
	farm.plant()
	var villager := Villager.new("v1", true, "")
	watering.claim_farm(villager, [farm])
	watering.mark_collected_water(villager)

	watering.release_claim(villager)

	assert_false(watering.has_collected_water(villager))


func test_release_claim_is_a_no_op_for_a_villager_with_no_claim() -> void:
	var watering := VillageFarmWatering.new()
	var villager := Villager.new("v1", true, "")

	watering.release_claim(villager)  # should not error.

	assert_null(watering.farm_for(villager))
