extends GutTest
## Tests for systems/sheep.gd (Seam 1, issue #11) — the first animal Folk
## type. Only covers what's genuinely Sheep-specific: its own (higher)
## Renown threshold via the shared Folk.gain_favored(), and the grass-
## contentment check. test_folk.gd already covers gain_favored()'s shared
## accumulation/Faith-unlock mechanism directly; no need to re-derive it
## here (issue #11's Testing Decisions).


func test_sheep_defaults_is_content_to_false() -> void:
	var sheep := Sheep.new("s1", false)

	assert_false(sheep.is_content)


func test_check_contentment_reflects_near_grass_true() -> void:
	var sheep := Sheep.new("s1", false)

	sheep.check_contentment(true)

	assert_true(sheep.is_content)


func test_check_contentment_reflects_near_grass_false() -> void:
	var sheep := Sheep.new("s1", false)
	sheep.check_contentment(true)

	sheep.check_contentment(false)

	assert_false(sheep.is_content)


func test_sheep_renown_threshold_is_higher_than_villagers() -> void:
	assert_gt(Sheep.RENOWN_THRESHOLD, Folk.DEFAULT_RENOWN_THRESHOLD)


func test_gain_favored_grants_faith_to_a_skeptic_sheep_who_crosses_the_shared_threshold() -> void:
	var sheep := Sheep.new("s1", false)

	sheep.gain_favored(Folk.DEFAULT_FAITH_THRESHOLD, Folk.DEFAULT_FAITH_THRESHOLD, Sheep.RENOWN_THRESHOLD)

	assert_true(sheep.has_faith)


func test_gain_favored_grants_renown_to_a_faithful_sheep_who_crosses_its_own_higher_renown_threshold() -> void:
	var sheep := Sheep.new("s1", true)

	sheep.gain_favored(Sheep.RENOWN_THRESHOLD, Folk.DEFAULT_FAITH_THRESHOLD, Sheep.RENOWN_THRESHOLD)

	assert_true(sheep.is_renowned)


func test_gain_favored_leaves_a_faithful_sheep_unrenowned_at_a_villagers_renown_threshold() -> void:
	# The same favored amount that would Renown a Villager must NOT be
	# enough for a Sheep — that's the whole point of User Story 6.
	var sheep := Sheep.new("s1", true)

	sheep.gain_favored(Folk.DEFAULT_RENOWN_THRESHOLD, Folk.DEFAULT_FAITH_THRESHOLD, Sheep.RENOWN_THRESHOLD)

	assert_false(sheep.is_renowned)
