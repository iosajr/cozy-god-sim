extends GutTest
## Tests for Reproduce Task candidacy + gestation countdown (systems/
## village_reproduction.gd, issue #42), driven directly since
## VillageReproduction is a plain collaborator, not itself a TaskProvider --
## same pattern as test_village_pairing.gd/test_village_farm_labor.gd.
## Seam 1: no scene tree.


func _paired_villager(id: String, partner_id: String) -> Villager:
	var villager := Villager.new(id, false, "")
	var partner := Villager.new(partner_id, false, "")
	villager.paired_with = partner
	partner.paired_with = villager
	return villager


# --- candidate_for() ---


func test_candidate_for_returns_null_for_an_unpaired_villager() -> void:
	var reproduction := VillageReproduction.new()
	var villager := Villager.new("v1", false, "")

	assert_null(reproduction.candidate_for(villager))


func test_candidate_for_returns_a_reproduce_task_for_the_lexicographically_first_partner() -> void:
	var reproduction := VillageReproduction.new()
	var villager := _paired_villager("v1", "v2")  # "v1" < "v2".

	var task := reproduction.candidate_for(villager)

	assert_not_null(task)
	assert_eq(task.kind, Task.KIND_REPRODUCE)
	assert_eq(task.priority, VillageReproduction.REPRODUCE_PRIORITY)
	assert_false(task.is_must_do())


func test_candidate_for_returns_null_for_the_other_partner_of_the_same_pair() -> void:
	# Gestation is tracked once per pair, not once per Villager -- only one
	# partner is ever offered the Task, so a pair never produces two
	# newborns from a single gestation window. See VillageReproduction's
	# doc comment.
	var reproduction := VillageReproduction.new()
	var villager := _paired_villager("v1", "v2")
	var partner := villager.paired_with

	assert_null(reproduction.candidate_for(partner))


func test_candidate_for_reuses_a_single_task_instance_across_calls() -> void:
	var reproduction := VillageReproduction.new()
	var a := _paired_villager("v1", "v2")
	var b := _paired_villager("v3", "v4")

	var task_a := reproduction.candidate_for(a)
	var task_b := reproduction.candidate_for(b)

	assert_same(task_a, task_b)


# --- begin_gestation()/advance_gestation() ---


func test_advance_gestation_returns_false_before_the_full_duration_elapses() -> void:
	var reproduction := VillageReproduction.new()
	var villager := Villager.new("v1", false, "")
	reproduction.begin_gestation(villager)

	var completed := reproduction.advance_gestation(villager, VillageReproduction.GESTATION_DURATION_SECONDS - 1.0)

	assert_false(completed)


func test_advance_gestation_returns_true_once_the_full_duration_elapses() -> void:
	var reproduction := VillageReproduction.new()
	var villager := Villager.new("v1", false, "")
	reproduction.begin_gestation(villager)

	var completed := reproduction.advance_gestation(villager, VillageReproduction.GESTATION_DURATION_SECONDS)

	assert_true(completed)


func test_advance_gestation_accumulates_across_multiple_calls() -> void:
	var reproduction := VillageReproduction.new()
	var villager := Villager.new("v1", false, "")
	reproduction.begin_gestation(villager)
	var half := VillageReproduction.GESTATION_DURATION_SECONDS / 2.0

	assert_false(reproduction.advance_gestation(villager, half))
	assert_true(reproduction.advance_gestation(villager, half))


func test_advance_gestation_without_begin_gestation_is_a_noop() -> void:
	var reproduction := VillageReproduction.new()
	var villager := Villager.new("v1", false, "")

	var completed := reproduction.advance_gestation(villager, 1000.0)

	assert_false(completed)


func test_advance_gestation_is_tracked_per_villager() -> void:
	var reproduction := VillageReproduction.new()
	var a := Villager.new("v1", false, "")
	var b := Villager.new("v2", false, "")
	reproduction.begin_gestation(a)

	var b_completed := reproduction.advance_gestation(b, VillageReproduction.GESTATION_DURATION_SECONDS)

	assert_false(b_completed)


# --- release() ---


func test_release_clears_in_progress_gestation() -> void:
	var reproduction := VillageReproduction.new()
	var villager := Villager.new("v1", false, "")
	reproduction.begin_gestation(villager)
	reproduction.advance_gestation(villager, VillageReproduction.GESTATION_DURATION_SECONDS - 1.0)

	reproduction.release(villager)

	# No gestation in progress any more -- same "hasn't begun" no-op as
	# advance_gestation_without_begin_gestation above.
	assert_false(reproduction.advance_gestation(villager, 0.5))
