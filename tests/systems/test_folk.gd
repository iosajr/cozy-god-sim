extends GutTest
## Tests for systems/folk.gd (Seam 1, issue #11) — the shared Folk base
## extracted out of Villager. Villager's own Favored/Renown tests (issues
## #6/#7, tests/systems/test_village.gd) already re-verify this exact
## behavior through Villager after the extraction; these tests exercise
## Folk directly, and tests/systems/test_sheep.gd exercises it again
## through Sheep with its own (higher) Renown threshold — see issue #11's
## Testing Decisions.
##
## Also covers Folk.advance() (issue #21's Ageing slice) — its
## year-crossing logic, tested the same in-isolation way per issue #21's
## Testing Decisions.


func test_folk_defaults_favored_to_zero() -> void:
	var folk := Folk.new("f1", true)

	assert_eq(folk.favored, 0.0)


func test_folk_defaults_is_renowned_to_false() -> void:
	var folk := Folk.new("f1", true)

	assert_false(folk.is_renowned)


func test_gain_favored_accumulates_over_repeated_calls() -> void:
	var folk := Folk.new("f1", true)

	folk.gain_favored(0.5, 100.0)
	folk.gain_favored(0.5, 100.0)
	folk.gain_favored(0.25, 100.0)

	assert_eq(folk.favored, 1.25)


func test_gain_favored_grants_faith_to_a_skeptic_who_crosses_the_threshold() -> void:
	var folk := Folk.new("f1", false)

	folk.gain_favored(10.0, 10.0)

	assert_true(folk.has_faith)


func test_gain_favored_leaves_a_skeptic_faithless_below_the_threshold() -> void:
	var folk := Folk.new("f1", false)

	folk.gain_favored(5.0, 10.0)

	assert_false(folk.has_faith)


func test_gain_favored_grants_renown_to_a_faithful_folk_who_crosses_the_renown_threshold() -> void:
	var folk := Folk.new("f1", true)

	folk.gain_favored(10.0, 5.0, 10.0)

	assert_true(folk.is_renowned)


func test_gain_favored_leaves_a_faithful_folk_unrenowned_below_the_renown_threshold() -> void:
	var folk := Folk.new("f1", true)

	folk.gain_favored(5.0, 5.0, 10.0)

	assert_false(folk.is_renowned)


func test_gain_favored_never_grants_renown_to_a_skeptic_even_past_the_renown_threshold() -> void:
	var folk := Folk.new("f1", false)

	folk.gain_favored(10.0, 100.0, 10.0)

	assert_false(folk.is_renowned)


func test_gain_favored_can_grant_faith_and_renown_in_the_same_call_that_crosses_both_thresholds() -> void:
	var folk := Folk.new("f1", false)

	folk.gain_favored(10.0, 5.0, 10.0)

	assert_true(folk.has_faith)
	assert_true(folk.is_renowned)


func test_villager_gain_favored_still_uses_folks_shared_implementation() -> void:
	# Regression guard for issue #11's User Story 2: Villager no longer
	# defines gain_favored() itself, it inherits Folk's.
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(10.0, 10.0)

	assert_true(villager.has_faith)
	assert_eq(villager.favored, 10.0)


func test_folk_defaults_age_years_to_zero() -> void:
	var folk := Folk.new("f1", true)

	assert_eq(folk.age_years, 0)


func test_advance_below_seconds_per_year_does_not_age_a_year() -> void:
	var folk := Folk.new("f1", true)

	folk.advance(5.0, 10.0)

	assert_eq(folk.age_years, 0)


func test_advance_past_seconds_per_year_ages_exactly_one_year() -> void:
	var folk := Folk.new("f1", true)

	folk.advance(12.0, 10.0)

	assert_eq(folk.age_years, 1)


func test_advance_carries_the_remainder_forward_across_calls() -> void:
	# 7.0 + 7.0 == 14.0, past a seconds_per_year of 10.0 by 4.0 — the
	# remainder should carry forward rather than reset to 0, so a second
	# small advance() shortly after a crossing still accumulates correctly.
	var folk := Folk.new("f1", true)

	folk.advance(7.0, 10.0)
	folk.advance(7.0, 10.0)

	assert_eq(folk.age_years, 1)


func test_advance_ages_multiple_years_across_repeated_calls() -> void:
	var folk := Folk.new("f1", true)

	folk.advance(10.0, 10.0)
	folk.advance(10.0, 10.0)
	folk.advance(10.0, 10.0)

	assert_eq(folk.age_years, 3)


func test_advance_uses_default_seconds_per_year_when_not_overridden() -> void:
	var folk := Folk.new("f1", true)

	folk.advance(Folk.DEFAULT_SECONDS_PER_YEAR)

	assert_eq(folk.age_years, 1)


func test_advance_does_not_affect_favored_or_faith() -> void:
	# Folk.advance() is ageing-only bookkeeping (issue #21) — it must not
	# touch gain_favored()'s Favored/Faith/Renown state.
	var folk := Folk.new("f1", false)

	folk.advance(Folk.DEFAULT_SECONDS_PER_YEAR)

	assert_eq(folk.favored, 0.0)
	assert_false(folk.has_faith)
	assert_false(folk.is_renowned)
