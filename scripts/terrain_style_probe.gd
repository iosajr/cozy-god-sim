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

var _grass_base_material: StandardMaterial3D
var _grass_variant_material: StandardMaterial3D
var _cliff_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _trunk_material: StandardMaterial3D
var _canopy_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_levels = _build_level_grid()
	_build_cliff_multimesh()
	_build_grass_multimeshes()
	_build_water_plane()
	_build_trees()


func _build_trees() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var ground_points: Array[Vector3] = []
	var max_attempts: int = tree_count * 50
	var attempts: int = 0
	while ground_points.size() < tree_count and attempts < max_attempts:
		attempts += 1
		var x: int = rng.randi() % grid_cells
		var z: int = rng.randi() % grid_cells
		var level: int = _levels[z * grid_cells + x]
		var top_y: float = _cell_top_y(level)
		if top_y < water_level_y:
			continue
		ground_points.append(Vector3(
			(float(x) + 0.5) * cell_size,
			top_y,
			(float(z) + 0.5) * cell_size
		))

	var trunk_height: float = 1.8
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = trunk_height
	trunk_mesh.radial_segments = 6

	var canopy_mesh: SphereMesh = SphereMesh.new()
	canopy_mesh.radius = 1.6
	canopy_mesh.height = 2.8
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 4

	var trunk_multimesh: MultiMesh = MultiMesh.new()
	trunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multimesh.mesh = trunk_mesh
	trunk_multimesh.instance_count = ground_points.size()

	var canopy_multimesh: MultiMesh = MultiMesh.new()
	canopy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multimesh.mesh = canopy_mesh
	canopy_multimesh.instance_count = ground_points.size()

	for i in range(ground_points.size()):
		var ground_point: Vector3 = ground_points[i]
		var trunk_xform: Transform3D = Transform3D(Basis(), ground_point + Vector3(0.0, trunk_height * 0.5, 0.0))
		trunk_multimesh.set_instance_transform(i, trunk_xform)
		var canopy_xform: Transform3D = Transform3D(Basis(), ground_point + Vector3(0.0, 2.4, 0.0))
		canopy_multimesh.set_instance_transform(i, canopy_xform)

	var trunk_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	trunk_instance.name = "TreeTrunkMultiMesh"
	trunk_instance.multimesh = trunk_multimesh
	trunk_instance.material_override = _trunk_material
	add_child(trunk_instance)

	var canopy_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	canopy_instance.name = "TreeCanopyMultiMesh"
	canopy_instance.multimesh = canopy_multimesh
	canopy_instance.material_override = _canopy_material
	add_child(canopy_instance)


func _build_water_plane() -> void:
	var mesh: PlaneMesh = PlaneMesh.new()
	var world_size: float = grid_cells * cell_size
	mesh.size = Vector2(world_size, world_size)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "WaterPlane"
	instance.mesh = mesh
	instance.material_override = _water_material
	instance.position = Vector3(world_size * 0.5, water_level_y, world_size * 0.5)
	add_child(instance)


func _make_flat_material(albedo: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.0
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


func _build_materials() -> void:
	_grass_base_material = _make_flat_material(Color(0.44, 0.82, 0.51))
	_grass_variant_material = _make_flat_material(Color(0.62, 0.89, 0.60))
	_cliff_material = _make_flat_material(Color(0.72, 0.55, 0.25))
	_water_material = _make_flat_material(Color(0.26, 0.40, 0.53, 0.85))
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trunk_material = _make_flat_material(Color(0.36, 0.24, 0.16))
	_canopy_material = _make_flat_material(Color(0.20, 0.52, 0.31))


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
	instance.material_override = _cliff_material
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
	_add_grass_multimesh_instance("GrassMultiMeshBase", mesh, base_xforms, _grass_base_material)
	_add_grass_multimesh_instance("GrassMultiMeshVariant", mesh, variant_xforms, _grass_variant_material)


func _add_grass_multimesh_instance(node_name: String, mesh: BoxMesh, xforms: Array[Transform3D], material: StandardMaterial3D) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = xforms.size()
	for i in range(xforms.size()):
		multimesh.set_instance_transform(i, xforms[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
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
