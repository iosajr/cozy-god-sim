extends GutTest
## Tests for systems/village_state_export.gd -- the JSON-safe snapshot shape
## Request/state_reader.py expects (see Request/README.md's pipeline).


func test_export_village_reports_population_and_one_entry_per_villager() -> void:
	var village := Village.new()
	village.populate(3)

	var state := village.export_state()

	assert_eq(state["population"], 3)
	assert_eq(state["villagers"].size(), 3)


func test_export_villager_carries_identity_and_only_real_fields() -> void:
	var village := Village.new()
	village.populate(1)
	var villager: Villager = village.villagers[0]

	var data: Dictionary = VillageStateExport.export_villager(villager)

	assert_eq(data["name"], villager.villager_name)
	assert_eq(data["age_years"], villager.age_years)
	assert_eq(data["is_farmer"], villager.is_farmer)
	assert_eq(data["has_faith"], villager.has_faith)
	assert_false(data.has("mood"), "mood isn't a tracked field -- don't invent it")
	assert_false(data.has("relationships"), "relationships aren't tracked -- don't invent them")
	assert_false(data.has("recent_memory"), "no memory log exists yet -- don't invent one")


func test_export_villager_reports_current_task_kind_when_assigned() -> void:
	var village := Village.new()
	village.populate(1)
	var villager: Villager = village.villagers[0]
	villager.current_task = Task.new(Task.KIND_SEED, 50.0)

	var data: Dictionary = VillageStateExport.export_villager(villager)

	assert_eq(data["current_task"], Task.KIND_SEED)


func test_export_villager_reports_null_task_and_wish_when_none_active() -> void:
	var village := Village.new()
	village.populate(1)
	var villager: Villager = village.villagers[0]

	var data: Dictionary = VillageStateExport.export_villager(villager)

	assert_eq(data["current_task"], null)
	assert_eq(data["current_wish"], "")


func test_export_villager_reports_wish_text_when_one_is_active() -> void:
	var village := Village.new()
	village.populate(1)
	var villager: Villager = village.villagers[0]
	villager.current_wish = "I wish the harvest holds through winter."

	var data: Dictionary = VillageStateExport.export_villager(villager)

	assert_eq(data["current_wish"], "I wish the harvest holds through winter.")
