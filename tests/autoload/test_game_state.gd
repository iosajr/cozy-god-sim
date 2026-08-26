extends GutTest
## Tests for autoload/game_state.gd's Village reference (Seam 1 adjacent —
## GameState is a bulletin board, per its own doc comment and CLAUDE.md;
## this only checks it holds the right kind of reference, not any logic).


func test_game_state_exposes_a_village_not_a_population_int() -> void:
	var gs: Node = autofree(preload("res://autoload/game_state.gd").new())

	assert_false("population" in gs, "population: int should be removed per issue #2")

	var demo_village := Village.new()
	gs.village = demo_village
	assert_eq(gs.village, demo_village, "village should hold whatever Village reference is assigned")


func test_game_state_village_defaults_to_an_empty_village_not_null() -> void:
	var gs: Node = autofree(preload("res://autoload/game_state.gd").new())

	assert_not_null(gs.village, "village should never be null — an empty Village, not a missing one")
	assert_true(gs.village is Village)
	assert_eq(gs.village.villagers.size(), 0)


func test_game_state_exposes_a_pantheon_not_null() -> void:
	# issue #3 deferred this on purpose; issue #4 fills it in so
	# village_spawner.gd has something to pass into Village's Wish-linking
	# (see systems/village.gd's resolve_wish()).
	var gs: Node = autofree(preload("res://autoload/game_state.gd").new())

	assert_not_null(gs.pantheon, "pantheon should never be null — a real Pantheon, not a missing one")
	assert_true(gs.pantheon is Pantheon)

	var demo_pantheon := Pantheon.new()
	gs.pantheon = demo_pantheon
	assert_eq(gs.pantheon, demo_pantheon, "pantheon should hold whatever Pantheon reference is assigned")


## issue #55: an absolute, ever-increasing game-time axis alongside the
## existing wrapping time_of_day, so a later system (e.g. issue #57's
## weather query) can ask "what point in absolute game time is it" and get
## a value that keeps growing day over day instead of looping.
func test_absolute_game_time_keeps_increasing_across_day_wraps() -> void:
	var gs: Node = autofree(preload("res://autoload/game_state.gd").new())
	gs.day_speed = 1.0  # 1 in-game hour per real second, easy to reason about

	var previous_absolute: float = gs.absolute_game_time
	# 30 seconds * 1.0 hour/sec = 30 in-game hours -- wraps time_of_day
	# around past 24.0 at least once.
	for _i in range(30):
		gs._process(1.0)
		assert_gt(gs.absolute_game_time, previous_absolute,
			"absolute_game_time should strictly increase every non-paused tick")
		previous_absolute = gs.absolute_game_time

	assert_gt(gs.absolute_game_time, 24.0,
		"absolute_game_time should keep growing past a single day's worth of hours")
	# time_of_day wrapped back down; absolute_game_time did not.
	assert_lt(gs.time_of_day, gs.absolute_game_time,
		"time_of_day should have wrapped while absolute_game_time kept climbing")


func test_absolute_game_time_unaffected_by_time_of_day_wrapping() -> void:
	var gs: Node = autofree(preload("res://autoload/game_state.gd").new())
	gs.day_speed = 1.0
	gs.time_of_day = 23.0

	gs._process(2.0)  # crosses the 24.0 wrap: 23.0 + 2.0 -> fmod to 1.0

	assert_almost_eq(gs.time_of_day, 1.0, 0.001, "time_of_day should still wrap exactly as before")
	assert_almost_eq(gs.absolute_game_time, 8.0 + 2.0, 0.001,
		"absolute_game_time should just keep adding elapsed hours, no wrap")


func test_absolute_game_time_does_not_advance_while_paused() -> void:
	var gs: Node = autofree(preload("res://autoload/game_state.gd").new())
	gs.paused = true
	var starting_absolute: float = gs.absolute_game_time

	gs._process(5.0)

	assert_eq(gs.absolute_game_time, starting_absolute,
		"absolute_game_time should respect the same paused guard as time_of_day")
