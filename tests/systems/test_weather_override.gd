extends GutTest
## Tests for systems/weather_override.gd (issue #58): the plain-data record
## of one God-forced weather interval, and its pure covers() check. Same
## Seam 1 conventions as test_weather_query.gd -- direct construction, no
## scene tree.


func test_covers_is_true_at_the_exact_center_and_time() -> void:
	var override := WeatherOverride.new(Vector3(10.0, 0.0, 10.0), 5.0, WeatherQuery.CATEGORY_STORM, 100.0, 200.0)

	assert_true(override.covers(Vector3(10.0, 0.0, 10.0), 150.0))


func test_covers_is_true_within_the_radius() -> void:
	var override := WeatherOverride.new(Vector3.ZERO, 10.0, WeatherQuery.CATEGORY_RAIN, 0.0, 10.0)

	assert_true(override.covers(Vector3(6.0, 0.0, 6.0), 5.0))  # distance ~8.49 <= 10.0


func test_covers_is_false_outside_the_radius() -> void:
	var override := WeatherOverride.new(Vector3.ZERO, 5.0, WeatherQuery.CATEGORY_RAIN, 0.0, 10.0)

	assert_false(override.covers(Vector3(100.0, 0.0, 0.0), 5.0))


func test_covers_is_true_at_the_interval_boundaries_inclusive() -> void:
	var override := WeatherOverride.new(Vector3.ZERO, 5.0, WeatherQuery.CATEGORY_RAIN, 100.0, 200.0)

	assert_true(override.covers(Vector3.ZERO, 100.0))
	assert_true(override.covers(Vector3.ZERO, 200.0))


func test_covers_is_false_before_the_interval_starts() -> void:
	var override := WeatherOverride.new(Vector3.ZERO, 5.0, WeatherQuery.CATEGORY_RAIN, 100.0, 200.0)

	assert_false(override.covers(Vector3.ZERO, 99.9))


func test_covers_is_false_after_the_interval_ends() -> void:
	var override := WeatherOverride.new(Vector3.ZERO, 5.0, WeatherQuery.CATEGORY_RAIN, 100.0, 200.0)

	assert_false(override.covers(Vector3.ZERO, 200.1))
