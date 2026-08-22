extends GutTest
## Tests for systems/farm.gd (issue #15's Farm data slice). No scene tree
## involved — Farm is plain RefCounted data/logic, mirroring
## test_house.gd/test_location.gd's Seam 1 test conventions. Covers the
## full seed -> water -> grow -> ready -> harvest -> re-seed cycle named
## in issue #15's Testing Decisions.


func test_farm_starts_in_the_seeded_stage() -> void:
	var farm := Farm.new()

	assert_eq(farm.stage, Farm.FARM_SEEDED)
	assert_eq(farm.water_progress, 0.0)
	assert_eq(farm.remaining_harvest, 0)


func test_farm_accepts_an_explicit_position() -> void:
	var farm := Farm.new(Vector3(10, 0, -4))

	assert_eq(farm.position, Vector3(10, 0, -4))


func test_water_moves_a_freshly_seeded_farm_to_growing() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0)

	farm.water(1.0)

	assert_eq(farm.stage, Farm.FARM_GROWING)
	assert_eq(farm.water_progress, 1.0)


func test_water_accumulates_across_multiple_calls_without_reaching_threshold() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0)

	farm.water(1.0)
	farm.water(1.0)

	assert_eq(farm.stage, Farm.FARM_GROWING)
	assert_eq(farm.water_progress, 2.0)


func test_water_reaching_the_growth_threshold_advances_to_ready_to_harvest() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)

	farm.water(1.0)
	farm.water(1.0)
	farm.water(1.0)

	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)
	assert_eq(farm.remaining_harvest, 20)


func test_water_overshooting_the_threshold_in_one_call_still_reaches_ready_to_harvest() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)

	farm.water(10.0)

	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)
	assert_eq(farm.remaining_harvest, 20)


func test_water_is_a_no_op_once_already_ready_to_harvest() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)
	farm.water(10.0)
	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)

	farm.water(5.0)

	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)
	assert_eq(farm.water_progress, 10.0)
	assert_eq(farm.remaining_harvest, 20)


func test_harvest_before_ready_to_harvest_returns_zero_and_changes_nothing() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)

	var taken := farm.harvest(5)

	assert_eq(taken, 0)
	assert_eq(farm.stage, Farm.FARM_SEEDED)


func test_harvest_takes_up_to_the_requested_amount() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)
	farm.water(10.0)

	var taken := farm.harvest(5)

	assert_eq(taken, 5)
	assert_eq(farm.remaining_harvest, 15)
	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)


func test_harvest_with_zero_amount_returns_zero_and_does_not_reseed() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)
	farm.water(10.0)

	var taken := farm.harvest(0)

	assert_eq(taken, 0)
	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)
	assert_eq(farm.remaining_harvest, 20)


func test_harvest_with_a_negative_amount_returns_zero_and_does_not_inflate_remaining_harvest() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)
	farm.water(10.0)

	var taken := farm.harvest(-5)

	assert_eq(taken, 0)
	assert_eq(farm.remaining_harvest, 20)


func test_harvest_caps_at_whatever_remains() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)
	farm.water(10.0)
	farm.harvest(15)

	var taken := farm.harvest(100)

	assert_eq(taken, 5)


func test_harvest_draining_remaining_to_zero_reseeds_the_farm() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)
	farm.water(10.0)

	farm.harvest(20)

	assert_eq(farm.stage, Farm.FARM_SEEDED)
	assert_eq(farm.water_progress, 0.0)
	assert_eq(farm.remaining_harvest, 0)


func test_harvest_after_reseeding_returns_zero_until_watered_again() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)
	farm.water(10.0)
	farm.harvest(20)

	var taken := farm.harvest(5)

	assert_eq(taken, 0)


func test_a_full_seed_to_harvest_to_reseed_cycle_can_repeat() -> void:
	var farm := Farm.new(Vector3.ZERO, 3.0, 20)

	farm.water(10.0)
	farm.harvest(20)
	assert_eq(farm.stage, Farm.FARM_SEEDED)

	farm.water(10.0)

	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)
	assert_eq(farm.remaining_harvest, 20)
