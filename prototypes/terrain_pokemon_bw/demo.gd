extends Node3D
## TerrainPokemonBWDemo (PROTOTYPE — throwaway, issue #25)
##
## Assembles one demo layout out of `TerrainGenerator`'s pieces: plateau(s)
## + cliff-skirt, winding path strips, a pond, and dense tree clusters.
## Deliberately built from exported parameters rather than one hardcoded
## arrangement — the point (issue #25 user story 7) is that
## `TerrainGenerator` is a general mechanism; this scene is just one
## configuration exercising it. Change the exports below (or call
## `TerrainGenerator`'s static functions directly from another scene) to
## get a different layout.
##
## Keeps ambient light enabled in the demo scene's own Environment (see
## `demo.tscn`) — see `terrain_generator.gd`'s doc comment on the
## `ambient_light_disabled` false-holes bug from both earlier terrain
## rounds.

@export var ground_size: float = 60.0
@export var plateau_count: int = 1
@export var plateau_radius: float = 12.0
@export var plateau_height: float = 3.0
@export var plateau_skirt_flare: float = 3.5
@export var tree_cluster_count: int = 5
@export var trees_per_cluster: int = 6
@export var cluster_radius: float = 2.2
@export var pond_radius: float = 4.0
@export var seed_value: int = 1

const GRASS_COLOR := Color(0.42, 0.72, 0.32)
const PLATEAU_TOP_COLOR := Color(0.48, 0.78, 0.36)
const CLIFF_COLOR := Color(0.82, 0.5, 0.24)
const PATH_COLOR := Color(0.78, 0.55, 0.3)
const WATER_COLOR := Color(0.22, 0.45, 0.75)

var _rng := RandomNumberGenerator.new()
var _last_stats := {"verts": 0, "tris": 0}
var _plateau_centers: Array[Vector2] = []


func _ready() -> void:
	_rng.seed = seed_value
	_build_ground()
	_build_plateaus()
	_build_paths()
	_build_pond()
	_build_trees()
	_report_stats()


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ground_size, ground_size)
	ground.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GRASS_COLOR
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)


func _build_plateaus() -> void:
	var plateaus := Node3D.new()
	plateaus.name = "Plateaus"
	add_child(plateaus)

	for i in plateau_count:
		var center := GroundScatter.random_ground_position(ground_size * 0.5, _rng)
		var center2 := Vector2(center.x, center.z)
		_plateau_centers.append(center2)
		var polygon := _make_blob_polygon(center2, plateau_radius, 8, 0.28)
		var plateau := TerrainGenerator.build_plateau(
			polygon, plateau_height, -0.15, plateau_skirt_flare, PLATEAU_TOP_COLOR, CLIFF_COLOR
		)
		plateau.name = "Plateau_%d" % i
		plateaus.add_child(plateau)


## Routes the path strip across a corner of open flat ground, away from
## any plateau footprint — a straight top-level cliff and a path strip
## crossing straight through it would read as the same kind of edge,
## which defeats checklist item 2's "NOT full-height terrain cliffs"
## distinction. Kept simple (one strip, on the ground plane's opposite
## side from the plateaus) rather than real path/plateau collision
## avoidance — a reasonable prototype-scope simplification.
func _build_paths() -> void:
	var paths := Node3D.new()
	paths.name = "PathStrips"
	add_child(paths)

	# Routed through the ground corner diagonally opposite the (first)
	# plateau's center, so the zigzag's random jitter has real room to
	# move without ever needing to cross the plateau — simpler and more
	# reliable than pushing individual points clear after the fact (which
	# was tried and made the path hug the cliff's boundary instead of
	# reading as a separate feature).
	var away := Vector2(ground_size * 0.45, ground_size * 0.45)
	if not _plateau_centers.is_empty():
		var toward_plateau := _plateau_centers[0].normalized()
		away = -toward_plateau * ground_size * 0.42
	var from := away.rotated(-0.5)
	var to := away.rotated(0.5)
	var points := TerrainGenerator.random_zigzag(from, to, 9, 4.0, _rng)
	var strip := TerrainGenerator.build_path_strip(points, 1.6, 0.12, PATH_COLOR)
	paths.add_child(strip)


