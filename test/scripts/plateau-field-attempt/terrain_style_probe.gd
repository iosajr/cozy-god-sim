## Disposable look-dev probe for Pokémon Black/White-style terraced terrain.
extends Node3D

@export var grid_cells: int = 512
@export var cell_size: float = 4.0
@export var terrace_step: float = 1.5
@export var terrace_levels: int = 5
@export var water_level_y: float = 0.35
@export var tree_count: int = 1200
@export var seed_value: int = 2

## Reshapes the normalised noise sample before it's quantised to a level.
## Not wired into _build_level_grid — see _build_staircase_curve below.
@export var curve: Curve

## PlateauFieldAttempt/AccessSolver preview — tickets 1-3.
@export var field_seed: int = 2
@export var field_grid_cells: int = 512
## 3-4 hand-placed peninsula blobs: (centre_x, centre_z, radius), in cells.
@export var peninsula_blobs: Array[Vector3] = [
	Vector3(120, 90, 70),
	Vector3(380, 140, 60),
	Vector3(300, 400, 80),
]
## One seed per PlateauFieldAttempt.Biome: lowland, forest, mountain, coast.
@export var biome_seed_points: Array[Vector2i] = [
	Vector2i(180, 300),
	Vector2i(340, 320),
	Vector2i(256, 130),
	Vector2i(256, 256),
]

var _field: PlateauFieldAttempt
var _access_sites: Array = []
var _debug_texture_rect: TextureRect
## "levels", "noise", "mask", "raw", "tier" or "biome" — see
## _refresh_debug_texture.
var _debug_mode: String = "levels"

var _levels: PackedInt32Array = PackedInt32Array()
var _raw_noise: PackedFloat32Array = PackedFloat32Array()

var _grass_base_material: StandardMaterial3D
var _grass_variant_material: StandardMaterial3D
var _cliff_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _trunk_material: StandardMaterial3D
var _canopy_material: StandardMaterial3D


func _ready() -> void:
	_levels = _build_level_grid()
	_raw_noise = _build_raw_noise_grid()
	_build_materials()
	_build_cliff_multimesh()
	_build_grass_multimeshes()
	_build_water_plane()
	_build_trees()
	_build_lighting_and_environment()
	_build_camera()
	_build_plateau_field()
	_build_debug_view()


## Keys: 0 plain noise levels, 9 raw noise grayscale, 1 PlateauFieldAttempt land
## mask, 2 PlateauFieldAttempt raw (pre-smoothing) terrace, 3 PlateauFieldAttempt final
## tier with access-site dots, 4 PlateauFieldAttempt biome, R the 200-seed
## AccessSolver reachability check.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_0:
			_debug_mode = "levels"
			_refresh_debug_texture()
		KEY_9:
			_debug_mode = "noise"
			_refresh_debug_texture()
		KEY_1:
			_debug_mode = "mask"
			_refresh_debug_texture()
		KEY_2:
			_debug_mode = "raw"
			_refresh_debug_texture()
		KEY_3:
			_debug_mode = "tier"
			_refresh_debug_texture()
		KEY_4:
			_debug_mode = "biome"
			_refresh_debug_texture()
		KEY_R:
			AccessSolver.run_reachability_check()


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


func _make_terrain_noise() -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.008
	noise.seed = seed_value
	return noise


func _build_level_grid() -> PackedInt32Array:
	var noise: FastNoiseLite = _make_terrain_noise()
	var levels: PackedInt32Array = PackedInt32Array()
	levels.resize(grid_cells * grid_cells)
	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell_x: float = (float(x) + 0.5) * cell_size
			var cell_z: float = (float(z) + 0.5) * cell_size
			var n: float = noise.get_noise_2d(cell_x, cell_z)
			levels[z * grid_cells + x] = _quantize_level(n, terrace_levels)
	return levels


## The same noise _build_level_grid quantises, but left as a continuous
## [0, 1] value — nothing thresholded or staged.
func _build_raw_noise_grid() -> PackedFloat32Array:
	var noise: FastNoiseLite = _make_terrain_noise()
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(grid_cells * grid_cells)
	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell_x: float = (float(x) + 0.5) * cell_size
			var cell_z: float = (float(z) + 0.5) * cell_size
			var n: float = noise.get_noise_2d(cell_x, cell_z)
			values[z * grid_cells + x] = (n + 1.0) * 0.5
	return values


## One flat plateau per level, joined by a narrow smoothed step — used
## whenever no `curve` is assigned in the inspector, if _build_level_grid
## is wired to call it. Wide flats mean a stray noise wiggle rarely
## lands in the narrow step between them, so a lone cell is unlikely to
## end up as its own layer. Not currently called.
func _build_staircase_curve(levels: int) -> Curve:
	var transition_fraction: float = 0.3
	var result: Curve = Curve.new()
	var step: float = 1.0 / float(levels)
	var margin: float = step * transition_fraction * 0.5
	for i in range(levels):
		var flat_value: float = (float(i) + 0.5) * step
		var band_start: float = float(i) * step
		var band_end: float = float(i + 1) * step
		var left_x: float = 0.0 if i == 0 else band_start + margin
		var right_x: float = 1.0 if i == levels - 1 else band_end - margin
		result.add_point(Vector2(left_x, flat_value), 0.0, 0.0, Curve.TANGENT_FREE, Curve.TANGENT_FREE)
		result.add_point(Vector2(right_x, flat_value), 0.0, 0.0, Curve.TANGENT_FREE, Curve.TANGENT_FREE)
	return result


