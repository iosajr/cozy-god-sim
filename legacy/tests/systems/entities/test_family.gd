extends GutTest
## Tests for systems/family.gd (issue #40): a small group of Villagers,
## seeded directly at Village.populate() time, optionally carrying a
## farming business bias. Plain RefCounted data, no scene tree involved --
## mirrors test_house.gd's Seam 1 test conventions.


func test_family_defaults_to_no_members() -> void:
	var family := Family.new()

	assert_eq(family.members.size(), 0)


func test_family_defaults_has_farming_bias_to_false() -> void:
	var family := Family.new()

	assert_false(family.has_farming_bias)


func test_family_accepts_an_explicit_farming_bias() -> void:
	var family := Family.new(true)

	assert_true(family.has_farming_bias)


func test_add_member_appends_the_villager_to_members() -> void:
	var family := Family.new()
	var villager := Villager.new("v1", true, "")

	family.add_member(villager)

	assert_eq(family.members.size(), 1)
	assert_same(family.members[0], villager)


func test_add_member_back_points_the_villagers_family_field() -> void:
	var family := Family.new()
	var villager := Villager.new("v1", true, "")

	family.add_member(villager)

	assert_same(villager.family, family)


func test_add_member_supports_multiple_members() -> void:
	var family := Family.new()
	var villager_a := Villager.new("v1", true, "")
	var villager_b := Villager.new("v2", true, "")

	family.add_member(villager_a)
	family.add_member(villager_b)

	assert_eq(family.members.size(), 2)