## Sits the pond just above the ground plane (a hair of positive Y, not
## recessed below it) — this project's ground is a single flat
## `PlaneMesh` with no depression cut into it, so a genuinely recessed
## pond mesh would render entirely hidden underneath that opaque plane.
## Implementer's call: picks the "flat... water plane" option from issue
## #25's Implementation Decisions rather than "gently-recessed", since a
## real recess would need the ground mesh itself to be cut/deformed at
## the pond's footprint — out of scope for this prototype's time budget.
func _build_pond() -> void:
	var pond_center := Vector2(-ground_size * 0.28, ground_size * 0.28)
	var pond := TerrainGenerator.build_pond(pond_center, pond_radius, -0.02, WATER_COLOR)
	add_child(pond)


## Rejects cluster centers that land inside (or too close to) any
## plateau's footprint — otherwise a tree cluster can be picked at
## y = 0 underneath/inside a plateau's elevated top, which reads as
## trees floating on the plateau surface from above. A simple
## reject-and-resample against each plateau's bounding circle, not real
## polygon collision — cheap and good enough at this prototype's scale.
func _build_trees() -> void:
	var trees := Node3D.new()
	trees.name = "TreeClusters"
	add_child(trees)

	var attempts := 0
	var placed := 0
	while placed < tree_cluster_count and attempts < tree_cluster_count * 20:
		attempts += 1
		var center3 := GroundScatter.random_ground_position(ground_size, _rng)
		var center2 := Vector2(center3.x, center3.z)
		if _overlaps_any_plateau(center2, cluster_radius):
			continue
		placed += 1
		for t in trees_per_cluster:
			var angle := _rng.randf_range(0.0, TAU)
			var dist := _rng.randf_range(0.0, cluster_radius)
			var pos := center3 + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			trees.add_child(TerrainGenerator.spawn_tree(pos))


func _overlaps_any_plateau(point: Vector2, margin: float) -> bool:
	for center in _plateau_centers:
		if point.distance_to(center) < plateau_radius + margin:
			return true
	return false


## Walks every MeshInstance3D in the scene and sums vertex/triangle
## counts, reported *separately* for the actual terrain geometry
## (ground + plateaus/skirts + path strips + pond — this prototype's own
## job) versus the placeholder tree primitives (reused as-is from
## `world_gen.gd`'s trunk+leaves shape, per issue #25's Implementation
## Decisions — their vertex cost is `CylinderMesh`/`SphereMesh`'s default
## segment resolution, not something this prototype controls or should be
## judged on). Issue #25 user story 8 asks for a number comparable to both
## earlier terrain rounds' figures (~4,614 verts/~1,538 tris for the
## noise-band approach, 396 verts/132 tris for the hand-authored-plateau
## approach) — that comparison is the **Terrain** figure below, not Total.
## Since none of this class's own meshes share vertices between faces
## (flat shading — see `terrain_generator.gd`), vertex count and raw
## face-array length are the same number for the terrain figures.
func _report_stats() -> void:
	var terrain_stats := {"verts": 0, "tris": 0}
	var tree_stats := {"verts": 0, "tris": 0}
	_accumulate_stats(get_node("Ground"), terrain_stats)
	_accumulate_stats(get_node("Plateaus"), terrain_stats)
	_accumulate_stats(get_node("PathStrips"), terrain_stats)
	_accumulate_stats(get_node("Pond"), terrain_stats)
	_accumulate_stats(get_node("TreeClusters"), tree_stats)
	_last_stats = terrain_stats
	print(
		(
			"TerrainPokemonBWDemo stats — Terrain (ground+plateaus+paths+pond): "
			+ "%d verts / %d tris | Trees (placeholder primitives, %d trees): %d verts / %d tris | Total: %d verts / %d tris"
		) % [
			terrain_stats["verts"], terrain_stats["tris"],
			tree_cluster_count * trees_per_cluster,
			tree_stats["verts"], tree_stats["tris"],
			terrain_stats["verts"] + tree_stats["verts"], terrain_stats["tris"] + tree_stats["tris"],
		]
	)


func _accumulate_stats(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var faces: PackedVector3Array = node.mesh.get_faces()
		stats["verts"] += faces.size()
		stats["tris"] += faces.size() / 3
	for child in node.get_children():
		_accumulate_stats(child, stats)


func _make_blob_polygon(center: Vector2, radius: float, sides: int, jitter: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle := (float(i) / sides) * TAU
		var r := radius * (1.0 - jitter * 0.5 + _rng.randf_range(0.0, jitter))
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