## Maps a noise sample in [-1, 1] to a terrace level in [0, terrace_levels - 1].
static func _quantize_level(noise_value: float, levels: int) -> int:
	var n01: float = (noise_value + 1.0) * 0.5
	return clampi(int(n01 * levels), 0, levels - 1)


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
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.75, 0.88, 0.96)
	environment.fog_density = 0.0018
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
	camera.position = Vector3(0.0, 0.0, cell_size * 40.0)
	pivot.add_child(camera)

	add_child(rig)


func _build_plateau_field() -> void:
	var started_at: int = Time.get_ticks_msec()
	_field = PlateauFieldAttempt.new()
	_field.generate(field_seed, field_grid_cells, peninsula_blobs)
	_field.assign_biomes(biome_seed_points, field_seed)
	var solver: AccessSolver = AccessSolver.new()
	_access_sites = solver.solve(_field)
	print("PlateauFieldAttempt: %dx%d generated in %d ms, %d access sites" % [
		field_grid_cells, field_grid_cells, Time.get_ticks_msec() - started_at, _access_sites.size(),
	])


func _build_debug_view() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "PlateauFieldAttemptDebugLayer"
	add_child(layer)

	_debug_texture_rect = TextureRect.new()
	_debug_texture_rect.name = "PlateauFieldAttemptDebugView"
	_debug_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_debug_texture_rect.position = Vector2(16, 16)
	_debug_texture_rect.size = Vector2(grid_cells, grid_cells)
	layer.add_child(_debug_texture_rect)

	_refresh_debug_texture()


func _refresh_debug_texture() -> void:
	if _debug_mode == "levels":
		_refresh_debug_texture_levels()
		return
	if _debug_mode == "noise":
		_refresh_debug_texture_noise()
		return

	var image: Image = Image.create_empty(field_grid_cells, field_grid_cells, false, Image.FORMAT_RGB8)
	for z in range(field_grid_cells):
		for x in range(field_grid_cells):
			var cell: Vector2i = Vector2i(x, z)
			var color: Color = _debug_color(cell)
			image.set_pixel(x, z, color)
	if _debug_mode == "tier":
		for site in _access_sites:
			_paint_access_dot(image, site.cell)
	_debug_texture_rect.size = Vector2(field_grid_cells, field_grid_cells)
	_debug_texture_rect.texture = ImageTexture.create_from_image(image)


## The original probe's own noise, straight through _quantize_level — no
## mask, no regions, no AccessSolver.
func _refresh_debug_texture_levels() -> void:
	var image: Image = Image.create_empty(grid_cells, grid_cells, false, Image.FORMAT_RGB8)
	for z in range(grid_cells):
		for x in range(grid_cells):
			image.set_pixel(x, z, _tier_debug_color(_levels[z * grid_cells + x]))
	_debug_texture_rect.size = Vector2(grid_cells, grid_cells)
	_debug_texture_rect.texture = ImageTexture.create_from_image(image)


## The raw [0, 1] noise as grayscale — nothing quantised or coloured by
## tier, just what the noise function itself is producing.
func _refresh_debug_texture_noise() -> void:
	var image: Image = Image.create_empty(grid_cells, grid_cells, false, Image.FORMAT_RGB8)
	for z in range(grid_cells):
		for x in range(grid_cells):
			var v: float = _raw_noise[z * grid_cells + x]
			image.set_pixel(x, z, Color(v, v, v))
	_debug_texture_rect.size = Vector2(grid_cells, grid_cells)
	_debug_texture_rect.texture = ImageTexture.create_from_image(image)


func _tier_debug_color(tier: int) -> Color:
	return Color.from_hsv(0.36 - clampf(float(tier) / 10.0, 0.0, 0.36), 0.55, 0.4 + 0.5 * clampf(float(tier) / 10.0, 0.0, 1.0))


func _debug_color(cell: Vector2i) -> Color:
	if _debug_mode == "biome":
		return _biome_debug_color(cell)
	if not _field.is_land(cell):
		return Color(0.24, 0.35, 0.47)
	if _debug_mode == "mask":
		return Color(0.42, 0.58, 0.32)
	var tier: int = _field.tier_raw_at(cell) if _debug_mode == "raw" else _field.tier_at(cell)
	return _tier_debug_color(tier)


func _biome_debug_color(cell: Vector2i) -> Color:
	if not _field.is_land(cell):
		return Color(0.24, 0.35, 0.47)
	match _field.biome_at(cell):
		PlateauFieldAttempt.Biome.LOWLAND:
			return Color(0.576, 0.659, 0.4)
		PlateauFieldAttempt.Biome.FOREST:
			return Color(0.357, 0.435, 0.298)
		PlateauFieldAttempt.Biome.MOUNTAIN:
			return Color(0.761, 0.808, 0.839)
		PlateauFieldAttempt.Biome.COAST:
			return Color(0.827, 0.682, 0.463)
		_:
			return Color(0.0, 0.0, 0.0)


func _paint_access_dot(image: Image, cell: Vector2i) -> void:
	var mark: Color = Color(0.95, 0.15, 0.1)
	for offset in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var point: Vector2i = cell + offset
		if point.x >= 0 and point.y >= 0 and point.x < field_grid_cells and point.y < field_grid_cells:
			image.set_pixel(point.x, point.y, mark)
