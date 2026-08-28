extends GutTest
## Tests for systems/location.gd (issue #8's Known Territory slice). No
## scene tree involved — Location is plain RefCounted data, per
## CONTEXT.md/docs/systems-overview.md, mirroring test_village.gd/
## test_pantheon.gd/test_wish.gd's Seam 1 test conventions.


func test_location_stores_name_and_tags() -> void:
	var tags: Array[String] = ["forest", "water"]

	var location := Location.new("Millbrook Woods", tags)

	assert_eq(location.location_name, "Millbrook Woods")
	assert_eq(location.context_tags, tags)


func test_location_does_not_alias_the_callers_tags_array() -> void:
	# Regression coverage for a bug caught in an earlier attempt at this
	# slice: Location's constructor must duplicate context_tags rather
	# than store the caller's array by reference, so a caller reusing/
	# mutating their tags array across multiple Location.new() calls
	# can't retroactively corrupt an already-created Location.
	var tags: Array[String] = ["forest"]
	var location := Location.new("Millbrook Woods", tags)

	tags.append("mountains")

	assert_eq(location.context_tags, ["forest"])
