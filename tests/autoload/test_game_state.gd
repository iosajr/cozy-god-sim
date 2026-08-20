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
