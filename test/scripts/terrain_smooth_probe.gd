## Disposable look-dev probe for a smooth-shaded terrain mesh built directly
## from a HeightMap field's continuous values — no terracing, no cliffs.
## Generation settings match terrain_noise_probe.gd's defaults — same seed,
## same field, same islands — this is that same field with a continuous
## surface instead of stepped levels.
extends Node3D

@export var grid_cells: int = 256
@export var cell_size: float = 4.0
## World-space height at value 1.0 — plain linear, every band below the
## snow threshold scales by this alone.
@export var max_height: float = 45.0
## Extra world-space height a value of 1.0 stacks on top of its plain linear
## height — the peak boost, ramping in only above the snow band's threshold.
@export var peak_boost_height: float = 40.0
## >1 ramps the peak boost in late (flat until close to the snow threshold,
## then sharp) — shapes only the boost above the threshold, not the whole
## field, so hills elsewhere are untouched by this.
@export var height_curve_exponent: float = 2.4
## 0.36 * max_height — 0.36 is HeightMapBands' midpoint between the
## shallow-water and sand thresholds (0.32, 0.40); well below the snow
## band, so the peak boost never reaches it. Re-derive by hand if
## max_height changes.
@export var water_level_y: float = 16.2
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

## Don't Starve palette from docs/Design/Terrain Edge Styling.dc.html —
## same swatches the terraced probes use, so all three probes read as one
## family. Band 0-1 (underwater) get "bed", 2-6 are five evenly-sampled
## steps of its nine-stop "tops" gradient.
const _BAND_TOP_COLOURS: Array[Color] = [
	Color("2b3a3f"), Color("2b3a3f"), Color("a9a186"), Color("6c7f57"),
	Color("5a6a52"), Color("6a6f72"), Color("c2c7ca"),
]
## What the snow band lightens toward above its own threshold, so a summit
## is visibly brighter than its base instead of one flat colour.
const _PEAK_COLOUR: Color = Color("f5f7f6")
const _WATER_COLOUR: Color = Color("3c5a68")

## Bands the raw field value (carried in vertex COLOR.r) into a colour per
## pixel instead of per vertex or per triangle — the step lands exactly on
## the true interpolated value at that pixel, so band edges are a clean
## line through each triangle, not a stair-step or a blended smear. The top
## band lightens toward peak_colour above its own threshold.
const _TERRAIN_SHADER_CODE: String = """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 band_colours[7];
uniform float band_thresholds[7];
uniform vec4 peak_colour;

void fragment() {
	float value = COLOR.r;
	vec4 colour = band_colours[0];
	for (int i = 0; i < 7; i++) {
		if (value >= band_thresholds[i]) {
			colour = band_colours[i];
		}
	}
	float top_threshold = band_thresholds[6];
	if (value >= top_threshold) {
		float peak_t = clamp((value - top_threshold) / max(1.0 - top_threshold, 0.0001), 0.0, 1.0);
		colour = mix(band_colours[6], peak_colour, peak_t);
	}
	ALBEDO = colour.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
"""

var _current_seed: int = 0
var _field: HeightMap

var _terrain_material: ShaderMaterial
var _water_material: StandardMaterial3D
var _trunk_material: StandardMaterial3D
var _canopy_material: StandardMaterial3D

var _terrain_instance: MeshInstance3D
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
	_rebuild_terrain_mesh()
	_rebuild_trees()
	var mode_name: String = "subtract" if combine_mode == HeightMap.CombineMode.SUBTRACT else "multiply"
	var shape_name: String = "square" if falloff_shape == HeightMap.FalloffShape.SQUARE else "radial"
	_info_label.text = "seed %d, %s, %s — R random seed, [ ] step seed, C swap blend, V swap falloff" % [_current_seed, mode_name, shape_name]


func _height_at(x: int, z: int) -> float:
	return _shaped_height(_field.value_at(x, z))


