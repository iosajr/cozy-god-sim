extends GutTest
## Tests for systems/renowned_thought_memory.gd -- find/remember/persist,
## no live game or network involved (issue #50).

const TEST_PATH := "res://tests/tmp_test_renowned_thought_memory.tres"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH + ".uid"):
		DirAccess.remove_absolute(TEST_PATH + ".uid")


func test_find_returns_null_when_nothing_matches() -> void:
	var memory := RenownedThoughtMemory.new(TEST_PATH)

	assert_null(memory.find("task=farming|mood=content enough|paired=false|farming_bias=false|standing="))


func test_remember_then_find_returns_the_saved_response() -> void:
	var memory := RenownedThoughtMemory.new(TEST_PATH)
	var signature := "task=farming|mood=hungry|paired=true|farming_bias=true|standing=renowned"

	memory.remember(signature, "Noor", "The gate again? Honestly.", "Fix the gate.")
	var found := memory.find(signature)

	assert_not_null(found)
	assert_eq(found.villager_name, "Noor")
	assert_eq(found.in_character, "The gate again? Honestly.")
	assert_eq(found.wish, "Fix the gate.")


func test_remembering_the_same_signature_again_replaces_the_entry() -> void:
	var memory := RenownedThoughtMemory.new(TEST_PATH)
	var signature := "task=farming|mood=fine|paired=false|farming_bias=false|standing="

	memory.remember(signature, "Noor", "First reaction.", "First wish.")
	memory.remember(signature, "Noor", "Second reaction.", "Second wish.")

	assert_eq(memory.all_entries().size(), 1)
	assert_eq(memory.find(signature).in_character, "Second reaction.")


func test_saved_entries_persist_and_reload_on_next_run() -> void:
	var signature := "task=idle|mood=content enough|paired=false|farming_bias=false|standing=faith"
	var writer := RenownedThoughtMemory.new(TEST_PATH)
	writer.remember(signature, "Amaya", "A quiet day.", "A bench by the well.")

	var reader := RenownedThoughtMemory.new(TEST_PATH)
	var found := reader.find(signature)

	assert_not_null(found)
	assert_eq(found.villager_name, "Amaya")
	assert_eq(found.in_character, "A quiet day.")
	assert_eq(found.wish, "A bench by the well.")


func test_a_fresh_store_with_no_saved_file_starts_empty() -> void:
	var memory := RenownedThoughtMemory.new(TEST_PATH)

	assert_eq(memory.all_entries().size(), 0)
