extends GutTest
## Tests for systems/god.gd and systems/pantheon.gd (the confirmed seam for
## issue #3). No scene tree involved — God/Pantheon are plain RefCounted
## data, per CONTEXT.md/docs/systems-overview.md, mirroring the
## Village/Villager slice's Seam 1 test conventions (test_village.gd).


func test_pantheon_constructs_with_full_roster() -> void:
	var pantheon := Pantheon.new()

	assert_eq(pantheon.gods.size(), 5)


func test_get_by_domain_returns_the_god_for_a_known_domain() -> void:
	var pantheon := Pantheon.new()

	var death_god: God = pantheon.get_by_domain("dying")

	assert_not_null(death_god)
	assert_eq(death_god.domain, "dying")


func test_get_by_domain_returns_null_for_an_unknown_domain() -> void:
	var pantheon := Pantheon.new()

	var result: God = pantheon.get_by_domain("this-domain-does-not-exist")

	assert_null(result)


func test_no_two_gods_in_the_roster_share_a_domain() -> void:
	var pantheon := Pantheon.new()

	var seen_domains: Dictionary = {}
	for god: God in pantheon.gods:
		assert_false(seen_domains.has(god.domain), "Duplicate domain: %s" % god.domain)
		seen_domains[god.domain] = true


func test_every_god_in_the_roster_has_non_empty_fields() -> void:
	var pantheon := Pantheon.new()

	for god: God in pantheon.gods:
		assert_false(god.god_name.is_empty())
		assert_false(god.domain.is_empty())
		assert_false(god.flavor.is_empty())


func test_roster_includes_at_least_one_cosmic_and_one_petty_god() -> void:
	# Per CONTEXT.md's range: a Death-like cosmic figure down to something
	# like the Rat God who loves cheese. Domain names are the stable check;
	# flavor text is prose and shouldn't be pattern-matched by tests.
	var pantheon := Pantheon.new()

	assert_not_null(pantheon.get_by_domain("dying"))
	assert_not_null(pantheon.get_by_domain("vermin"))
