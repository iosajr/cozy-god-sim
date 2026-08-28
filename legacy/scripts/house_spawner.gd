extends Node3D
## Spawns each House's placeholder 3D body at its position. No build
## trigger, no assignment logic — Houses are only ever added directly;
## this spawner is that debug seam, adding spawned Houses straight to
## GameState.village.houses. Nothing assigns a spawned House to a
## Villager, so Villager.house stays null here.

## Warm roof-brown, distinct from Villager's tan and Sheep's off-white.
const BODY_COLOR: Color = Color(0.5, 0.35, 0.22)

@export var house_count: int = 3
@export var ground_size: float = 200.0
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 17

var houses: Array[House] = []

var _rng := RandomNumberGenerator.new()
var _last_synced_village: Village = null


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value
	_spawn_houses()


func _process(_delta: float) -> void:
	var village: Village = GameState.village
	if village != _last_synced_village:
		FolkSpawnerSupport.sync_new_items(houses, village.houses)
		_last_synced_village = village


func _spawn_houses() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.5, 2.2, 2.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BODY_COLOR

	for i in house_count:
		var house_position := GroundScatter.random_ground_position(ground_size, _rng)
		var house := House.new(House.DEFAULT_CAPACITY, house_position)
		houses.append(house)

		var root := Node3D.new()
		root.name = "house_%d" % i
		root.position = house_position
		add_child(root)

		FolkSpawnerSupport.spawn_body(root, mesh, mat, 1.1)
