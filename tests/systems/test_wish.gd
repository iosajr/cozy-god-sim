extends GutTest
## Tests for systems/wish.gd (issue #4's Wish slice). No scene tree
## involved — Wish is plain RefCounted data, per CONTEXT.md/
## docs/systems-overview.md, mirroring test_village.gd/test_pantheon.gd's
## Seam 1 test conventions.


func test_wish_stores_text_and_domain() -> void:
	var wish := Wish.new("I wish it would rain.", "storms")

	assert_eq(wish.text, "I wish it would rain.")
	assert_eq(wish.domain, "storms")
