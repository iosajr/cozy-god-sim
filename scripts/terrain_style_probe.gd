## Disposable look-dev probe for Pokémon Black/White-style terraced terrain.
extends Node3D

@export var grid_cells: int = 128
@export var cell_size: float = 4.0
@export var terrace_step: float = 1.5
@export var terrace_levels: int = 5
@export var water_level_y: float = 0.35
@export var tree_count: int = 1200
@export var seed_value: int = 1


var _levels: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_levels = _build_level_grid()
	_build_cliff_multimesh()
	_build_grass_multimeshes()


func _cell_top_y(level: int) -> float:
	return level * terrace_step


func _build_cliff_multimesh() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(cell_size, 1.0, cell_size)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = grid_cells * grid_cells
	for z in range(grid_cells):
		for x in range(grid_cells):
			var level: int = _levels[z * grid_cells + x]
			var top_y: float = _cell_top_y(level)
			var column_height: float = top_y + 4.0
			var basis: Basis = Basis().scaled(Vector3(1.0, column_height, 1.0))
			var origin: Vector3 = Vector3(
				(float(x) + 0.5) * cell_size,
				top_y - column_height * 0.5,
				(float(z) + 0.5) * cell_size
			)
			var xform: Transform3D = Transform3D(basis, origin)
			multimesh.set_instance_transform(z * grid_cells + x, xform)
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "CliffMultiMesh"
	instance.multimesh = multimesh
	add_child(instance)


func _build_grass_multimeshes() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(cell_size, 0.2, cell_size)
	var base_xforms: Array[Transform3D] = []
	var variant_xforms: Array[Transform3D] = []
	for z in range(grid_cells):
		for x in range(grid_cells):
			var level: int = _levels[z * grid_cells + x]
			var top_y: float = _cell_top_y(level)
			var xform: Transform3D = Transform3D()
			xform.origin = Vector3(
				(float(x) + 0.5) * cell_size,
				top_y + 0.01 - 0.1,
				(float(z) + 0.5) * cell_size
			)
			if rng.randi() % 4 == 0:
				variant_xforms.append(xform)
			else:
				base_xforms.append(xform)
	_add_grass_multimesh_instance("GrassMultiMeshBase", mesh, base_xforms)
	_add_grass_multimesh_instance("GrassMultiMeshVariant", mesh, variant_xforms)


func _add_grass_multimesh_instance(node_name: String, mesh: BoxMesh, xforms: Array[Transform3D]) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = xforms.size()
	for i in range(xforms.size()):
		multimesh.set_instance_transform(i, xforms[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)


func _build_level_grid() -> PackedInt32Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.008
	noise.seed = seed_value
	var levels: PackedInt32Array = PackedInt32Array()
	levels.resize(grid_cells * grid_cells)
	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell_x: float = (float(x) + 0.5) * cell_size
			var cell_z: float = (float(z) + 0.5) * cell_size
			var n: float = noise.get_noise_2d(cell_x, cell_z)
			levels[z * grid_cells + x] = _quantize_level(n, terrace_levels)
	return levels


## Maps a noise sample in [-1, 1] to a terrace level in [0, terrace_levels - 1].
static func _quantize_level(noise_value: float, levels: int) -> int:
	var n01: float = (noise_value + 1.0) * 0.5
	return clampi(int(n01 * levels), 0, levels - 1)
