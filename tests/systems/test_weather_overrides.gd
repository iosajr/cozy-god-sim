extends GutTest
## Tests for systems/weather_overrides.gd (issue #58): the registered set
## of WeatherOverride intervals that WeatherQuery.category_at() consults.
## Registry is class-level static state (see the doc comment on
## WeatherOverrides) so it must be cleared between tests -- otherwise an
## override registered in one test leaks into the next.


func after_each() -> void:
	WeatherOverrides.clear_all()


func test_category_at_returns_empty_string_with_nothing_registered() -> void:
	assert_eq(WeatherOverrides.category_at(Vector3.ZERO, 0.0), "")


func test_category_at_returns_the_forced_category_inside_the_override() -> void:
	WeatherOverrides.register(Vector3(10.0, 0.0, 10.0), WeatherQuery.CATEGORY_STORM, 100.0, 200.0)

	assert_eq(WeatherOverrides.category_at(Vector3(10.0, 0.0, 10.0), 150.0), WeatherQuery.CATEGORY_STORM)


func test_category_at_returns_empty_string_outside_the_overrides_radius() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 100.0, 200.0, 5.0)

	assert_eq(WeatherOverrides.category_at(Vector3(500.0, 0.0, 0.0), 150.0), "")


func test_category_at_returns_empty_string_before_the_intervals_start() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 100.0, 200.0)

	assert_eq(WeatherOverrides.category_at(Vector3.ZERO, 50.0), "")


func test_category_at_returns_empty_string_after_the_intervals_end() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 100.0, 200.0)

	assert_eq(WeatherOverrides.category_at(Vector3.ZERO, 250.0), "")


func test_register_defaults_to_a_usable_radius() -> void:
	var override := WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_RAIN, 0.0, 10.0)

	assert_gt(override.radius, 0.0)


func test_clear_all_removes_every_registered_override() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 1000.0)

	WeatherOverrides.clear_all()

	assert_eq(WeatherOverrides.category_at(Vector3.ZERO, 500.0), "")


## active_override_at() (issue #60): same lookup as category_at(), but
## returns the covering WeatherOverride object itself so a caller (e.g.
## FolkSpawnerSupport's divine-exposure logging) can dedupe against the
## exact override instance rather than just its category string.
func test_active_override_at_returns_null_with_nothing_registered() -> void:
	assert_null(WeatherOverrides.active_override_at(Vector3.ZERO, 0.0))


func test_active_override_at_returns_the_covering_override_instance() -> void:
	var override := WeatherOverrides.register(Vector3(10.0, 0.0, 10.0), WeatherQuery.CATEGORY_STORM, 100.0, 200.0)

	assert_eq(WeatherOverrides.active_override_at(Vector3(10.0, 0.0, 10.0), 150.0), override)


func test_active_override_at_returns_null_outside_the_overrides_radius() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 100.0, 200.0, 5.0)

	assert_null(WeatherOverrides.active_override_at(Vector3(500.0, 0.0, 0.0), 150.0))
