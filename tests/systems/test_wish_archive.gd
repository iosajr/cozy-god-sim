extends GutTest

const TEST_PATH := "res://tests/tmp_test_wish_archive.tres"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH + ".uid"):
		DirAccess.remove_absolute(TEST_PATH + ".uid")


func test_starts_empty() -> void:
	var archive := WishArchive.new(TEST_PATH)
	assert_eq(archive.all_entries().size(), 0)


func test_append_records_villager_name_in_character_and_wish() -> void:
	var archive := WishArchive.new(TEST_PATH)

	var entry := archive.append("Noor", "A brief reaction.", "A ticket-style wish.")

	assert_eq(entry.villager_name, "Noor")
	assert_eq(entry.in_character, "A brief reaction.")
	assert_eq(entry.wish, "A ticket-style wish.")
	assert_gt(entry.saved_at_unix_time, 0)
	assert_eq(archive.all_entries().size(), 1)


func test_append_is_additive_not_replacing() -> void:
	var archive := WishArchive.new(TEST_PATH)

	archive.append("Noor", "Reaction one.", "Wish one.")
	archive.append("Noor", "Reaction two.", "Wish two.")

	assert_eq(archive.all_entries().size(), 2)


func test_persists_and_reloads_across_instances() -> void:
	var writer := WishArchive.new(TEST_PATH)
	writer.append("Noor", "A reaction.", "A wish.")

	var reader := WishArchive.new(TEST_PATH)

	assert_eq(reader.all_entries().size(), 1)
	assert_eq(reader.all_entries()[0].villager_name, "Noor")


func test_a_fresh_path_with_no_file_yet_starts_empty_without_erroring() -> void:
	var archive := WishArchive.new(TEST_PATH)
	assert_eq(archive.all_entries(), ([] as Array[WishArchiveEntry]))
