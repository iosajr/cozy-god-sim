## Disposable look-dev probe for terraced terrain quantised from a HeightMap
## field. Every generation setting matches height_map_probe.gd's defaults —
## same seed, same field, same islands — and each of HeightMapBands' bands
## is one terrace step: band index is level.
extends Node3D

@export var grid_cells: int = 256
@export var cell_size: float = 4.0
@export var terrace_step: float = 1.5
## Water plane sits between the two water bands (index 0, 1) and the first
## dry band (index 2) — tuned against the default terrace_step of 1.5.
@export var water_level_y: float = 2.25
@export var tree_count: int = 1200

@export var seed_value: int = 2
@export var noise_scale: float = 90.0
@export var octaves: int = 5
@export_range(0.0, 1.0) var persistence: float = 0.5
@export var lacunarity: float = 2.0
@export var normalize_mode: HeightMap.NormalizeMode = HeightMap.NormalizeMode.LOCAL
@export var combine_mode: HeightMap.CombineMode = HeightMap.CombineMode.SUBTRACT
@export var falloff_shape: HeightMap.FalloffShape = HeightMap.FalloffShape.SQUARE
@export var falloff_noise_scale: float = 40.0
@export_range(0.0, 1.0) var falloff_noise_amount: float = 0.25

var _bands: Array[Dictionary] = HeightMapBands.bands()

var _current_seed: int = 0
var _field: HeightMap
var _levels: PackedInt32Array = PackedInt32Array()

## Don't Starve palette from docs/Design/Terrain Edge Styling.dc.html —
## band 0-1 (underwater) get "bed", 2-6 (sand through snowline) are five
## evenly-sampled steps of its nine-stop "tops" gradient.
const _BAND_TOP_COLOURS: Array[Color] = [
	Color("2b3a3f"), Color("2b3a3f"), Color("a9a186"), Color("6c7f57"),
	Color("5a6a52"), Color("6a6f72"), Color("c2c7ca"),
]
const _CLIFF_COLOUR: Color = Color("33342f")
const _WATER_COLOUR: Color = Color("3c5a68")

var _grass_material: StandardMaterial3D
var _cliff_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _trunk_material: StandardMaterial3D
var _canopy_material: StandardMaterial3D

var _cliff_instance: MultiMeshInstance3D
var _grass_instance: MultiMeshInstance3D
var _trunk_instance: MultiMeshInstance3D
var _canopy_instance: MultiMeshInstance3D
var _info_label: Label


func _ready() -> void:
	_current_seed = seed_value
	_build_materials()
	_build_water_plane()
	_build_lighting_and_environment()
	_build_camera()
	_build_info_label()
	_regenerate()


## R rerolls to a random seed, [ and ] step the seed by one, C swaps
## subtract/multiply, V swaps square/radial falloff — all rebuild the
## terrain in place, camera and lighting untouched.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_R:
			_current_seed = randi()
			_regenerate()
		KEY_BRACKETLEFT:
			_current_seed -= 1
			_regenerate()
		KEY_BRACKETRIGHT:
			_current_seed += 1
			_regenerate()
		KEY_C:
			combine_mode = HeightMap.CombineMode.MULTIPLY if combine_mode == HeightMap.CombineMode.SUBTRACT else HeightMap.CombineMode.SUBTRACT
			_regenerate()
		KEY_V:
			falloff_shape = HeightMap.FalloffShape.RADIAL if falloff_shape == HeightMap.FalloffShape.SQUARE else HeightMap.FalloffShape.SQUARE
			_regenerate()


func _regenerate() -> void:
	_field = HeightMap.new()
	_field.generate(grid_cells, grid_cells, _current_seed, noise_scale, octaves, persistence, lacunarity, Vector2.ZERO, normalize_mode, combine_mode, falloff_shape, falloff_noise_scale, falloff_noise_amount)
	_levels = _build_level_grid()
	_rebuild_terrain_meshes()
	var mode_name: String = "subtract" if combine_mode == HeightMap.CombineMode.SUBTRACT else "multiply"
	var shape_name: String = "square" if falloff_shape == HeightMap.FalloffShape.SQUARE else "radial"
	_info_label.text = "seed %d, %s, %s — R random seed, [ ] step seed, C swap blend, V swap falloff" % [_current_seed, mode_name, shape_name]


