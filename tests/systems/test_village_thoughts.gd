extends GutTest
## Tests for Village's thought/wish rerolling and Wish resolution
## (systems/village_thoughts.gd, driven through Village's public methods).


func test_reroll_thought_produces_a_value_from_the_pool() -> void:
	var village := Village.new()
	village.wish_chance = 0.0
	village.empty_chance = 0.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_has(VillageThoughts.THOUGHT_POOL, villager.current_thought)


func test_villager_defaults_current_wish_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.current_wish)


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
	village.empty_chance = 0.0
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
	village.empty_chance = 0.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_null(villager.current_wish)
	assert_has(VillageThoughts.THOUGHT_POOL, villager.current_thought)


func test_same_seed_produces_the_same_wish_vs_flavor_choice_and_outcome() -> void:
	var pantheon := Pantheon.new()

	var village_a := Village.new(7)
	village_a.wish_chance = 1.0
	village_a.empty_chance = 0.0
	village_a.populate(6)
	for villager in village_a.villagers:
		village_a.reroll_thought(villager, pantheon)

	var village_b := Village.new(7)
	village_b.wish_chance = 1.0
	village_b.empty_chance = 0.0
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


func test_reroll_thought_can_produce_an_empty_outcome_when_empty_chance_is_one() -> void:
	var village := Village.new()
	village.empty_chance = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_eq(villager.current_thought, "")
	assert_null(villager.current_wish)


func test_reroll_thought_never_produces_an_empty_outcome_when_empty_chance_is_zero() -> void:
	var village := Village.new()
	village.empty_chance = 0.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_ne(villager.current_thought, "")


func test_default_empty_chance_makes_empty_the_single_most_common_outcome() -> void:
	var village := Village.new(42)
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	var empty_count := 0
	var non_empty_count := 0
	var reroll_count := 500
	for i in reroll_count:
		village.reroll_thought(villager, pantheon)
		if villager.current_thought == "":
			empty_count += 1
		else:
			non_empty_count += 1

	assert_gt(empty_count, non_empty_count,
		"empty should be reachable at a meaningfully higher rate than non-empty combined")


func test_wish_vs_flavor_ratio_among_non_empty_outcomes_is_unchanged_by_empty_chance() -> void:
	var pantheon := Pantheon.new()

	var village_a := Village.new(3)
	village_a.wish_chance = 0.5
	village_a.empty_chance = 0.0
	village_a.populate(1)
	var villager_a: Villager = village_a.villagers[0]

	var village_b := Village.new(3)
	village_b.wish_chance = 0.5
	village_b.empty_chance = 0.7
	village_b.populate(1)
	var villager_b: Villager = village_b.villagers[0]

	var reroll_count := 200
	var wish_count_a := 0
	var non_empty_count_b := 0
	var wish_count_b := 0
	for i in reroll_count:
		village_a.reroll_thought(villager_a, pantheon)
		if villager_a.current_wish != null:
			wish_count_a += 1

		village_b.reroll_thought(villager_b, pantheon)
		if villager_b.current_thought != "":
			non_empty_count_b += 1
			if villager_b.current_wish != null:
				wish_count_b += 1

	# Same seed/RNG sequence in both villages -- adding empty_chance only
	# consumes an extra roll per reroll_thought() call, it doesn't change
	# how the non-empty branch itself decides wish-vs-flavor. Both should
	# see the same wish rate among their non-empty outcomes.
	var wish_ratio_a: float = float(wish_count_a) / float(reroll_count)
	var wish_ratio_b: float = float(wish_count_b) / float(non_empty_count_b)
	assert_almost_eq(wish_ratio_a, wish_ratio_b, 0.15)
