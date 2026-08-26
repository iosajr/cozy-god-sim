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


func test_populated_villager_starts_at_a_believable_adult_age() -> void:
	var village := Village.new()

	village.populate(1)

	var villager: Villager = village.villagers[0]
	assert_gte(villager.age_years, Village.MIN_STARTING_AGE_YEARS)
	assert_lte(villager.age_years, Village.MAX_STARTING_AGE_YEARS)


func test_no_populated_villager_ever_starts_below_the_minimum_starting_age() -> void:
	var village := Village.new()

	village.populate(50)

	for villager: Villager in village.villagers:
		assert_gte(villager.age_years, 20)


func test_populated_villager_gets_a_non_empty_name_from_the_pool() -> void:
	var village := Village.new()

	village.populate(1)

	var villager: Villager = village.villagers[0]
	assert_ne(villager.villager_name, "")
	assert_has(Village.NAME_POOL, villager.villager_name)


func test_no_populated_villager_ever_starts_with_an_empty_name() -> void:
	var village := Village.new()

	village.populate(50)

	for villager: Villager in village.villagers:
		assert_ne(villager.villager_name, "")


func test_populate_assigns_is_farmer_with_a_baseline_probability() -> void:
	var village := Village.new()

	village.populate(200)

	var farmer_count := 0
	for villager: Villager in village.villagers:
		if villager.is_farmer:
			farmer_count += 1
	# Roughly Village.FARMER_CHANCE (0.5) of 200 -- generous bounds, not
	# an exact-probability assertion.
	assert_gt(farmer_count, 0)
	assert_lt(farmer_count, 200)


func test_populate_assigns_sex_with_roughly_even_split() -> void:
	var village := Village.new()

	village.populate(200)

	var female_count := 0
	for villager: Villager in village.villagers:
		if villager.sex == Villager.Sex.FEMALE:
			female_count += 1
	# Roughly half of 200 -- generous bounds, not an exact-probability
	# assertion (same spirit as test_populate_assigns_is_farmer_with_a_
	# baseline_probability above).
	assert_gt(female_count, 0)
	assert_lt(female_count, 200)


func test_same_seed_produces_the_same_villagers() -> void:
	var village_a := Village.new(42)
	village_a.populate(6)

	var village_b := Village.new(42)
	village_b.populate(6)

	for i in 6:
		assert_eq(village_a.villagers[i].has_faith, village_b.villagers[i].has_faith)
		assert_eq(village_a.villagers[i].current_thought, village_b.villagers[i].current_thought)
		assert_eq(village_a.villagers[i].age_years, village_b.villagers[i].age_years)
		assert_eq(village_a.villagers[i].villager_name, village_b.villagers[i].villager_name)
		assert_eq(village_a.villagers[i].is_farmer, village_b.villagers[i].is_farmer)
		assert_eq(village_a.villagers[i].sex, village_b.villagers[i].sex)


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


## known_resources (issue #37) is a sibling collection to known_locations,
## not seeded with anything at Village creation -- only ever populated by
## dropped cargo (see test_village_tasks.gd's Recover section).
func test_new_village_starts_with_no_known_resources() -> void:
	var village := Village.new()

	assert_true(village.known_resources.is_empty())


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


func test_villager_defaults_villager_name_to_empty() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.villager_name, "")


func test_villagers_name_can_be_set_directly() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.villager_name = "Ada"

	assert_eq(villager.villager_name, "Ada")


func test_villagers_house_can_be_set_directly() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var house := House.new()

	villager.house = house

	assert_same(villager.house, house)


# --- Family (issue #40) ---


# --- Pairing (issue #41) ---


func test_villager_defaults_sex_to_male() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.sex, Villager.Sex.MALE)


func test_villagers_sex_can_be_set_directly() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.sex = Villager.Sex.FEMALE

	assert_eq(villager.sex, Villager.Sex.FEMALE)


func test_villager_defaults_paired_with_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.paired_with)


func test_min_reproduction_age_is_18() -> void:
	assert_eq(Villager.MIN_REPRODUCTION_AGE, 18)


func test_advance_pairing_pairs_two_eligible_villagers_who_stay_close_long_enough() -> void:
	var village := Village.new()
	village.pairing_duration = 10.0
	var a := Villager.new("v1", false, "")
	a.sex = Villager.Sex.MALE
	a.age_years = Villager.MIN_REPRODUCTION_AGE
	var b := Villager.new("v2", false, "")
	b.sex = Villager.Sex.FEMALE
	b.age_years = Villager.MIN_REPRODUCTION_AGE
	b.position = Vector3(1, 0, 0)
	village.villagers.append(a)
	village.villagers.append(b)

	village.advance_pairing(10.0)

	assert_same(a.paired_with, b)
	assert_same(b.paired_with, a)


