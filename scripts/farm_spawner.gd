extends Node3D
## Spawns each Farm's placeholder 3D body at its position and keeps its
## color tinted to the current stage (awaiting-planting/seeded/growing/
## ready-to-harvest). No construction trigger exists yet — this spawner is
## the debug seam that adds spawned Farms straight to GameState.village.farms.
##
## Harvest-delivery has no existence independent of an actual Villager
## doing it (issue #33) — the standalone delivery walker this spawner used
## to own is gone; a Ready-to-Harvest Farm is now offered to an idle
## Villager as a real Collect Task by systems/village_tasks.gd/
## village_farm_labor.gd. Likewise, a fresh/reset Farm no longer
## auto-transitions into Seeded (issue #36) — it sits Awaiting-Planting
## until an idle Villager completes a Seed Task via village_farm_seeding.gd.

const AWAITING_PLANTING_COLOR: Color = Color(0.55, 0.5, 0.42)
const SEEDED_COLOR: Color = Color(0.45, 0.32, 0.2)
const GROWING_COLOR: Color = Color(0.42, 0.58, 0.24)
const READY_COLOR: Color = Color(0.92, 0.8, 0.25)

@export var farm_count: int = 2
@export var ground_size: float = 200.0
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 9
@export_range(0.1, 999.0, 0.1) var growth_threshold: float = Farm.DEFAULT_GROWTH_THRESHOLD
@export_range(1, 999, 1) var harvest_yield: int = Farm.DEFAULT_HARVEST_YIELD

var farms: Array[Farm] = []

var _rng := RandomNumberGenerator.new()
var _bodies: Dictionary = {}  # Farm -> MeshInstance3D
var _last_synced_village: Village = null


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value
	_spawn_farms()


func _process(delta: float) -> void:
	var village: Village = GameState.village
	if village != _last_synced_village:
		FolkSpawnerSupport.sync_new_items(farms, village.farms)
		_last_synced_village = village
	village.advance_farms(delta, GameState.absolute_game_time)
	for farm in farms:
		_sync_stage_tint(farm)


func _sync_stage_tint(farm: Farm) -> void:
	var body: MeshInstance3D = _bodies[farm]
	if body == null:
		return
	var mat: StandardMaterial3D = body.material_override
	var target_color: Color = SEEDED_COLOR
	if farm.stage == Farm.FARM_AWAITING_PLANTING:
		target_color = AWAITING_PLANTING_COLOR
	elif farm.stage == Farm.FARM_GROWING:
		target_color = GROWING_COLOR
	elif farm.stage == Farm.FARM_READY_TO_HARVEST:
		target_color = READY_COLOR
	if mat.albedo_color != target_color:
		mat.albedo_color = target_color


func _spawn_farms() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 0.2, 3.0)

	for i in farm_count:
		var farm_position := GroundScatter.random_ground_position(ground_size, _rng)
		var farm := Farm.new(farm_position, growth_threshold, harvest_yield)
		farms.append(farm)

		var root := Node3D.new()
		root.name = "farm_%d" % i
		root.position = farm_position
		add_child(root)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = AWAITING_PLANTING_COLOR
		_bodies[farm] = FolkSpawnerSupport.spawn_body(root, mesh, mat, 0.1)
