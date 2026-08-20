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
