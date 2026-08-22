extends GutTest
## Tests for systems/house.gd (issue #17's Housing data slice, extended by
## issue #30's real `position`). No scene tree involved — House is plain
## RefCounted data, mirroring test_location.gd's Seam 1 test conventions.
## Explicitly NOT testing any assignment/construction logic — neither
## issue #17 nor #30 ships any.


func test_house_defaults_capacity_to_a_value_within_the_stated_range() -> void:
	var house := House.new()

	assert_true(house.capacity >= House.MIN_CAPACITY)
	assert_true(house.capacity <= House.MAX_CAPACITY)


func test_house_accepts_an_explicit_capacity() -> void:
	var house := House.new(6)

	assert_eq(house.capacity, 6)


# --- position (issue #30) ---


func test_house_defaults_position_to_the_origin() -> void:
	var house := House.new()

	assert_eq(house.position, Vector3.ZERO)


func test_house_accepts_an_explicit_position() -> void:
	var house := House.new(House.DEFAULT_CAPACITY, Vector3(3, 0, -7))

	assert_eq(house.position, Vector3(3, 0, -7))


func test_house_position_is_settable_directly() -> void:
	var house := House.new()

	house.position = Vector3(1, 0, 2)

	assert_eq(house.position, Vector3(1, 0, 2))
