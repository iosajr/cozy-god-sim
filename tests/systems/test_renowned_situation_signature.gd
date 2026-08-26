extends GutTest
## Tests for systems/renowned_situation_signature.gd -- deriving a
## matchable situation key from tracked Folk state only.


func test_same_tracked_state_derives_the_same_signature() -> void:
	var a := {
		"current_task": "farming",
		"hunger_state": "hungry",
		"tiredness_state": "fine",
		"paired": true,
		"family_has_farming_bias": true,
		"is_renowned": true,
		"has_faith": true,
	}
	var b := a.duplicate()

	assert_eq(RenownedSituationSignature.derive(a), RenownedSituationSignature.derive(b))


func test_differing_task_changes_the_signature() -> void:
	var farming := {"current_task": "farming"}
	var idle := {"current_task": "idle"}

	assert_ne(RenownedSituationSignature.derive(farming), RenownedSituationSignature.derive(idle))


func test_differing_mood_changes_the_signature() -> void:
	var fine := {"hunger_state": "fine", "tiredness_state": "fine"}
	var hungry := {"hunger_state": "hungry", "tiredness_state": "fine"}

	assert_ne(RenownedSituationSignature.derive(fine), RenownedSituationSignature.derive(hungry))


func test_differing_paired_changes_the_signature() -> void:
	var paired := {"paired": true}
	var unpaired := {"paired": false}

	assert_ne(RenownedSituationSignature.derive(paired), RenownedSituationSignature.derive(unpaired))


func test_differing_farming_bias_changes_the_signature() -> void:
	var biased := {"family_has_farming_bias": true}
	var unbiased := {"family_has_farming_bias": false}

	assert_ne(RenownedSituationSignature.derive(biased), RenownedSituationSignature.derive(unbiased))


func test_renowned_and_faith_only_signatures_differ() -> void:
	var renowned := {"is_renowned": true, "has_faith": true}
	var faith_only := {"is_renowned": false, "has_faith": true}

	assert_ne(RenownedSituationSignature.derive(renowned), RenownedSituationSignature.derive(faith_only))


func test_irrelevant_fields_are_ignored() -> void:
	var a := {"name": "Noor", "age_years": 40, "current_wish": "a new gate"}
	var b := {"name": "Different", "age_years": 12, "current_wish": "something else entirely"}

	assert_eq(RenownedSituationSignature.derive(a), RenownedSituationSignature.derive(b))
