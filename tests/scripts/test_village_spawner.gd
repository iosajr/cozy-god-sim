extends GutTest
## Regression test for issue #31: VillageSpawner never actually set
## village.site_position, so it silently stayed at its Vector3.ZERO
## default and every Eat/Sleep/Farm-delivery/Watering destination
## resolved to the world origin instead of where the Village really
## sits (systems/village.gd's site_position doc comment already claimed
## "a spawner sets this" -- it didn't).
##
## Uses add_child_autofree() -- unlike DialogueBox/PresenceLight/
## VillagerNameplate's siblings under tests/scripts/ (deliberately built
## so their tests never run _ready()), VillageSpawner's own site_position
## fix reads global_position, which Godot only resolves correctly once a
## Node3D is actually inside the SceneTree (outside it, get_global_
## transform() logs an error and returns identity/zero -- confirmed by
## running this test un-parented first). _ready() is also where this
## bug actually lives, so it's the thing worth exercising directly.


## village_spawner.gd has no class_name (same as autoload/game_state.gd,
## per test_game_state.gd's own precedent) -- preload it directly.
const VillageSpawnerScript := preload("res://scripts/village_spawner.gd")


func test_ready_sets_site_position_to_the_spawners_own_world_position() -> void:
	var spawner: Node3D = VillageSpawnerScript.new()
	spawner.villager_count = 1
	spawner.position = Vector3(10, 0, 5)

	add_child_autofree(spawner)

	assert_eq(spawner.village.site_position, Vector3(10, 0, 5))


func test_ready_leaves_site_position_at_the_origin_for_a_spawner_left_at_the_origin() -> void:
	# Existing at-origin behavior stays unaffected -- acceptance
	# criterion 3.
	var spawner: Node3D = VillageSpawnerScript.new()
	spawner.villager_count = 1

	add_child_autofree(spawner)

	assert_eq(spawner.village.site_position, Vector3.ZERO)


## Water source position (issue #38) -- a fixed offset from site_position,
## same "single placeholder point" tier.
func test_ready_sets_water_source_position_relative_to_the_spawners_own_position() -> void:
	var spawner: Node3D = VillageSpawnerScript.new()
	spawner.villager_count = 1
	spawner.position = Vector3(10, 0, 5)

	add_child_autofree(spawner)

	assert_eq(
		spawner.village.water_source_position,
		Vector3(10, 0, 5) + VillageSpawnerScript.WATER_SOURCE_OFFSET
	)


## Regression test for issue #42: a newborn Villager added mid-game by
## Village.advance_gestation() (via a completed Reproduce Task) wasn't
## registered in any of _process()'s per-Villager dictionaries -- the very
## next frame crashed on the first dictionary lookup for it. Reaches
## global_position the same way the site_position bug above does, so this
## needs the same add_child_autofree()-into-the-real-tree setup, not a bare
## .new().
func test_process_spawns_a_mover_for_a_newborn_villager_added_after_ready() -> void:
	var spawner: Node3D = VillageSpawnerScript.new()
	spawner.villager_count = 1
	add_child_autofree(spawner)
	spawner._process(0.01)  # establishes the initial batch's Movers, etc.

	# What Village.advance_gestation() -> _spawn_newborn() does: append a
	# fresh Villager straight to village.villagers mid-game, never having
	# gone through the initial _spawn_villagers() batch.
	var newborn := Villager.new("newborn", true, "")
	spawner.village.villagers.append(newborn)

	spawner._process(0.01)  # must not crash on the unregistered newborn.

	# _spawn_one_villager() names each spawned Mover after the Villager's
	# id and adds it as spawner's own child -- a public, black-box way to
	# confirm the newborn actually got spawned (see _spawn_villagers()'s
	# doc comment).
	assert_not_null(spawner.get_node_or_null(NodePath(newborn.id)))
