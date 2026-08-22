extends GutTest
## Tests for systems/village.gd (Seam 1). No scene tree involved — Village
## is plain RefCounted data, per CONTEXT.md/docs/systems-overview.md and
## issue #2.


func test_populate_creates_n_villagers() -> void:
	var village := Village.new()

	village.populate(6)

	assert_eq(village.villagers.size(), 6)


func test_populated_villager_has_faith_flag_and_thought_from_pool() -> void:
	var village := Village.new()

	village.populate(1)

	var villager: Villager = village.villagers[0]
	assert_typeof(villager.has_faith, TYPE_BOOL)
	assert_has(Village.THOUGHT_POOL, villager.current_thought)


func test_same_seed_produces_the_same_villagers() -> void:
	var village_a := Village.new(42)
	village_a.populate(6)

	var village_b := Village.new(42)
	village_b.populate(6)

	for i in 6:
		assert_eq(village_a.villagers[i].has_faith, village_b.villagers[i].has_faith)
		assert_eq(village_a.villagers[i].current_thought, village_b.villagers[i].current_thought)


func test_reroll_thought_produces_a_value_from_the_pool() -> void:
	var village := Village.new()
	village.wish_chance = 0.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_has(Village.THOUGHT_POOL, villager.current_thought)


func test_villager_defaults_current_wish_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.current_wish)


func test_villager_defaults_favored_to_zero() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.favored, 0.0)


func test_villager_defaults_is_renowned_to_false() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_false(villager.is_renowned)


func test_gain_favored_accumulates_over_repeated_calls() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(0.5, 100.0)
	villager.gain_favored(0.5, 100.0)
	villager.gain_favored(0.25, 100.0)

	assert_eq(villager.favored, 1.25)


func test_gain_favored_grants_faith_to_a_skeptic_who_crosses_the_threshold() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(10.0, 10.0)

	assert_true(villager.has_faith)


func test_gain_favored_leaves_a_skeptic_faithless_below_the_threshold() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(5.0, 10.0)

	assert_false(villager.has_faith)


func test_gain_favored_on_a_villager_who_already_has_faith_keeps_accumulating_without_incident() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(10.0, 10.0)
	villager.gain_favored(10.0, 10.0)

	assert_eq(villager.favored, 20.0)
	assert_true(villager.has_faith)


func test_gain_favored_grants_renown_to_a_faithful_villager_who_crosses_the_renown_threshold() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(10.0, 5.0, 10.0)

	assert_true(villager.is_renowned)


func test_gain_favored_leaves_a_faithful_villager_unrenowned_below_the_renown_threshold() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(5.0, 5.0, 10.0)

	assert_false(villager.is_renowned)


func test_gain_favored_never_grants_renown_to_a_skeptic_even_past_the_renown_threshold() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(10.0, 100.0, 10.0)

	assert_false(villager.is_renowned)


func test_gain_favored_can_grant_faith_and_renown_in_the_same_call_that_crosses_both_thresholds() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(10.0, 5.0, 10.0)

	assert_true(villager.has_faith)
	assert_true(villager.is_renowned)


func test_renown_persists_across_further_gain_favored_calls() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(10.0, 5.0, 10.0)
	villager.gain_favored(1.0, 5.0, 10.0)

	assert_true(villager.is_renowned)


func test_resolve_wish_links_to_the_god_who_claims_its_domain() -> void:
	var village := Village.new()
	var pantheon := Pantheon.new()
	var wish := Wish.new("I wish the rats would leave the grain store.", "vermin")

	village.resolve_wish(wish, pantheon)

	assert_not_null(wish.linked_god)
	assert_eq(wish.linked_god.domain, "vermin")
	assert_has(Wish.OUTCOMES, wish.outcome)


func test_resolve_wish_with_unclaimed_domain_leaves_it_unlinked_but_resolved() -> void:
	var village := Village.new()
	var pantheon := Pantheon.new()
	var wish := Wish.new("I wish the loom worked better.", "weaving")

	village.resolve_wish(wish, pantheon)

	assert_null(wish.linked_god)
	assert_eq(wish.outcome, Wish.OUTCOME_IGNORED)


func test_resolve_wish_with_a_null_pantheon_resolves_to_ignored_without_crashing() -> void:
	var village := Village.new()
	var wish := Wish.new("I wish the rats would leave the grain store.", "vermin")

	village.resolve_wish(wish, null)

	assert_null(wish.linked_god)
	assert_eq(wish.outcome, Wish.OUTCOME_IGNORED)


