extends GutTest
## Tests for Village's thought/wish rerolling and Wish resolution
## (systems/village_thoughts.gd, driven through Village's public methods).


func test_reroll_thought_produces_a_value_from_the_pool() -> void:
	var village := Village.new()
	village.wish_chance = 0.0
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
	assert_has(VillageThoughts.THOUGHT_POOL, villager.current_thought)


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