## Plain linear height, plus an exponential boost stacked on top above the
## snow band's threshold — hills scale by max_height alone; only peaks
## sharpen. base is never reduced, so this only ever raises height.
func _shaped_height(value: float) -> float:
	var base: float = value * max_height
	var peak_threshold: float = _bands[_bands.size() - 1]["threshold"]
	if value <= peak_threshold:
		return base
	var peak_t: float = inverse_lerp(peak_threshold, 1.0, value)
	return base + pow(peak_t, height_curve_exponent) * peak_boost_height


## One triangulated quad per cell, generate_normals() for a smooth-shaded
## continuous surface. Quads fully below the water plane are skipped — the
## opaque water hides them. Vertex colour carries the raw field value, not a
## final colour — _terrain_material bands it into colour per pixel.
func _rebuild_terrain_mesh() -> void:
	if _terrain_instance != null:
		_terrain_instance.queue_free()

	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(grid_cells - 1):
		for x in range(grid_cells - 1):
			_add_quad(surface, x, z)
	surface.generate_normals()

	_terrain_instance = MeshInstance3D.new()
	_terrain_instance.name = "SmoothTerrainMesh"
	_terrain_instance.mesh = surface.commit()
	_terrain_instance.material_override = _terrain_material
	add_child(_terrain_instance)


## Godot fronts are clockwise-wound, so each triangle is v0, v2, v1 rather
## than the counter-clockwise order that would put the normal underground.
func _add_quad(surface: SurfaceTool, x: int, z: int) -> void:
	if _quad_is_submerged(x, z):
		return
	_add_triangle(surface, [Vector2i(x, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)])
	_add_triangle(surface, [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 1, z + 1)])


## True only when every corner of this quad sits below the water plane — a
## quad with even one corner above it is the shoreline and still needs to
## be built, so the dry terrain meets the water plane with no gap.
func _quad_is_submerged(x: int, z: int) -> bool:
	var corners: Array[Vector2i] = [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1)]
	for corner in corners:
		if _height_at(corner.x, corner.y) >= water_level_y:
			return false
	return true


func _add_triangle(surface: SurfaceTool, corners: Array[Vector2i]) -> void:
	for corner in corners:
		var value: float = _field.value_at(corner.x, corner.y)
		surface.set_color(Color(value, 0.0, 0.0, 1.0))
		surface.add_vertex(Vector3(corner.x * cell_size, _shaped_height(value), corner.y * cell_size))


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
	_terrain_material = _build_terrain_material()
	_water_material = _make_flat_material(_WATER_COLOUR)
	_trunk_material = _make_flat_material(Color(0.36, 0.24, 0.16))
	_canopy_material = _make_flat_material(Color(0.20, 0.52, 0.31))


func _build_terrain_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = _TERRAIN_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	var thresholds: PackedFloat32Array = PackedFloat32Array()
	for band in _bands:
		thresholds.append(band["threshold"])
	material.set_shader_parameter("band_thresholds", thresholds)
	material.set_shader_parameter("band_colours", _BAND_TOP_COLOURS)
	material.set_shader_parameter("peak_colour", _PEAK_COLOUR)
	return material


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


## Frees the previous tree nodes and rebuilds them from _field. Water,
## lighting and camera are seed-independent and untouched.
func _rebuild_trees() -> void:
	for instance in [_trunk_instance, _canopy_instance]:
		if instance != null:
			instance.queue_free()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _current_seed
	var ground_points: Array[Vector3] = []
	var max_attempts: int = tree_count * 50
	var attempts: int = 0
	while ground_points.size() < tree_count and attempts < max_attempts:
		attempts += 1
		var x: int = rng.randi() % (grid_cells - 1)
		var z: int = rng.randi() % (grid_cells - 1)
		var height: float = _height_at(x, z)
		if height < water_level_y:
			continue
		ground_points.append(Vector3(x * cell_size, height, z * cell_size))

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
	layer.name = "TerrainSmoothProbeDebugLayer"
	add_child(layer)

	_info_label = Label.new()
	_info_label.name = "TerrainSmoothProbeInfo"
	_info_label.position = Vector2(16, 16)
	_info_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_info_label.add_theme_constant_override("shadow_offset_x", 1)
	_info_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_info_label)
