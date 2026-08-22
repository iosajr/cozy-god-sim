extends GutTest
## Tests for systems/village.gd's own surface: population, Known Territory,
## Houses, and TaskProvider identity. Thought/Wish, Needs, Task, and Farm
## behavior have their own test files (test_village_thoughts.gd,
## test_village_needs.gd, test_village_tasks.gd, test_village_farms.gd).


func test_populate_creates_n_villagers() -> void:
	var village := Village.new()

	village.populate(6)

	assert_eq(village.villagers.size(), 6)


func test_populated_villager_has_faith_flag_and_thought_from_pool() -> void:
	var village := Village.new()

	village.populate(1)

	var villager: Villager = village.villagers[0]
	assert_typeof(villager.has_faith, TYPE_BOOL)
	assert_has(VillageThoughts.THOUGHT_POOL, villager.current_thought)


func test_same_seed_produces_the_same_villagers() -> void:
	var village_a := Village.new(42)
	village_a.populate(6)

	var village_b := Village.new(42)
	village_b.populate(6)

	for i in 6:
		assert_eq(village_a.villagers[i].has_faith, village_b.villagers[i].has_faith)
		assert_eq(village_a.villagers[i].current_thought, village_b.villagers[i].current_thought)


func test_village_is_a_task_provider() -> void:
	var village := Village.new()

	assert_true(village is TaskProvider)


func test_query_next_task_returns_null_for_a_non_villager_folk() -> void:
	var village := Village.new()
	var folk := Folk.new("f1", true)

	assert_null(village.query_next_task(folk))


func test_new_village_starts_knowing_exactly_one_location_its_own_site() -> void:
	var village := Village.new()

	assert_eq(village.known_locations.size(), 1)
	assert_true(village.known_locations[0] is Location)


func test_knows_location_with_tag_finds_a_tag_present_on_a_known_location() -> void:
	var village := Village.new()
	var starting_tags: Array[String] = village.known_locations[0].context_tags

	for tag in starting_tags:
		assert_true(village.knows_location_with_tag(tag))


func test_knows_location_with_tag_reports_absence_for_an_unknown_tag() -> void:
	var village := Village.new()

	assert_false(village.knows_location_with_tag("this-tag-does-not-exist"))


# --- Housing (provisional, not final) ---


func test_new_village_starts_with_no_houses() -> void:
	var village := Village.new()

	assert_eq(village.houses.size(), 0)


func test_a_house_can_be_appended_to_village_houses() -> void:
	var village := Village.new()
	var house := House.new()

	village.houses.append(house)

	assert_eq(village.houses.size(), 1)
	assert_same(village.houses[0], house)


func test_villager_defaults_house_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.house)


func test_villagers_house_can_be_set_directly() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var house := House.new()

	villager.house = house

	assert_same(villager.house, house)
