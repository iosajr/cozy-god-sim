extends GutTest
## Tests for prototypes/terrain_pokemon_bw/terrain_generator.gd (issue #25).
##
## Per the issue's own Testing Decisions: "does this look like the
## reference" is a real-screenshot visual judgment call, not testable
## logic — see prototypes/terrain_pokemon_bw/take_screenshots.gd and the
## session's final summary for that half. This file covers what GUT
## *can* verify headlessly: generation completes without error, and the
## resulting geometry has the numeric shape you'd expect (vertex/triangle
## counts, no degenerate empty meshes).


func test_build_plateau_returns_top_and_skirt_mesh_instances() -> void:
	var polygon := PackedVector2Array([
		Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5),
	])

	var plateau := TerrainGenerator.build_plateau(polygon, 3.0, -0.1, 2.0, Color.GREEN, Color.ORANGE)

	assert_not_null(plateau.get_node("Top"))
	assert_not_null(plateau.get_node("Skirt"))
	plateau.free()


func test_build_plateau_top_face_vertex_count_matches_triangulated_quad() -> void:
	# A 4-vertex convex polygon triangulates to 2 triangles = 6 verts
	# (no shared vertices between faces — see terrain_generator.gd's flat-
	# shading doc comment).
	var polygon := PackedVector2Array([
		Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5),
	])

	var plateau := TerrainGenerator.build_plateau(polygon, 3.0, -0.1, 2.0, Color.GREEN, Color.ORANGE)
	var top: MeshInstance3D = plateau.get_node("Top")

	assert_eq(top.mesh.get_faces().size(), 6)
	plateau.free()


func test_build_plateau_skirt_vertex_count_matches_edge_count() -> void:
	# One quad (2 tris = 6 verts) per polygon edge; a 4-vertex polygon has
	# 4 edges.
	var polygon := PackedVector2Array([
		Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5),
	])

	var plateau := TerrainGenerator.build_plateau(polygon, 3.0, -0.1, 2.0, Color.GREEN, Color.ORANGE)
	var skirt: MeshInstance3D = plateau.get_node("Skirt")

	assert_eq(skirt.mesh.get_faces().size(), 4 * 6)
	plateau.free()


func test_build_path_strip_produces_nonempty_mesh() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(5, 2), Vector2(10, 0)])

	var strip := TerrainGenerator.build_path_strip(points, 1.5, 0.1, Color.ORANGE)

	assert_gt(strip.mesh.get_faces().size(), 0)
	strip.free()


func test_build_pond_produces_a_mesh_with_segments_times_3_verts() -> void:
	var pond := TerrainGenerator.build_pond(Vector2.ZERO, 4.0, 0.2, Color.BLUE, 12)

	assert_eq(pond.mesh.get_faces().size(), 12 * 3)
	pond.free()


func test_cluster_tree_positions_returns_cluster_count_times_trees_per_cluster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var positions := TerrainGenerator.cluster_tree_positions(60.0, 5, 6, 2.0, rng)

	assert_eq(positions.size(), 30)


func test_cluster_tree_positions_is_deterministic_for_a_given_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 7
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 7

	var positions_a := TerrainGenerator.cluster_tree_positions(60.0, 3, 4, 2.0, rng_a)
	var positions_b := TerrainGenerator.cluster_tree_positions(60.0, 3, 4, 2.0, rng_b)

	for i in positions_a.size():
		assert_eq(positions_a[i], positions_b[i])


func test_random_zigzag_starts_and_ends_at_given_points() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	var points := TerrainGenerator.random_zigzag(Vector2(-10, 0), Vector2(10, 0), 5, 2.0, rng)

	assert_eq(points[0], Vector2(-10, 0))
	assert_eq(points[points.size() - 1], Vector2(10, 0))


func test_spawn_tree_returns_a_node_with_trunk_and_leaves() -> void:
	var tree := TerrainGenerator.spawn_tree(Vector3(1, 0, 2))

	assert_eq(tree.get_child_count(), 2)
	assert_eq(tree.position, Vector3(1, 0, 2))
	tree.free()
