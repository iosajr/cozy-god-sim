extends GutTest

const TEST_PATH := "res://tests/tmp_test_renowned_interaction_decision.tres"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH + ".uid"):
		DirAccess.remove_absolute(TEST_PATH + ".uid")


func test_asks_model_when_nothing_cached() -> void:
	var memory := RenownedThoughtMemory.new(TEST_PATH)
	assert_eq(
		RenownedInteractionDecision.decide(memory, "task=eat|mood=fine"), RenownedInteractionDecision.ACTION_ASK_MODEL
	)


func test_uses_cached_when_a_matching_entry_exists() -> void:
	var memory := RenownedThoughtMemory.new(TEST_PATH)
	memory.remember("task=eat|mood=fine", "Noor", "A reaction.", "A wish.")

	assert_eq(
		RenownedInteractionDecision.decide(memory, "task=eat|mood=fine"),
		RenownedInteractionDecision.ACTION_USE_CACHED
	)


func test_asks_model_for_a_different_signature_even_with_other_entries_cached() -> void:
	var memory := RenownedThoughtMemory.new(TEST_PATH)
	memory.remember("task=eat|mood=fine", "Noor", "A reaction.", "A wish.")

	assert_eq(
		RenownedInteractionDecision.decide(memory, "task=sleep|mood=tired"),
		RenownedInteractionDecision.ACTION_ASK_MODEL
	)
