extends Node3D
## Spawns a flock of Sheep as placeholder 3D bodies, mirrors
## village_spawner.gd's Favored-from-exposure loop (issue #61), and tints
## a Sheep's own body (no nameplate exists for Sheep) once it turns
## Renowned.

## Off-white wool tone, distinct from Villager's tan capsule.
const BODY_COLOR: Color = Color(0.93, 0.92, 0.88)

@export var sheep_count: int = 6
@export var ground_size: float = 200.0
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 5
@export var camera_rig_path: NodePath = ^"../CameraRig"
@export var favored_radius: float = 8.0
## Discrete Favored grant per logged divine-exposure entry (issue #61) --
## no longer a per-second rate, since Favored gain is no longer
## continuous.
@export var favored_gain_per_exposure: float = 5.0

var flock: Array[Sheep] = []

var _rng := RandomNumberGenerator.new()
var _bodies: Dictionary = {}  # Sheep -> MeshInstance3D
var _debug_infos: Dictionary = {}  # Sheep -> FolkDebugInfo


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value
	_spawn_sheep()


func _process(delta: float) -> void:
	var camera_rig: Node3D = get_node_or_null(camera_rig_path)
	for a_sheep in flock:
		a_sheep.advance(delta)
		FolkSpawnerSupport.maybe_log_divine_exposure(
			a_sheep, _bodies.get(a_sheep), camera_rig, favored_radius, GameState.absolute_game_time,
			favored_gain_per_exposure, Folk.DEFAULT_FAITH_THRESHOLD, Sheep.RENOWN_THRESHOLD
		)
		_sync_renown_tint(a_sheep)
		_debug_infos[a_sheep].sync(a_sheep)


func _sync_renown_tint(a_sheep: Sheep) -> void:
	var body: MeshInstance3D = _bodies.get(a_sheep)
	if body == null:
		return
	var mat: StandardMaterial3D = body.material_override
	var target_color: Color = VillagerNameplate.RENOWNED_COLOR if a_sheep.is_renowned else BODY_COLOR
	if mat.albedo_color != target_color:
		mat.albedo_color = target_color


func _spawn_sheep() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.5, 0.9)

	for i in sheep_count:
		var a_sheep := Sheep.new("sheep_%d" % i, false)
		# Trivially true on today's uniformly grass-colored placeholder ground.
		a_sheep.check_contentment(true)
		flock.append(a_sheep)

		var root := Node3D.new()
		root.name = a_sheep.id
		root.position = GroundScatter.random_ground_position(ground_size, _rng)
		add_child(root)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = BODY_COLOR
		_bodies[a_sheep] = FolkSpawnerSupport.spawn_body(root, mesh, mat, 0.25)

		var debug_info := FolkDebugInfo.new()
		debug_info.name = "DebugInfo"
		root.add_child(debug_info)
		_debug_infos[a_sheep] = debug_info
