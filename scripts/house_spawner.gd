extends Node3D
## HouseSpawner
## Sibling to village_spawner.gd/sheep_spawner.gd (issue #30's Solution) —
## spawns each House's placeholder 3D body at its `position` (issue #17's
## House gains a real `position: Vector3` this issue), the same
## GroundScatter-based scatter world_gen.gd/village_spawner.gd/
## sheep_spawner.gd already use. A primitive placeholder shape is a
## completely acceptable outcome here (issue #30's User Story 5) — a real
## model is a nice-to-have only, not a requirement.
##
## No build trigger, no assignment logic (issue #30's Out of Scope,
## unchanged from issue #17's original House slice) — Houses are still
## only ever added directly. This spawner IS that test/debug seam: it
## creates each House with a scattered `position` and adds it straight to
## `GameState.village.houses`, mirroring the same "populate on _ready(),
## no Player-facing trigger" shape village_spawner.gd/sheep_spawner.gd use
## for their own populations. Nothing here assigns any spawned House to a
## Villager — `Villager.house` stays null for every Villager exactly as
## before, so Sleep keeps using the `site_position` fallback in practice
## (see systems/village.gd's task_destination()) until real assignment
## logic exists.
##
## `GameState.village.houses` is (re)synced from this spawner's own
## `houses` array whenever `GameState.village` turns out to be a
## different object than last frame — defensive against
## `village_spawner.gd` replacing it with a freshly-populated Village of
## its own after this spawner has already run (Godot doesn't strictly
## guarantee sibling `_ready()` ordering the way this scene's node order
## implies), same defensive spirit as `GroundScatter.
## resolve_ground_size()`'s null fallback and (per the unmerged issue #15
## Farm WIP branch's `scripts/farm_spawner.gd`, the closest sibling
## precedent for this exact pattern) its own identical
## `_last_synced_village` guard.

## Placeholder body color for a House — a warm roof-brown, deliberately
## distinct from Villager's tan capsule and Sheep's off-white wool tone
## (see village_spawner.gd/sheep_spawner.gd's own BODY_COLOR) so a House
## reads as a different kind of thing even before real art exists.
const BODY_COLOR: Color = Color(0.5, 0.35, 0.22)

@export var house_count: int = 3
## Fallback ground size, used only if `world_gen_path` doesn't resolve to
## a node with its own `ground_size` (see GroundScatter.
## resolve_ground_size()) — mirrors village_spawner.gd/sheep_spawner.gd.
@export var ground_size: float = 200.0
## Sibling node (world_gen.gd) that owns the ground plane's real size, so
## Houses and Villagers/Sheep/trees never disagree about how big the
## ground is.
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 17

var houses: Array[House] = []

var _rng := RandomNumberGenerator.new()
## See this script's doc comment on `GameState.village.houses` syncing —
## null until the first `_process()` call, so the very first frame always
## syncs once regardless of whatever `GameState.village` already is.
var _last_synced_village: Village = null


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value
	_spawn_houses()


func _process(_delta: float) -> void:
	var village: Village = GameState.village
	if village != _last_synced_village:
		for house in houses:
			if not village.houses.has(house):
				village.houses.append(house)
		_last_synced_village = village


func _spawn_houses() -> void:
	for i in house_count:
		var house_position := GroundScatter.random_ground_position(ground_size, _rng)
		var house := House.new(House.DEFAULT_CAPACITY, house_position)
		houses.append(house)

		var root := Node3D.new()
		root.name = "house_%d" % i
		root.position = house_position
		add_child(root)

		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.5, 2.2, 2.5)
		body.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BODY_COLOR
		body.material_override = mat
		body.position.y = 1.1
		root.add_child(body)
