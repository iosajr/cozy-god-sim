extends GutTest
## Tests for systems/villager_wish_parser.gd -- parsing villager-ideas's
## IN CHARACTER: / WISH: output contract.


func test_parses_well_formed_response_into_both_parts() -> void:
	var raw := "IN CHARACTER: The gate again? Honestly.\nWISH: Fix the gate — add a latch that stays shut."

	var data := VillagerWishParser.parse(raw)

	assert_eq(data["in_character"], "The gate again? Honestly.")
	assert_eq(data["wish"], "Fix the gate — add a latch that stays shut.")
	assert_true(data["parsed_ok"])


func test_falls_back_to_raw_text_when_format_is_missing() -> void:
	var raw := "Just some rambling text with no markers at all."

	var data := VillagerWishParser.parse(raw)

	assert_eq(data["in_character"], raw)
	assert_eq(data["wish"], "")
	assert_false(data["parsed_ok"])


func test_is_case_insensitive_on_the_markers() -> void:
	var raw := "in character: tired today.\nwish: A nap spot near the well."

	var data := VillagerWishParser.parse(raw)

	assert_eq(data["in_character"], "tired today.")
	assert_eq(data["wish"], "A nap spot near the well.")
	assert_true(data["parsed_ok"])
