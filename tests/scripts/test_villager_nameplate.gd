extends GutTest
## Tests for scripts/villager_nameplate.gd (Seam 2). Only checks that
## displayed text matches input — no assertions on billboard behavior or
## bubble styling, per issue #2's Testing Decisions.


func test_show_thought_sets_displayed_text() -> void:
	var nameplate: Label3D = autofree(VillagerNameplate.new())

	nameplate.show_thought("The bread smells almost ready.")

	assert_eq(nameplate.text, "The bread smells almost ready.")


func test_set_renowned_true_changes_the_nameplate_color() -> void:
	var nameplate: VillagerNameplate = autofree(VillagerNameplate.new())
	var ordinary_color: Color = nameplate.modulate

	nameplate.set_renowned(true)

	assert_ne(nameplate.modulate, ordinary_color)
