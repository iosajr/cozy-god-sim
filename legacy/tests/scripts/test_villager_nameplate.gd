extends GutTest
## Tests for scripts/villager_nameplate.gd (Seam 2). Only checks that
## displayed text matches input — no assertions on billboard behavior or
## bubble styling, per issue #2's Testing Decisions.


func test_show_thought_sets_displayed_text() -> void:
	var nameplate: Label3D = autofree(VillagerNameplate.new())

	nameplate.show_thought("The bread smells almost ready.")

	assert_eq(nameplate.text, "The bread smells almost ready.")


func test_show_baseline_sets_displayed_text_to_name_and_age() -> void:
	var nameplate: VillagerNameplate = autofree(VillagerNameplate.new())

	nameplate.show_baseline("Ada", 27)

	assert_eq(nameplate.text, "Ada, 27")


func test_format_baseline_matches_show_baselines_output() -> void:
	assert_eq(VillagerNameplate.format_baseline("Ada", 27), "Ada, 27")


func test_set_renowned_tints_the_label_regardless_of_baseline_or_thought_showing() -> void:
	var nameplate: VillagerNameplate = autofree(VillagerNameplate.new())
	nameplate.show_baseline("Ada", 27)

	nameplate.set_renowned(true)

	assert_eq(nameplate.modulate, VillagerNameplate.RENOWNED_COLOR)
	assert_eq(nameplate.text, "Ada, 27")


func test_set_renowned_true_changes_the_nameplate_color() -> void:
	var nameplate: VillagerNameplate = autofree(VillagerNameplate.new())
	var ordinary_color: Color = nameplate.modulate

	nameplate.set_renowned(true)

	assert_ne(nameplate.modulate, ordinary_color)
