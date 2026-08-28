extends GutTest
## Tests for systems/weather_query.gd (issue #57's base weather query). Pure
## static function, no scene tree involved -- same Seam 1 conventions as
## test_location.gd/test_farm.gd: query the public interface only, never
## reach into noise internals.


func test_same_position_and_time_always_returns_the_same_category() -> void:
	var position := Vector3(12.0, 0.0, -34.0)
	var absolute_time := 57.5

	var first: String = WeatherQuery.category_at(position, absolute_time)
	var second: String = WeatherQuery.category_at(position, absolute_time)

	assert_eq(first, second)


func test_repeated_calls_with_other_inputs_in_between_do_not_change_the_answer() -> void:
	# Regression coverage for the "no stored state" requirement: a query
	# implemented as a reseed-per-call RNG (or anything else that drifts
	# with call count) would answer this differently depending on what
	# was queried in between. A pure noise/hash function must not.
	var position := Vector3(5.0, 0.0, 5.0)
	var absolute_time := 100.0

	var before: String = WeatherQuery.category_at(position, absolute_time)
	for i in range(25):
		WeatherQuery.category_at(Vector3(i * 3.0, 0.0, -i * 7.0), i * 11.0)
	var after: String = WeatherQuery.category_at(position, absolute_time)

	assert_eq(before, after)


func test_result_is_always_a_known_weather_category() -> void:
	var known: Array[String] = [
		WeatherQuery.CATEGORY_CLEAR,
		WeatherQuery.CATEGORY_OVERCAST,
		WeatherQuery.CATEGORY_RAIN,
		WeatherQuery.CATEGORY_STORM,
	]

	for i in range(20):
		var category: String = WeatherQuery.category_at(Vector3(i * 17.0, 0.0, i * -5.0), i * 9.0)
		assert_true(known.has(category), "unexpected category %s at sample %d" % [category, i])


func test_varies_across_the_absolute_time_axis_for_a_fixed_position() -> void:
	# Not just a repeating within-day cycle: sampling far apart on the
	# time axis (thousands of game-hours apart, well past any daily
	# wraparound) must be able to land in more than one category.
	var position := Vector3(0.0, 0.0, 0.0)
	var seen: Dictionary = {}

	for i in range(50):
		var absolute_time: float = i * 137.0
		seen[WeatherQuery.category_at(position, absolute_time)] = true

	assert_gt(seen.size(), 1, "expected more than one category across a wide spread of absolute_time")


func test_varies_across_position_for_a_fixed_time() -> void:
	var absolute_time := 42.0
	var seen: Dictionary = {}

	for i in range(50):
		var position := Vector3(i * 91.0, 0.0, i * -53.0)
		seen[WeatherQuery.category_at(position, absolute_time)] = true

	assert_gt(seen.size(), 1, "expected more than one category across a wide spread of positions")


func test_answers_a_position_time_pair_nothing_has_actively_simulated() -> void:
	# The whole point of a pure query: an arbitrary, never-before-touched
	# (position, time) pair still gets a real, deterministic answer --
	# not a crash, not null, not a default fallback.
	var position := Vector3(-9123.4, 0.0, 8842.1)
	var absolute_time := 999999.25

	var category: String = WeatherQuery.category_at(position, absolute_time)

	assert_true(category is String and category != "")


# --- Pantheon-forced overrides (issue #58) ---
#
# category_at() is the single entry point callers use; a registered
# WeatherOverrides interval is checked transparently inside it, so any
# caller (including #59's farm-watering hook) gets override-awareness for
# free without changing how it calls this function.


func after_each() -> void:
	WeatherOverrides.clear_all()


func test_category_at_returns_the_forced_state_inside_an_active_override() -> void:
	var position := Vector3(12.0, 0.0, -34.0)
	var absolute_time := 57.5
	var base: String = WeatherQuery.category_at(position, absolute_time)
	var forced := WeatherQuery.CATEGORY_STORM if base != WeatherQuery.CATEGORY_STORM else WeatherQuery.CATEGORY_CLEAR
	WeatherOverrides.register(position, forced, absolute_time - 1.0, absolute_time + 1.0)

	assert_eq(WeatherQuery.category_at(position, absolute_time), forced)


func test_category_at_is_unaffected_by_an_override_at_a_different_position() -> void:
	var position := Vector3(12.0, 0.0, -34.0)
	var absolute_time := 57.5
	var base: String = WeatherQuery.category_at(position, absolute_time)
	WeatherOverrides.register(
		Vector3(9000.0, 0.0, 9000.0), WeatherQuery.CATEGORY_STORM, absolute_time - 1.0, absolute_time + 1.0, 1.0
	)

	assert_eq(WeatherQuery.category_at(position, absolute_time), base)


func test_category_at_is_unaffected_by_an_override_before_or_after_its_interval() -> void:
	var position := Vector3(12.0, 0.0, -34.0)
	var absolute_time := 57.5
	var base: String = WeatherQuery.category_at(position, absolute_time)
	WeatherOverrides.register(position, WeatherQuery.CATEGORY_STORM, absolute_time + 10.0, absolute_time + 20.0)

	assert_eq(WeatherQuery.category_at(position, absolute_time), base)
