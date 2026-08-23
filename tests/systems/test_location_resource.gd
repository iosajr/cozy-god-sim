extends GutTest
## Tests for systems/location_resource.gd (issue #37's Known Territory
## resource-entry slice). No scene tree involved — LocationResource is
## plain RefCounted data, mirroring test_location.gd's Seam 1 test
## conventions.


func test_stores_position_amount_and_last_observed() -> void:
	var entry := LocationResource.new(Vector3(1, 0, 2), 5, 12.5)

	assert_eq(entry.position, Vector3(1, 0, 2))
	assert_eq(entry.amount, 5)
	assert_eq(entry.last_observed, 12.5)


func test_last_observed_defaults_to_zero() -> void:
	var entry := LocationResource.new(Vector3.ZERO, 5)

	assert_eq(entry.last_observed, 0.0)


# --- collect() ---


func test_collect_drains_up_to_the_requested_amount() -> void:
	var entry := LocationResource.new(Vector3.ZERO, 5)

	var taken := entry.collect(2)

	assert_eq(taken, 2)
	assert_eq(entry.amount, 3)


func test_collect_caps_at_whatever_remains() -> void:
	var entry := LocationResource.new(Vector3.ZERO, 5)

	var taken := entry.collect(20)

	assert_eq(taken, 5)
	assert_eq(entry.amount, 0)


func test_collect_returns_zero_for_a_non_positive_request() -> void:
	var entry := LocationResource.new(Vector3.ZERO, 5)

	var taken := entry.collect(0)

	assert_eq(taken, 0)
	assert_eq(entry.amount, 5)