func test_reroll_thought_can_draw_a_wish_and_resolve_it_against_the_pantheon() -> void:
	var village := Village.new(1)
	village.wish_chance = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_not_null(villager.current_wish)
	assert_eq(villager.current_thought, villager.current_wish.text)
	assert_has(Wish.OUTCOMES, villager.current_wish.outcome)


func test_reroll_thought_never_draws_a_wish_when_wish_chance_is_zero() -> void:
	var village := Village.new()
	village.wish_chance = 0.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_null(villager.current_wish)
	assert_has(Village.THOUGHT_POOL, villager.current_thought)


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


func test_same_seed_produces_the_same_wish_vs_flavor_choice_and_outcome() -> void:
	var pantheon := Pantheon.new()

	var village_a := Village.new(7)
	village_a.wish_chance = 1.0
	village_a.populate(6)
	for villager in village_a.villagers:
		village_a.reroll_thought(villager, pantheon)

	var village_b := Village.new(7)
	village_b.wish_chance = 1.0
	village_b.populate(6)
	for villager in village_b.villagers:
		village_b.reroll_thought(villager, pantheon)

	for i in 6:
		var villager_a: Villager = village_a.villagers[i]
		var villager_b: Villager = village_b.villagers[i]
		assert_eq(villager_a.current_thought, villager_b.current_thought)
		assert_not_null(villager_a.current_wish)
		assert_not_null(villager_b.current_wish)
		assert_eq(villager_a.current_wish.domain, villager_b.current_wish.domain)
		assert_eq(villager_a.current_wish.outcome, villager_b.current_wish.outcome)


func test_villager_defaults_is_away_and_is_provisioned_to_false() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_false(villager.is_away)
	assert_false(villager.is_provisioned)


func test_villager_defaults_last_eating_outcome_to_empty_string() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.last_eating_outcome, "")


func test_check_eating_returns_at_village_outcome_when_not_away_regardless_of_food() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(village.check_eating(villager, true), Village.EATING_AT_VILLAGE)
	assert_eq(village.check_eating(villager, false), Village.EATING_AT_VILLAGE)


func test_check_eating_returns_provisioned_outcome_when_away_and_provisioned() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.is_away = true
	villager.is_provisioned = true

	assert_eq(village.check_eating(villager, false), Village.EATING_PROVISIONED)


func test_check_eating_returns_foraging_outcome_when_away_and_unprovisioned() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.is_away = true
	villager.is_provisioned = false

	assert_eq(village.check_eating(villager, true), Village.EATING_FORAGING)


func test_advance_eating_checks_does_not_record_an_outcome_before_the_countdown_elapses() -> void:
	var village := Village.new()
	village.eating_check_interval_min = 100.0
	village.eating_check_interval_max = 100.0
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.advance_eating_checks(1.0, true)

	assert_eq(villager.last_eating_outcome, "")


func test_advance_eating_checks_records_an_outcome_once_the_countdown_elapses() -> void:
	var village := Village.new()
	village.eating_check_interval_min = 1.0
	village.eating_check_interval_max = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.advance_eating_checks(2.0, true)

	assert_eq(villager.last_eating_outcome, Village.EATING_AT_VILLAGE)


func test_advance_eating_checks_ticks_down_the_countdown_by_delta() -> void:
	var village := Village.new()
	village.eating_check_interval_min = 10.0
	village.eating_check_interval_max = 10.0
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.advance_eating_checks(4.0, true)
	assert_eq(villager.last_eating_outcome, "")
	village.advance_eating_checks(4.0, true)
	assert_eq(villager.last_eating_outcome, "")
	village.advance_eating_checks(4.0, true)
	assert_eq(villager.last_eating_outcome, Village.EATING_AT_VILLAGE)


func test_new_village_starts_with_no_houses() -> void:
	# issue #17's Housing data slice: no construction trigger this
	# slice, so a fresh Village's houses collection starts empty.
	var village := Village.new()

	assert_eq(village.houses.size(), 0)


func test_a_house_can_be_appended_to_village_houses() -> void:
	# No assignment logic in this slice (issue #17's Out of Scope) — a
	# House is just directly appendable, mirroring known_locations.
	var village := Village.new()
	var house := House.new()

	village.houses.append(house)

	assert_eq(village.houses.size(), 1)
	assert_same(village.houses[0], house)


func test_villager_defaults_house_to_null() -> void:
	# issue #17: no assignment logic ships this slice, so a Villager's
	# House pointer stays unset until something (a test, a debug seam)
	# sets it directly.
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.house)


func test_villagers_house_can_be_set_directly() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var house := House.new()

	villager.house = house

	assert_same(villager.house, house)
