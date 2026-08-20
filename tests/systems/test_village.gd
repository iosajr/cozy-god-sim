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
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.reroll_thought(villager)

	assert_has(Village.THOUGHT_POOL, villager.current_thought)
