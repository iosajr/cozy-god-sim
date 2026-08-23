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
