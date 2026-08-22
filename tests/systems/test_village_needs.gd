extends GutTest
## Tests for hunger/tiredness escalation (systems/village_needs.gd, driven
## through Village's public methods).


func test_villager_defaults_is_away_and_is_provisioned_to_false() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_false(villager.is_away)
	assert_false(villager.is_provisioned)


func test_villager_defaults_last_eating_outcome_to_empty_string() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.last_eating_outcome, "")


func test_villager_defaults_hunger_state_to_fine() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.hunger_state, Villager.HUNGER_FINE)


func test_villager_defaults_tiredness_state_to_fine() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.tiredness_state, Villager.TIREDNESS_FINE)


# --- check_eating() ---


func test_check_eating_at_village_always_escalates_hunger_regardless_of_food() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	var outcome := village.check_eating(villager)

	assert_eq(outcome, VillageNeeds.EATING_AT_VILLAGE)
	assert_eq(villager.hunger_state, Villager.HUNGER_HUNGRY)


func test_check_eating_provisioned_recovers_hunger() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.is_away = true
	villager.is_provisioned = true
	villager.hunger_state = Villager.HUNGER_HUNGRY

	var outcome := village.check_eating(villager)

	assert_eq(outcome, VillageNeeds.EATING_PROVISIONED)
	assert_eq(villager.hunger_state, Villager.HUNGER_FINE)


func test_check_eating_foraging_unprovisioned_escalates_hunger() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.is_away = true
	villager.is_provisioned = false

	var outcome := village.check_eating(villager)

	assert_eq(outcome, VillageNeeds.EATING_FORAGING)
	assert_eq(villager.hunger_state, Villager.HUNGER_HUNGRY)


func test_check_eating_escalates_hunger_one_stage_at_a_time_up_to_starving() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	village.check_eating(villager)
	assert_eq(villager.hunger_state, Villager.HUNGER_HUNGRY)
	village.check_eating(villager)
	assert_eq(villager.hunger_state, Villager.HUNGER_STARVING)


func test_check_eating_never_escalates_hunger_past_starving() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_STARVING

	village.check_eating(villager)

	assert_eq(villager.hunger_state, Villager.HUNGER_STARVING)


func test_advance_eating_checks_does_not_record_an_outcome_before_the_countdown_elapses() -> void:
	var village := Village.new()
	village.eating_check_interval_min = 100.0
	village.eating_check_interval_max = 100.0
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.advance_eating_checks(1.0)

	assert_eq(villager.last_eating_outcome, "")


func test_advance_eating_checks_records_an_outcome_once_the_countdown_elapses() -> void:
	var village := Village.new()
	village.eating_check_interval_min = 1.0
	village.eating_check_interval_max = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.advance_eating_checks(2.0)

	assert_eq(villager.last_eating_outcome, VillageNeeds.EATING_AT_VILLAGE)


func test_advance_eating_checks_ticks_down_the_countdown_by_delta() -> void:
	var village := Village.new()
	village.eating_check_interval_min = 10.0
	village.eating_check_interval_max = 10.0
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.advance_eating_checks(4.0)
	assert_eq(villager.last_eating_outcome, "")
	village.advance_eating_checks(4.0)
	assert_eq(villager.last_eating_outcome, "")
	village.advance_eating_checks(4.0)
	assert_eq(villager.last_eating_outcome, VillageNeeds.EATING_AT_VILLAGE)


func test_advance_eating_checks_escalates_hunger_on_schedule_even_while_a_villager_has_a_current_task() -> void:
	var village := Village.new()
	village.eating_check_interval_min = 1.0
	village.eating_check_interval_max = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.task_resolving = true

	village.advance_eating_checks(2.0)

	assert_eq(villager.hunger_state, Villager.HUNGER_HUNGRY)


# --- check_sleep() ---


func test_check_sleep_always_escalates_tiredness_regardless_of_location() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	village.check_sleep(villager)

	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


func test_check_sleep_escalates_tiredness_one_stage_at_a_time_up_to_exhausted() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	village.check_sleep(villager)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)
	village.check_sleep(villager)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_EXHAUSTED)


func test_check_sleep_never_escalates_tiredness_past_exhausted() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.tiredness_state = Villager.TIREDNESS_EXHAUSTED

	village.check_sleep(villager)

	assert_eq(villager.tiredness_state, Villager.TIREDNESS_EXHAUSTED)


func test_advance_sleep_checks_does_not_evaluate_before_the_countdown_elapses() -> void:
	var village := Village.new()
	village.sleep_check_interval_min = 100.0
	village.sleep_check_interval_max = 100.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	villager.tiredness_state = Villager.TIREDNESS_TIRED

	village.advance_sleep_checks(1.0)

	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


func test_advance_sleep_checks_evaluates_once_the_countdown_elapses() -> void:
	var village := Village.new()
	village.sleep_check_interval_min = 1.0
	village.sleep_check_interval_max = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]

	village.advance_sleep_checks(2.0)

	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


func test_advance_sleep_checks_escalates_tiredness_on_schedule_even_while_a_villager_has_a_current_task() -> void:
	var village := Village.new()
	village.sleep_check_interval_min = 1.0
	village.sleep_check_interval_max = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	villager.current_task = Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	village.advance_sleep_checks(2.0)

	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)
