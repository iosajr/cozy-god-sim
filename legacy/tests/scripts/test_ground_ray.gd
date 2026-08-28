extends GutTest
## Tests for scripts/ground_ray.gd — the pure ray/ground-plane (y = 0)
## intersection seam shared by camera_rig.gd's drag-pan and the
## Presence-light demo (issue #5). No scene tree, no physics query —
## known origin/direction pairs against expected hit points, mirroring
## the plain-data testing style of tests/systems/test_pantheon.gd.


func test_straight_down_ray_hits_the_plane_below_its_origin() -> void:
	var result: Dictionary = GroundRay.intersect_ground_plane(Vector3(0, 10, 0), Vector3(0, -1, 0))

	assert_true(result["hit"])
	assert_eq(result["point"], Vector3(0, 0, 0))


func test_angled_ray_hits_the_plane_at_the_expected_offset_point() -> void:
	var direction := Vector3(1, -1, 0).normalized()

	var result: Dictionary = GroundRay.intersect_ground_plane(Vector3(0, 10, 0), direction)

	assert_true(result["hit"])
	assert_eq(result["point"], Vector3(10, 0, 0))


func test_ray_parallel_to_the_plane_is_a_defined_not_a_hit_not_a_crash_or_nan() -> void:
	var result: Dictionary = GroundRay.intersect_ground_plane(Vector3(0, 5, 0), Vector3(1, 0, 0))

	assert_false(result["hit"])
	assert_eq(result["point"], Vector3.ZERO)


func test_ray_facing_away_from_the_plane_is_a_defined_not_a_hit() -> void:
	var result: Dictionary = GroundRay.intersect_ground_plane(Vector3(0, 5, 0), Vector3(0, 1, 0))

	assert_false(result["hit"])
	assert_eq(result["point"], Vector3.ZERO)
