extends GutTest
## Tests for scripts/mover.gd's pure movement-math seam (issue #14) —
## Mover.advance(), the position-advance/arrival-check function extracted
## so it's testable without the scene tree, mirroring
## test_ground_ray.gd's shape exactly: no Node, no _physics_process, just
## known inputs against expected outputs. The Node-level Mover component
## itself (the _physics_process loop, the `arrived` signal actually
## firing in a live scene) is NOT covered here — issue #14's Testing
## Decisions call that out as real-engine-verification territory, same
## precedent as camera_rig.gd/presence_light.gd having no GUT coverage of
## their own Node-lifecycle behavior.


func test_advance_moves_the_expected_distance_per_delta() -> void:
	var result: Dictionary = Mover.advance(Vector3.ZERO, Vector3(10, 0, 0), 2.0, 1.0, 0.1)

	assert_eq(result["position"], Vector3(2, 0, 0))
	assert_false(result["arrived"])


func test_advance_clamps_to_the_target_rather_than_overshooting() -> void:
	# speed * delta (20.0) would overshoot a target only 5.0 units away.
	var result: Dictionary = Mover.advance(Vector3.ZERO, Vector3(5, 0, 0), 20.0, 1.0, 0.1)

	assert_eq(result["position"], Vector3(5, 0, 0))
	assert_true(result["arrived"])


func test_advance_reports_arrived_once_within_the_threshold() -> void:
	var result: Dictionary = Mover.advance(Vector3(0, 0, 0), Vector3(1, 0, 0), 5.0, 1.0, 0.5)

	# Moves the full 5.0 units this call, clamped to the 1.0-unit-away
	# target, landing well inside the 0.5 threshold.
	assert_eq(result["position"], Vector3(1, 0, 0))
	assert_true(result["arrived"])


func test_advance_does_not_report_arrived_while_still_outside_the_threshold() -> void:
	var result: Dictionary = Mover.advance(Vector3.ZERO, Vector3(100, 0, 0), 1.0, 1.0, 0.5)

	assert_eq(result["position"], Vector3(1, 0, 0))
	assert_false(result["arrived"])


func test_advance_handles_already_at_target_gracefully() -> void:
	var result: Dictionary = Mover.advance(Vector3(4, 0, -2), Vector3(4, 0, -2), 3.0, 1.0, 0.1)

	assert_eq(result["position"], Vector3(4, 0, -2))
	assert_true(result["arrived"])


func test_advance_with_zero_delta_produces_no_movement() -> void:
	var result: Dictionary = Mover.advance(Vector3(1, 0, 1), Vector3(9, 0, 9), 5.0, 0.0, 0.1)

	assert_eq(result["position"], Vector3(1, 0, 1))
	assert_false(result["arrived"])


func test_advance_moves_along_a_diagonal_straight_line_toward_the_target() -> void:
	var direction := Vector3(1, 0, 1).normalized()
	var target := direction * 10.0

	var result: Dictionary = Mover.advance(Vector3.ZERO, target, 1.0, 1.0, 0.1)

	assert_eq(result["position"], direction)
	assert_false(result["arrived"])