## Each cell's terrace level is the index of the HeightMapBands band its
## value falls in — the same band the 2D probe would colour it.
func _build_level_grid() -> PackedInt32Array:
	var levels: PackedInt32Array = PackedInt32Array()
	levels.resize(grid_cells * grid_cells)
	for i in range(levels.size()):
		levels[i] = HeightMapBands.index_for(_field.values[i], _bands)
	return levels


func _cell_top_y(level: int) -> float:
	return level * terrace_step


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
	_grass_material = _make_flat_material(Color.WHITE)
	_grass_material.vertex_color_use_as_albedo = true
	_cliff_material = _make_flat_material(_CLIFF_COLOUR)
	_water_material = _make_flat_material(Color(_WATER_COLOUR, 0.85))
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trunk_material = _make_flat_material(Color(0.36, 0.24, 0.16))
	_canopy_material = _make_flat_material(Color(0.20, 0.52, 0.31))


## Frees the previous terrain-dependent nodes and rebuilds them from
## _levels. Water, lighting and camera are seed-independent and untouched.
func _rebuild_terrain_meshes() -> void:
	for instance in [_cliff_instance, _grass_instance, _trunk_instance, _canopy_instance]:
		if instance != null:
			instance.queue_free()
	_build_cliff_multimesh()
	_build_grass_multimeshes()
	_build_trees()


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
	_cliff_instance = MultiMeshInstance3D.new()
	_cliff_instance.name = "CliffMultiMesh"
	_cliff_instance.multimesh = multimesh
	_cliff_instance.material_override = _cliff_material
	add_child(_cliff_instance)


## One coloured cap per cell — colour comes from the cell's band via
## _BAND_TOP_COLOURS, not from a random texture variant.
func _build_grass_multimeshes() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(cell_size, 0.2, cell_size)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = grid_cells * grid_cells
	for z in range(grid_cells):
		for x in range(grid_cells):
			var index: int = z * grid_cells + x
			var level: int = _levels[index]
			var top_y: float = _cell_top_y(level)
			var xform: Transform3D = Transform3D()
			xform.origin = Vector3(
				(float(x) + 0.5) * cell_size,
				top_y + 0.01 - 0.1,
				(float(z) + 0.5) * cell_size
			)
			multimesh.set_instance_transform(index, xform)
			multimesh.set_instance_color(index, _BAND_TOP_COLOURS[level])
	_grass_instance = MultiMeshInstance3D.new()
	_grass_instance.name = "GrassMultiMesh"
	_grass_instance.multimesh = multimesh
	_grass_instance.material_override = _grass_material
	add_child(_grass_instance)


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


func _build_trees() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _current_seed
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

	_trunk_instance = MultiMeshInstance3D.new()
	_trunk_instance.name = "TreeTrunkMultiMesh"
	_trunk_instance.multimesh = trunk_multimesh
	_trunk_instance.material_override = _trunk_material
	add_child(_trunk_instance)

	_canopy_instance = MultiMeshInstance3D.new()
	_canopy_instance.name = "TreeCanopyMultiMesh"
	_canopy_instance.multimesh = canopy_multimesh
	_canopy_instance.material_override = _canopy_material
	add_child(_canopy_instance)


func _build_lighting_and_environment() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	add_child(sun)

	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.50, 0.83)
	sky_material.sky_horizon_color = Color(0.75, 0.88, 0.96)
	sky_material.ground_horizon_color = Color(0.75, 0.88, 0.96)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.1
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = false

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


## Same CameraRig used by the live game (pan/zoom/rotate), not a fixed
## vista shot, so the probe can be flown around while judging the look.
func _build_camera() -> void:
	var world_size: float = grid_cells * cell_size
	var rig: CameraRig = CameraRig.new()
	rig.name = "CameraRig"
	rig.position = Vector3(world_size * 0.5, 0.0, world_size * 0.5)
	rig.min_zoom = cell_size * 4.0
	rig.max_zoom = world_size
	rig.pan_speed = cell_size * 6.0

	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	pivot.rotation_degrees = Vector3(-32.0, 0.0, 0.0)
	rig.add_child(pivot)

	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 50.0
	camera.current = true
	camera.position = Vector3(0.0, 0.0, world_size * 0.35)
	pivot.add_child(camera)

	add_child(rig)


func _build_info_label() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TerrainNoiseProbeDebugLayer"
	add_child(layer)

	_info_label = Label.new()
	_info_label.name = "TerrainNoiseProbeInfo"
	_info_label.position = Vector2(16, 16)
	_info_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_info_label.add_theme_constant_override("shadow_offset_x", 1)
	_info_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_info_label)
