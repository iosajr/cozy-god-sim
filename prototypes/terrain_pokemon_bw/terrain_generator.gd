class_name TerrainGenerator
extends RefCounted
## TerrainGenerator (PROTOTYPE — throwaway, issue #25)
##
## Builds Pokémon Black/White-style terrain pieces: elevated flat plateaus
## meeting lower ground via a cliff-skirt, bordered path strips, and a
## pond. A **general, reusable mechanism**, not a fixed scene — every
## piece here is parametrized (footprint polygon, height, color, ...) so
## callers can compose varied layouts, per issue #25's user story 7.
##
## Geometry approach for the plateau/skirt (re-derived from the reverted
## `terrain_plateaus` prototype's description in project memory, since its
## code itself didn't survive the revert — see issue #25's Implementation
## Decisions): a hand-authored flat top polygon, plus a separate skirt
## whose base edge *flares outward* past the top edge. The flare means the
## skirt overlaps whatever ground it's meeting rather than depending on
## exact shared-edge topology — gaps/winding bugs are avoided by
## construction, not by careful edge-matching.
##
## Known pitfalls from both earlier terrain rounds (project memory, not
## re-derived from scratch — see issue #25's Further Notes):
## 1. Winding-order bugs backface-culled top faces. Sidestepped here by
##    setting `cull_mode = CULL_DISABLED` on every material this class
##    hands out, regardless of triangle winding.
## 2. `ambient_light_disabled` made shadow-angled faces render as false
##    "holes." Not this class's call to make (it doesn't own the
##    Environment) — flagged here so callers keep ambient light enabled.
## 3. Unconditional corner-chamfering left holes at same-band interior
##    vertices. Not attempted here at all — no chamfering, just flat
##    polygon tops + flared skirts.
##
## Flat/toon-leaning shading: every triangle gets its own hard-edged
## normal (vertices are never shared between faces — see `_add_tri()`),
## giving a faceted, low-poly look under `StandardMaterial3D`'s ordinary
## per-pixel PBR lighting. This is *not* a real cel-shader with hard light
## bands — an implementer's-call simplification given the prototype's time
## budget; a custom toon shader would sharpen the effect further.


## Builds one plateau + its cliff-skirt as a `Node3D` with two
## `MeshInstance3D` children ("Top", "Skirt"). `polygon` is the plateau's
## XZ footprint (any simple polygon, convex or not — triangulated via
## `Geometry2D.triangulate_polygon()`). `height` is the top's Y. `base_y`
## is where the skirt's flared base sits (should be at or slightly below
## the surrounding ground's own Y, so it visibly undercuts rather than
## floating). `flare` is how far outward (world units) the skirt's base
## extends past the top edge.
static func build_plateau(
	polygon: PackedVector2Array,
	height: float,
	base_y: float,
	flare: float,
	top_color: Color,
	skirt_color: Color
) -> Node3D:
	var container := Node3D.new()
	container.name = "Plateau"

	var top_inst := MeshInstance3D.new()
	top_inst.name = "Top"
	top_inst.mesh = _build_top_mesh(polygon, height)
	top_inst.material_override = _flat_material(top_color)
	container.add_child(top_inst)

	var skirt_inst := MeshInstance3D.new()
	skirt_inst.name = "Skirt"
	skirt_inst.mesh = _build_skirt_mesh(polygon, height, base_y, flare)
	skirt_inst.material_override = _flat_material(skirt_color)
	container.add_child(skirt_inst)

	return container


