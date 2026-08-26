extends GutTest
## Tests for systems/villager_ideas_prompt.gd -- building villager-ideas's
## user-turn prompt from real, tracked fields only.


func test_mood_falls_back_when_nothing_notable() -> void:
	var villager := {"hunger_state": "fine", "tiredness_state": "fine"}

	assert_eq(VillagerIdeasPrompt.mood_from_state(villager), "content enough")


func test_mood_reports_hunger_and_tiredness_when_not_fine() -> void:
	var villager := {"hunger_state": "hungry", "tiredness_state": "exhausted"}

	assert_eq(VillagerIdeasPrompt.mood_from_state(villager), "hungry, exhausted")


func test_role_reflects_farming_interest_not_a_job_title() -> void:
	assert_eq(VillagerIdeasPrompt.role_from_state({"is_farmer": true}), "villager with a farming interest")
	assert_eq(VillagerIdeasPrompt.role_from_state({"is_farmer": false}), "villager")


func test_queued_block_reports_placeholder_when_empty() -> void:
	var empty: Array[String] = []
	assert_eq(VillagerIdeasPrompt.queued_block(empty), "- (nothing queued yet)")


func test_queued_block_lists_each_title() -> void:
	var titles: Array[String] = ["Fix the gate", "Add a well bucket"]
	assert_eq(VillagerIdeasPrompt.queued_block(titles), "- Fix the gate\n- Add a well bucket")


func test_build_includes_name_and_systems_summary_and_queued_titles() -> void:
	var villager := {"name": "Noor", "age_years": 35, "is_farmer": true}
	var village := {"population": 6}
	var titles: Array[String] = ["Fix the gate"]

	var prompt := VillagerIdeasPrompt.build(villager, village, "Villages have Houses.", titles)

	assert_true(prompt.contains("Villager: Noor"))
	assert_true(prompt.contains("Villages have Houses."))
	assert_true(prompt.contains("- Fix the gate"))