func test_villager_defaults_family_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.family)


func test_populate_leaves_no_villager_family_less() -> void:
	var village := Village.new()

	village.populate(50)

	for villager: Villager in village.villagers:
		assert_not_null(villager.family)


func test_populate_groups_villagers_into_families_sized_within_the_tunable_range() -> void:
	var village := Village.new()

	village.populate(200)

	var seen: Dictionary = {}
	for villager: Villager in village.villagers:
		var family: Family = villager.family
		if not seen.has(family):
			seen[family] = true
			assert_gte(family.members.size(), Village.MIN_FAMILY_SIZE)
			assert_lte(family.members.size(), Village.MAX_FAMILY_SIZE)


func test_populate_assigns_some_families_a_farming_bias() -> void:
	var village := Village.new()

	village.populate(200)

	var seen: Dictionary = {}
	var biased_count := 0
	for villager: Villager in village.villagers:
		var family: Family = villager.family
		if not seen.has(family):
			seen[family] = true
			if family.has_farming_bias:
				biased_count += 1
	# Roughly Village.FAMILY_FARMING_BIAS_CHANCE of ~60-100 families --
	# generous bounds, not an exact-probability assertion.
	assert_gt(biased_count, 0)


func test_family_farming_bias_raises_a_members_odds_of_starting_a_farmer() -> void:
	# Seeded RNG, per this project's existing RNG-seeding test patterns
	# (see test_same_seed_produces_the_same_villagers below) -- picks a
	# seed where at least one family lands each side of the bias so the
	# comparison below is meaningful.
	var village := Village.new(7)

	village.populate(400)

	var biased_farmer_count := 0
	var biased_total := 0
	var baseline_farmer_count := 0
	var baseline_total := 0
	for villager: Villager in village.villagers:
		var family: Family = villager.family
		if family.has_farming_bias:
			biased_total += 1
			if villager.is_farmer:
				biased_farmer_count += 1
		else:
			baseline_total += 1
			if villager.is_farmer:
				baseline_farmer_count += 1
	assert_gt(biased_total, 0)
	assert_gt(baseline_total, 0)
	var biased_rate: float = float(biased_farmer_count) / float(biased_total)
	var baseline_rate: float = float(baseline_farmer_count) / float(baseline_total)
	assert_gt(biased_rate, baseline_rate)


func test_same_seed_produces_the_same_families_and_farmer_bias() -> void:
	var village_a := Village.new(42)
	village_a.populate(20)

	var village_b := Village.new(42)
	village_b.populate(20)

	for i in 20:
		var family_a: Family = village_a.villagers[i].family
		var family_b: Family = village_b.villagers[i].family
		assert_eq(family_a.has_farming_bias, family_b.has_farming_bias)
		assert_eq(family_a.members.size(), family_b.members.size())


# --- Renowned starters (issue #56) ---


func test_populate_seeds_a_couple_of_starter_villagers_as_renowned() -> void:
	var village := Village.new(1)

	village.populate(6)

	var renowned_count := 0
	for villager: Villager in village.villagers:
		if villager.is_renowned:
			renowned_count += 1
	assert_eq(renowned_count, Village.STARTER_RENOWNED_COUNT)


func test_renowned_starters_also_have_faith_per_gain_favored() -> void:
	var village := Village.new(1)

	village.populate(6)

	for villager: Villager in village.villagers:
		if villager.is_renowned:
			assert_true(villager.has_faith)


func test_non_renowned_starters_get_no_forced_faith_or_favored() -> void:
	var village := Village.new(1)

	village.populate(6)

	var seen_non_renowned := false
	for villager: Villager in village.villagers:
		if not villager.is_renowned:
			seen_non_renowned = true
			assert_eq(villager.favored, 0.0)
	assert_true(seen_non_renowned)


func test_same_seed_produces_the_same_renowned_starters() -> void:
	var village_a := Village.new(42)
	village_a.populate(6)

	var village_b := Village.new(42)
	village_b.populate(6)

	for i in 6:
		assert_eq(village_a.villagers[i].is_renowned, village_b.villagers[i].is_renowned)


func test_a_later_populate_call_does_not_renown_the_new_villagers() -> void:
	var village := Village.new(1)
	village.populate(6)

	village.populate(1)

	assert_false(village.villagers[6].is_renowned)
