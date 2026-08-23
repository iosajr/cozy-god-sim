extends GutTest
## Tests for pairing-formation detection (systems/village_pairing.gd,
## issue #41), driven directly since VillagePairing is a plain
## collaborator, not itself a TaskProvider -- same pattern as
## test_village_farm_labor.gd. Seam 1: no scene tree, Villager.position is
## set directly rather than synced from a spawned body.

const MATURE_AGE := Villager.MIN_REPRODUCTION_AGE


func _make_villager(id: String, sex: Villager.Sex, position: Vector3, age_years: int = MATURE_AGE) -> Villager:
	var villager := Villager.new(id, false, "")
	villager.sex = sex
	villager.position = position
	villager.age_years = age_years
	return villager


# --- defaults ---


func test_defaults_proximity_threshold_to_three() -> void:
	var pairing := VillagePairing.new()

	assert_eq(pairing.proximity_threshold, 3.0)


func test_defaults_pairing_duration_to_thirty_seconds() -> void:
	var pairing := VillagePairing.new()

	assert_eq(pairing.pairing_duration, 30.0)


# --- is_eligible() ---


func test_is_eligible_true_for_an_unpaired_mature_villager() -> void:
	var villager := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)

	assert_true(VillagePairing.is_eligible(villager))


func test_is_eligible_false_below_the_maturity_gate() -> void:
	var villager := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO, MATURE_AGE - 1)

	assert_false(VillagePairing.is_eligible(villager))


func test_is_eligible_false_when_already_paired() -> void:
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3.ZERO)
	a.paired_with = b
	b.paired_with = a

	assert_false(VillagePairing.is_eligible(a))


# --- advance_pairing() forming a pair ---


func test_two_eligible_villagers_who_stay_close_long_enough_pair_up() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b], 10.0)

	assert_same(a.paired_with, b)


func test_pairing_is_mutual() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b], 10.0)

	assert_same(b.paired_with, a)


func test_advance_pairing_does_not_pair_before_duration_elapses() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b], 5.0)

	assert_null(a.paired_with)
	assert_null(b.paired_with)


func test_advance_pairing_accumulates_sustained_proximity_across_multiple_calls() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b], 4.0)
	assert_null(a.paired_with)
	pairing.advance_pairing([a, b], 4.0)
	assert_null(a.paired_with)
	pairing.advance_pairing([a, b], 4.0)
	assert_same(a.paired_with, b)


# --- never-pair cases (acceptance criteria) ---


func test_same_sex_villagers_never_pair_regardless_of_proximity_or_duration() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.MALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b], 100.0)

	assert_null(a.paired_with)
	assert_null(b.paired_with)


func test_an_already_paired_villager_never_pairs_with_a_third() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))
	var c := _make_villager("v3", Villager.Sex.FEMALE, Vector3(2, 0, 0))
	a.paired_with = b
	b.paired_with = a

	pairing.advance_pairing([a, b, c], 100.0)

	assert_same(a.paired_with, b)
	assert_null(c.paired_with)


func test_a_villager_below_the_maturity_gate_never_pairs() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO, MATURE_AGE - 1)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b], 100.0)

	assert_null(a.paired_with)
	assert_null(b.paired_with)


func test_villagers_beyond_the_proximity_threshold_never_accumulate_progress() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	pairing.proximity_threshold = 3.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(10, 0, 0))

	pairing.advance_pairing([a, b], 1000.0)

	assert_null(a.paired_with)
	assert_null(b.paired_with)


func test_progress_resets_once_a_pair_drifts_apart_before_pairing() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	pairing.proximity_threshold = 3.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b], 8.0)
	b.position = Vector3(100, 0, 0)
	pairing.advance_pairing([a, b], 1.0)
	b.position = Vector3(1, 0, 0)
	pairing.advance_pairing([a, b], 8.0)

	# 8.0 + 8.0 == 16.0 would cross pairing_duration if progress had
	# survived the separation; it shouldn't have.
	assert_null(a.paired_with)


func test_advance_pairing_with_three_eligible_villagers_only_pairs_two_of_them() -> void:
	var pairing := VillagePairing.new()
	pairing.pairing_duration = 10.0
	var a := _make_villager("v1", Villager.Sex.MALE, Vector3.ZERO)
	var b := _make_villager("v2", Villager.Sex.FEMALE, Vector3(1, 0, 0))
	var c := _make_villager("v3", Villager.Sex.FEMALE, Vector3(1, 0, 0))

	pairing.advance_pairing([a, b, c], 10.0)

	assert_not_null(a.paired_with)
	assert_true(a.paired_with == b or a.paired_with == c)
	if a.paired_with == b:
		assert_null(c.paired_with)
	else:
		assert_null(b.paired_with)
