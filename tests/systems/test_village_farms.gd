extends GutTest
## Tests for weather-driven Farm watering (systems/village_farms.gd, issue
## #59), driven through Village's public methods. Farms are planted
## immediately after construction -- these tests cover watering, not the
## Seed Task itself (see test_farm.gd/test_village_tasks.gd's Farm Labor
## section for that).
##
## Real (position, absolute_time) pairs below are ones already confirmed
## (by direct probing of WeatherQuery.category_at) to answer clear/
## overcast/rain/storm -- see systems/weather_query.gd; this file doesn't
## reimplement or reverse-engineer its noise function, just borrows fixed
## inputs known to land in each category.

const CLEAR_POSITION := Vector3.ZERO
const CLEAR_TIME: float = 686.0
const OVERCAST_POSITION := Vector3.ZERO
const OVERCAST_TIME: float = 8.0
const RAIN_POSITION := Vector3.ZERO
const RAIN_TIME: float = 386.0
const STORM_POSITION := Vector3(2460.0, 0.0, 0.0)
const STORM_TIME: float = 1990.0

## A position that answers clear at RAIN_TIME specifically (distinct from
## CLEAR_POSITION/CLEAR_TIME above), so a test can hold time fixed and
## vary only position across two Farms.
const CLEAR_POSITION_AT_RAIN_TIME := Vector3(6430.0, 0.0, 0.0)


# -- should_water_from_weather(): pure decision, no scene tree needed --

func test_should_water_from_weather_is_true_for_rain_on_a_seeded_farm() -> void:
	var farm := Farm.new()
	farm.plant()
	assert_true(VillageFarms.should_water_from_weather(WeatherQuery.CATEGORY_RAIN, farm))


func test_should_water_from_weather_is_true_for_storm_on_a_growing_farm() -> void:
	var farm := Farm.new()
	farm.plant()
	farm.water(0.1)  # nudges it from Seeded into Growing
	assert_true(VillageFarms.should_water_from_weather(WeatherQuery.CATEGORY_STORM, farm))


func test_should_water_from_weather_is_false_for_clear() -> void:
	var farm := Farm.new()
	farm.plant()
	assert_false(VillageFarms.should_water_from_weather(WeatherQuery.CATEGORY_CLEAR, farm))


func test_should_water_from_weather_is_false_for_overcast() -> void:
	var farm := Farm.new()
	farm.plant()
	assert_false(VillageFarms.should_water_from_weather(WeatherQuery.CATEGORY_OVERCAST, farm))


func test_should_water_from_weather_is_false_for_rain_on_an_awaiting_planting_farm() -> void:
	var farm := Farm.new()  # never planted
	assert_false(VillageFarms.should_water_from_weather(WeatherQuery.CATEGORY_RAIN, farm))


func test_should_water_from_weather_is_false_for_storm_on_a_ready_to_harvest_farm() -> void:
	var farm := Farm.new(Vector3.ZERO, 1.0)
	farm.plant()
	farm.water(1.0)  # reaches Ready-to-Harvest with a threshold of 1.0
	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)
	assert_false(VillageFarms.should_water_from_weather(WeatherQuery.CATEGORY_STORM, farm))


# -- advance_farms(): wiring should_water_from_weather() to the real query --

func test_advance_farms_waters_a_farm_where_the_weather_is_raining() -> void:
	var village := Village.new()
	village.rain_water_rate = 1.0
	var farm := Farm.new(RAIN_POSITION)
	farm.plant()
	village.farms.append(farm)

	village.advance_farms(1.0, RAIN_TIME)

	assert_eq(farm.water_progress, 1.0)
	assert_eq(farm.stage, Farm.FARM_GROWING)


func test_advance_farms_waters_a_farm_where_the_weather_is_storming() -> void:
	var village := Village.new()
	village.rain_water_rate = 1.0
	var farm := Farm.new(STORM_POSITION)
	farm.plant()
	village.farms.append(farm)

	village.advance_farms(1.0, STORM_TIME)

	assert_eq(farm.water_progress, 1.0)


func test_advance_farms_does_not_water_a_farm_where_the_weather_is_clear() -> void:
	var village := Village.new()
	village.rain_water_rate = 1.0
	var farm := Farm.new(CLEAR_POSITION)
	farm.plant()
	village.farms.append(farm)

	village.advance_farms(1.0, CLEAR_TIME)

	assert_eq(farm.water_progress, 0.0)
	assert_eq(farm.stage, Farm.FARM_SEEDED)


func test_advance_farms_does_not_water_a_farm_where_the_weather_is_overcast() -> void:
	var village := Village.new()
	village.rain_water_rate = 1.0
	var farm := Farm.new(OVERCAST_POSITION)
	farm.plant()
	village.farms.append(farm)

	village.advance_farms(1.0, OVERCAST_TIME)

	assert_eq(farm.water_progress, 0.0)


func test_advance_farms_does_not_water_an_awaiting_planting_farm_even_when_raining() -> void:
	var village := Village.new()
	village.rain_water_rate = 1.0
	var farm := Farm.new(RAIN_POSITION)  # never planted
	village.farms.append(farm)

	village.advance_farms(1.0, RAIN_TIME)

	assert_eq(farm.stage, Farm.FARM_AWAITING_PLANTING)
	assert_eq(farm.water_progress, 0.0)


func test_advance_farms_does_not_water_a_ready_to_harvest_farm_even_when_raining() -> void:
	var village := Village.new()
	village.rain_water_rate = 1.0
	var farm := Farm.new(RAIN_POSITION, 1.0)
	farm.plant()
	farm.water(1.0)  # reaches Ready-to-Harvest
	village.farms.append(farm)

	village.advance_farms(1.0, RAIN_TIME)

	assert_eq(farm.stage, Farm.FARM_READY_TO_HARVEST)
	assert_eq(farm.water_progress, 1.0)  # unchanged by the weather check


func test_advance_farms_scales_the_dose_by_delta() -> void:
	var village := Village.new()
	village.rain_water_rate = 2.0
	var farm := Farm.new(RAIN_POSITION)
	farm.plant()
	village.farms.append(farm)

	village.advance_farms(0.5, RAIN_TIME)

	assert_eq(farm.water_progress, 1.0)


func test_advance_farms_handles_multiple_farms_independently_by_position() -> void:
	var village := Village.new()
	village.rain_water_rate = 1.0
	var rainy_farm := Farm.new(RAIN_POSITION)
	var clear_farm := Farm.new(CLEAR_POSITION_AT_RAIN_TIME)
	rainy_farm.plant()
	clear_farm.plant()
	village.farms.append(rainy_farm)
	village.farms.append(clear_farm)

	# Same call, same absolute_time -- each Farm's own position decides
	# its own weather independently.
	village.advance_farms(1.0, RAIN_TIME)

	assert_eq(rainy_farm.water_progress, 1.0)
	assert_eq(clear_farm.water_progress, 0.0)
