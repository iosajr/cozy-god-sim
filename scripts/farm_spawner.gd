extends Node3D
## Spawns each Farm's placeholder 3D body at its position and owns the
## harvest-delivery loop: a standalone Mover walks between a Ready-to-
## Harvest Farm and the store, carrying up to `carry_capacity` per trip.
## No construction trigger exists yet — this spawner is the debug seam
## that adds spawned Farms straight to GameState.village.farms.

const WALKER_IDLE := "idle"
const WALKER_TO_STORE := "to_store"
const WALKER_TO_FARM := "to_farm"

const SEEDED_COLOR: Color = Color(0.45, 0.32, 0.2)
const GROWING_COLOR: Color = Color(0.42, 0.58, 0.24)
const READY_COLOR: Color = Color(0.92, 0.8, 0.25)
const WALKER_COLOR: Color = Color(0.75, 0.55, 0.35)

## One Farm's spawned body + delivery walker + trip state.
class DeliveryState:
	var body: MeshInstance3D
	var walker: Mover
	var state: String = WALKER_IDLE
	var carrying: int = 0

@export var farm_count: int = 2
@export var ground_size: float = 200.0
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 9
@export_range(1, 999, 1) var carry_capacity: int = 5
@export_range(0.1, 999.0, 0.1) var growth_threshold: float = Farm.DEFAULT_GROWTH_THRESHOLD
@export_range(1, 999, 1) var harvest_yield: int = Farm.DEFAULT_HARVEST_YIELD
@export_range(0.1, 999.0, 0.1) var walker_speed: float = 4.0

var farms: Array[Farm] = []

var _rng := RandomNumberGenerator.new()
var _deliveries: Dictionary = {}  # Farm -> DeliveryState
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
	village.advance_farms(delta)
	for farm in farms:
		# Order matters: a harvest draining the last of remaining_harvest
		# re-seeds `farm` inline, so starting delivery before tinting avoids
		# one extra frame of READY_COLOR after the stage already reset.
		_maybe_start_delivery(farm, village)
		_sync_stage_tint(farm)


func _maybe_start_delivery(farm: Farm, village: Village) -> void:
	var delivery: DeliveryState = _deliveries[farm]
	if delivery.state != WALKER_IDLE:
		return
	if farm.stage != Farm.FARM_READY_TO_HARVEST:
		return
	var taken := farm.harvest(carry_capacity)
	if taken <= 0:
		return
	delivery.carrying = taken
	delivery.state = WALKER_TO_STORE
	delivery.walker.move_to(village.site_position)


func _on_walker_arrived(farm: Farm) -> void:
	var delivery: DeliveryState = _deliveries[farm]
	if delivery.state == WALKER_TO_STORE:
		if delivery.carrying > 0:
			GameState.add_resource("food", delivery.carrying)
		delivery.carrying = 0
		delivery.state = WALKER_TO_FARM
		delivery.walker.move_to(farm.position)
	elif delivery.state == WALKER_TO_FARM:
		delivery.state = WALKER_IDLE


func _sync_stage_tint(farm: Farm) -> void:
	var body: MeshInstance3D = _deliveries[farm].body
	if body == null:
		return
	var mat: StandardMaterial3D = body.material_override
	var target_color: Color = SEEDED_COLOR
	if farm.stage == Farm.FARM_GROWING:
		target_color = GROWING_COLOR
	elif farm.stage == Farm.FARM_READY_TO_HARVEST:
		target_color = READY_COLOR
	if mat.albedo_color != target_color:
		mat.albedo_color = target_color


func _spawn_farms() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 0.2, 3.0)
	var walker_mesh := CapsuleMesh.new()
	walker_mesh.radius = 0.25
	walker_mesh.height = 1.0
	var walker_mat := StandardMaterial3D.new()
	walker_mat.albedo_color = WALKER_COLOR

	for i in farm_count:
		var farm_position := GroundScatter.random_ground_position(ground_size, _rng)
		var farm := Farm.new(farm_position, growth_threshold, harvest_yield)
		farms.append(farm)

		var root := Node3D.new()
		root.name = "farm_%d" % i
		root.position = farm_position
		add_child(root)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = SEEDED_COLOR
		var body := FolkSpawnerSupport.spawn_body(root, mesh, mat, 0.1)

		# Standalone delivery walker, not a Villager — no task/worker-
		# assignment system exists yet. Uses local `position` (not
		# global_position) to match `root`, both direct children here.
		var walker := Mover.new()
		walker.name = "farm_%d_walker" % i
		walker.speed = walker_speed
		walker.position = farm_position
		add_child(walker)
		FolkSpawnerSupport.spawn_body(walker, walker_mesh, walker_mat, 0.5)

		walker.arrived.connect(_on_walker_arrived.bind(farm))
		var delivery := DeliveryState.new()
		delivery.body = body
		delivery.walker = walker
		_deliveries[farm] = delivery
