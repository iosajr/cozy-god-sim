extends GutTest

func test_empty_log_reports_nothing_notable() -> void:
	var log := VillageEventLog.new()
	assert_eq(log.recent_text(), "(nothing notable yet)")


func test_logged_event_appears_in_recent_text() -> void:
	var log := VillageEventLog.new()
	log.log_event("Noor started a Collect task")
	assert_true(log.recent_text().contains("Noor started a Collect task"))


func test_recent_text_lists_most_recent_first() -> void:
	var log := VillageEventLog.new()
	log.log_event("first event")
	log.log_event("second event")

	var text := log.recent_text()
	assert_true(text.find("second event") < text.find("first event"))


func test_recent_text_stays_under_the_char_cap_however_many_events_are_logged() -> void:
	var log := VillageEventLog.new()
	for i in 500:
		log.log_event("Villager %d did something notable enough to log" % i)

	assert_lt(log.recent_text().length(), VillageEventLog.MAX_CHARS + 100)


func test_only_the_most_recent_events_survive_the_cap() -> void:
	var log := VillageEventLog.new()
	for i in 500:
		log.log_event("event number %d" % i)

	var text := log.recent_text()
	assert_true(text.contains("event number 499"), "the newest event should always fit")
	assert_false(text.contains("event number 0"), "the oldest event should be dropped once capped")
