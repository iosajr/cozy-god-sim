extends GutTest
## Tests for systems/house.gd (issue #17's Housing data slice). No scene
## tree involved — House is plain RefCounted data, mirroring
## test_location.gd's Seam 1 test conventions. Explicitly NOT testing any
## assignment/construction logic — issue #17 ships none.


func test_house_defaults_capacity_to_a_value_within_the_stated_range() -> void:
	var house := House.new()

	assert_true(house.capacity >= House.MIN_CAPACITY)
	assert_true(house.capacity <= House.MAX_CAPACITY)


func test_house_accepts_an_explicit_capacity() -> void:
	var house := House.new(6)

	assert_eq(house.capacity, 6)