## Builds a thin, raised, bordered path strip following `points` (an XZ
## polyline — winding/zigzagging it is the caller's job, see
## `random_zigzag()` below). `width` is the strip's total width, `height`
## how far above the ground plane it sits (kept small — this reads as a
## garden-planter/walking-path border, per issue #25's checklist item 2,
## NOT a full-height terrain cliff). Returns a single `MeshInstance3D`.
static func build_path_strip(points: PackedVector2Array, width: float, height: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * (width * 0.5)

		var top_l := Vector3(a.x + side.x, height, a.y + side.y)
		var top_r := Vector3(a.x - side.x, height, a.y - side.y)
		var top_l2 := Vector3(b.x + side.x, height, b.y + side.y)
		var top_r2 := Vector3(b.x - side.x, height, b.y - side.y)

		# Top face of the strip segment.
		_add_tri(st, top_l, top_r, top_r2, color)
		_add_tri(st, top_l, top_r2, top_l2, color)

		# Low side walls down to the ground, so the strip reads as a
		# raised border rather than a flat decal floating above the grass.
		var base_l := Vector3(a.x + side.x, 0.0, a.y + side.y)
		var base_l2 := Vector3(b.x + side.x, 0.0, b.y + side.y)
		var base_r := Vector3(a.x - side.x, 0.0, a.y - side.y)
		var base_r2 := Vector3(b.x - side.x, 0.0, b.y - side.y)
		_add_tri(st, top_l, top_l2, base_l2, color)
		_add_tri(st, top_l, base_l2, base_l, color)
		_add_tri(st, top_r, base_r2, top_r2, color)
		_add_tri(st, top_r, base_r, base_r2, color)

	var inst := MeshInstance3D.new()
	inst.name = "PathStrip"
	inst.mesh = st.commit()
	inst.material_override = _flat_material(color)
	return inst


## Builds a simple round-ish pond: a flat disc, gently recessed
## (`depth` below the ground plane), with a distinct water color. No
## wave/reflection shader per issue #25's Implementation Decisions — a
## prototype-appropriate flat color plane is enough for this checklist item.
static func build_pond(center: Vector2, radius: float, depth: float, color: Color, segments: int = 16) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mid := Vector3(center.x, -depth, center.y)
	for i in range(segments):
		var a0 := (float(i) / segments) * TAU
		var a1 := (float(i + 1) / segments) * TAU
		var p0 := Vector3(center.x + cos(a0) * radius, -depth, center.y + sin(a0) * radius)
		var p1 := Vector3(center.x + cos(a1) * radius, -depth, center.y + sin(a1) * radius)
		_add_tri(st, mid, p1, p0, color)

	var inst := MeshInstance3D.new()
	inst.name = "Pond"
	inst.mesh = st.commit()
	inst.material_override = _flat_material(color)
	return inst


## Picks `cluster_count` cluster-center points (reusing
## `GroundScatter.random_ground_position()` for the centers themselves,
## per issue #25's Implementation Decisions) and scatters
## `trees_per_cluster` tree positions within `cluster_radius` of each
## center — dense clumps with visible gaps between them, rather than
## `world_gen.gd`'s current fully-independent per-tree scatter. Returns a
## flat array of Vector3 tree positions (y = 0); building the actual tree
## meshes is the caller's job (see `spawn_tree()` below), same split as
## `GroundScatter` leaving mesh-building to its callers.
static func cluster_tree_positions(
	ground_size: float,
	cluster_count: int,
	trees_per_cluster: int,
	cluster_radius: float,
	rng: RandomNumberGenerator
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for c in cluster_count:
		var center := GroundScatter.random_ground_position(ground_size, rng)
		for t in trees_per_cluster:
			var angle := rng.randf_range(0.0, TAU)
			var dist := rng.randf_range(0.0, cluster_radius)
			positions.append(center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist))
	return positions


## A minimal placeholder tree — reuses `world_gen.gd`'s existing
## trunk+leaves primitive shape (issue #25's Implementation Decisions: new
## tree art is explicitly out of scope for this prototype), recolored
## toward flatter, more saturated tones to match the reference's color
## blocking.
static func spawn_tree(position: Vector3) -> Node3D:
	var tree := Node3D.new()
	tree.position = position

	# Low segment counts on purpose — Godot's PrimitiveMesh defaults
	# (64 radial segments) are needlessly heavy for a low-poly, flat-shaded
	# placeholder tree and dominated this prototype's total vertex count
	# (~15k verts/tree at defaults) without being this prototype's own
	# geometry to account for — see `demo.gd`'s `_report_stats()` doc
	# comment on why tree cost is reported separately from terrain cost.
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 1.6
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	trunk.mesh = trunk_mesh
	trunk.material_override = _flat_material(Color(0.45, 0.3, 0.16))
	trunk.position.y = 0.8
	tree.add_child(trunk)

	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()
	leaves_mesh.radius = 1.2
	leaves_mesh.height = 2.2
	leaves_mesh.radial_segments = 8
	leaves_mesh.rings = 6
	leaves.mesh = leaves_mesh
	leaves.material_override = _flat_material(Color(0.3, 0.68, 0.24))
	leaves.position.y = 2.1
	tree.add_child(leaves)

	return tree


## Generates a hand-random zigzagging polyline between two XZ points —
## the "winding, bordered ground-strip path" shape from issue #25's
## checklist item 2. Not a real pathfinding walk, just enough randomness
## to read as organic rather than a straight line.
static func random_zigzag(from: Vector2, to: Vector2, segments: int, jitter: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var dir := (to - from)
	var perp := Vector2(-dir.y, dir.x).normalized()
	points.append(from)
	for i in range(1, segments):
		var t := float(i) / segments
		var base := from.lerp(to, t)
		var offset := perp * rng.randf_range(-jitter, jitter)
		points.append(base + offset)
	points.append(to)
	return points


static func _build_top_mesh(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, indices.size(), 3):
		var a := polygon[indices[i]]
		var b := polygon[indices[i + 1]]
		var c := polygon[indices[i + 2]]
		_add_tri(
			st,
			Vector3(a.x, height, a.y),
			Vector3(b.x, height, b.y),
			Vector3(c.x, height, c.y),
			Color.WHITE
		)
	return st.commit()


static func _build_skirt_mesh(polygon: PackedVector2Array, height: float, base_y: float, flare: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var centroid := Vector2.ZERO
	for p in polygon:
		centroid += p
	centroid /= polygon.size()

	var n := polygon.size()
	for i in range(n):
		var p1 := polygon[i]
		var p2 := polygon[(i + 1) % n]
		var out1 := p1 + (p1 - centroid).normalized() * flare
		var out2 := p2 + (p2 - centroid).normalized() * flare

		var top1 := Vector3(p1.x, height, p1.y)
		var top2 := Vector3(p2.x, height, p2.y)
		var bot1 := Vector3(out1.x, base_y, out1.y)
		var bot2 := Vector3(out2.x, base_y, out2.y)

		_add_tri(st, top1, bot1, bot2, Color.WHITE)
		_add_tri(st, top1, bot2, top2, Color.WHITE)

	return st.commit()


## Adds one triangle with a shared, hard-edged face normal (never
## smoothed with neighboring triangles — see the class doc comment's
## flat/toon-shading note) and a per-vertex color, in case a caller wants
## vertex-color-driven materials later.
static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(b)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(c)


## Every material this class hands out is `CULL_DISABLED` — sidesteps the
## winding-order backface-culling bug both earlier terrain rounds hit
## (issue #25's Further Notes) entirely, rather than needing exactly
## correct winding on every triangle above.
static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
