extends GutTest
## Tests for periodic Farm watering (systems/village_farms.gd, driven
## through Village's public methods).


func test_advance_farms_does_not_water_before_the_countdown_elapses() -> void:
	var village := Village.new()
	village.farm_check_interval_min = 100.0
	village.farm_check_interval_max = 100.0
	village.rain_chance = 1.0
	var farm := Farm.new()
	village.farms.append(farm)

	village.advance_farms(1.0)

	assert_eq(farm.stage, Farm.FARM_SEEDED)
	assert_eq(farm.water_progress, 0.0)


func test_advance_farms_waters_the_farm_once_the_countdown_elapses_and_rain_hits() -> void:
	var village := Village.new()
	village.farm_check_interval_min = 1.0
	village.farm_check_interval_max = 1.0
	village.rain_chance = 1.0
	village.rain_water_amount = 1.0
	var farm := Farm.new()
	village.farms.append(farm)

	village.advance_farms(2.0)

	assert_eq(farm.water_progress, 1.0)
	assert_eq(farm.stage, Farm.FARM_GROWING)


func test_advance_farms_does_not_water_when_rain_chance_misses() -> void:
	var village := Village.new()
	village.farm_check_interval_min = 1.0
	village.farm_check_interval_max = 1.0
	village.rain_chance = 0.0
	var farm := Farm.new()
	village.farms.append(farm)

	village.advance_farms(2.0)

	assert_eq(farm.water_progress, 0.0)
	assert_eq(farm.stage, Farm.FARM_SEEDED)


func test_advance_farms_ticks_down_the_countdown_by_delta() -> void:
	var village := Village.new()
	village.farm_check_interval_min = 10.0
	village.farm_check_interval_max = 10.0
	village.rain_chance = 1.0
	var farm := Farm.new()
	village.farms.append(farm)

	village.advance_farms(4.0)
	assert_eq(farm.water_progress, 0.0)
	village.advance_farms(4.0)
	assert_eq(farm.water_progress, 0.0)
	village.advance_farms(4.0)
	assert_eq(farm.water_progress, 1.0)


func test_advance_farms_handles_multiple_farms_independently() -> void:
	var village := Village.new()
	village.farm_check_interval_min = 1.0
	village.farm_check_interval_max = 1.0
	village.rain_chance = 1.0
	var farm_a := Farm.new()
	var farm_b := Farm.new()
	village.farms.append(farm_a)
	village.farms.append(farm_b)

	village.advance_farms(2.0)

	assert_eq(farm_a.water_progress, 1.0)
	assert_eq(farm_b.water_progress, 1.0)
