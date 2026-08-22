extends GutTest
## Tests for Task assignment/execution/idle wandering (systems/
## village_tasks.gd, driven through Village's public methods).


func test_villager_defaults_position_to_zero() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.position, Vector3.ZERO)


func test_villager_defaults_current_task_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.current_task)


func test_villager_defaults_task_resolving_to_false() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_false(villager.task_resolving)


# --- query_next_task() ---


func test_query_next_task_returns_a_real_idle_task_when_nothing_is_urgent() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	var task := village.query_next_task(villager)

	assert_not_null(task)
	assert_eq(task.kind, Task.KIND_IDLE)
	assert_eq(task.priority, VillageTasks.IDLE_PRIORITY)
	assert_false(task.is_must_do())


func test_idle_priority_is_below_the_lowest_eat_and_sleep_priorities() -> void:
	assert_true(VillageTasks.IDLE_PRIORITY < VillageNeeds.EAT_PRIORITY_HUNGRY)
	assert_true(VillageTasks.IDLE_PRIORITY < VillageNeeds.SLEEP_PRIORITY_TIRED)


func test_query_next_task_prefers_eat_over_idle_when_hungry() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_HUNGRY

	var task := village.query_next_task(villager)

	assert_eq(task.kind, Task.KIND_EAT)


func test_query_next_task_prefers_sleep_over_idle_when_tired() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.tiredness_state = Villager.TIREDNESS_TIRED

	var task := village.query_next_task(villager)

	assert_eq(task.kind, Task.KIND_SLEEP)


func test_query_next_task_returns_an_eat_task_when_hungry() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_HUNGRY

	var task := village.query_next_task(villager)

	assert_not_null(task)
	assert_eq(task.kind, Task.KIND_EAT)
	assert_false(task.is_must_do())


func test_query_next_task_returns_a_must_do_eat_task_when_starving() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_STARVING

	var task := village.query_next_task(villager)

	assert_not_null(task)
	assert_eq(task.kind, Task.KIND_EAT)
	assert_true(task.is_must_do())


func test_query_next_task_returns_a_must_do_sleep_task_when_exhausted() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.tiredness_state = Villager.TIREDNESS_EXHAUSTED

	var task := village.query_next_task(villager)

	assert_not_null(task)
	assert_eq(task.kind, Task.KIND_SLEEP)
	assert_true(task.is_must_do())


func test_query_next_task_returns_the_higher_priority_candidate_when_both_are_urgent() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_STARVING
	villager.tiredness_state = Villager.TIREDNESS_TIRED

	var task := village.query_next_task(villager)

	assert_not_null(task)
	assert_eq(task.kind, Task.KIND_EAT)
	assert_true(task.is_must_do())


func test_query_next_task_reuses_a_single_idle_task_instance_across_calls_and_villagers() -> void:
	var village := Village.new()
	var villager_a := Villager.new("v1", true, "The bread smells almost ready.")
	var villager_b := Villager.new("v2", true, "The bread smells almost ready.")

	var task_a := village.query_next_task(villager_a)
	var task_b := village.query_next_task(villager_b)
	var task_a_again := village.query_next_task(villager_a)

	assert_same(task_a, task_b)
	assert_same(task_a, task_a_again)


# --- should_interrupt() ---


func test_should_interrupt_is_true_when_the_villager_has_no_current_task() -> void:
	var village := Village.new()
	var candidate := Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	assert_true(village.should_interrupt(null, candidate))


func test_should_interrupt_is_false_when_there_is_no_candidate() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	assert_false(village.should_interrupt(current, null))


func test_should_interrupt_is_false_when_candidate_is_not_must_do() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	var candidate := Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	assert_false(village.should_interrupt(current, candidate))


func test_should_interrupt_is_true_when_candidate_is_must_do() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	var candidate := Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_STARVING)

	assert_true(village.should_interrupt(current, candidate))


func test_should_interrupt_is_true_when_current_is_idle_and_candidate_is_a_non_must_do_real_task() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)
	var candidate := Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	assert_true(village.should_interrupt(current, candidate))


func test_should_interrupt_is_false_when_current_and_candidate_are_both_idle() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)
	var candidate := Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)

	assert_false(village.should_interrupt(current, candidate))


# --- advance_task_assignment() ---


func test_advance_task_assignment_assigns_a_task_to_a_free_villager() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_HUNGRY

	var changed := village.advance_task_assignment(villager)

	assert_true(changed)
	assert_not_null(villager.current_task)
	assert_eq(villager.current_task.kind, Task.KIND_EAT)


func test_advance_task_assignment_assigns_an_idle_task_to_a_free_villager_with_nothing_urgent() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	var changed := village.advance_task_assignment(villager)

	assert_true(changed)
	assert_not_null(villager.current_task)
	assert_eq(villager.current_task.kind, Task.KIND_IDLE)


func test_advance_task_assignment_does_not_thrash_a_running_idle_task_every_frame() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	village.advance_task_assignment(villager)
	var first_task := villager.current_task

	var changed := village.advance_task_assignment(villager)

	assert_false(changed)
	assert_same(villager.current_task, first_task)


func test_advance_task_assignment_switches_from_idle_to_a_non_must_do_real_task_immediately() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	village.advance_task_assignment(villager)
	assert_eq(villager.current_task.kind, Task.KIND_IDLE)

	villager.hunger_state = Villager.HUNGER_HUNGRY  # merely-Important, not Must-do.
	var changed := village.advance_task_assignment(villager)

	assert_true(changed)
	assert_eq(villager.current_task.kind, Task.KIND_EAT)
	assert_false(villager.current_task.is_must_do())


func test_advance_task_assignment_leaves_a_running_task_alone_when_the_new_candidate_is_not_must_do() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var running := Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.current_task = running
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	villager.hunger_state = Villager.HUNGER_HUNGRY  # merely-Important, not Must-do.

	var changed := village.advance_task_assignment(villager)

	assert_false(changed)
	assert_same(villager.current_task, running)


func test_advance_task_assignment_interrupts_a_running_task_when_a_must_do_candidate_appears() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	villager.hunger_state = Villager.HUNGER_STARVING  # Must-do.

	var changed := village.advance_task_assignment(villager)

	assert_true(changed)
	assert_not_null(villager.current_task)
	assert_eq(villager.current_task.kind, Task.KIND_EAT)
	assert_true(villager.current_task.is_must_do())


func test_advance_task_assignment_interrupting_a_resolving_sleep_task_resets_task_resolving() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.task_resolving = true
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	villager.hunger_state = Villager.HUNGER_STARVING  # Must-do.

	village.advance_task_assignment(villager)

	assert_false(villager.task_resolving)


func test_re_querying_after_a_task_finishes_naturally_resurfaces_the_still_pending_need() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_HUNGRY
	villager.tiredness_state = Villager.TIREDNESS_TIRED

	# Both are equally (merely-Important) urgent; Eat wins the tie.
	village.advance_task_assignment(villager)
	assert_eq(villager.current_task.kind, Task.KIND_EAT)

	# The Eat Task resolves (enough food) and hunger recovers, clearing
	# current_task — Sleep was never queued anywhere, it's just still
	# true that tiredness_state is Tired.
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	assert_null(villager.current_task)
	assert_eq(villager.hunger_state, Villager.HUNGER_FINE)

	# Asking again naturally re-surfaces the still-pending Sleep need.
	var changed := village.advance_task_assignment(villager)

	assert_true(changed)
	assert_eq(villager.current_task.kind, Task.KIND_SLEEP)


# --- task_destination()/has_reached_destination() ---


func test_task_destination_is_site_position_for_an_eat_task() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	var task := Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	assert_eq(village.task_destination(task, villager), Vector3(10, 0, 5))


func test_task_destination_is_site_position_for_a_sleep_task_without_a_house() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	var task := Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)

	assert_eq(village.task_destination(task, villager), Vector3(10, 0, 5))


func test_task_destination_prefers_the_villagers_house_position_for_a_sleep_task() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	villager.house = House.new(House.DEFAULT_CAPACITY, Vector3(1, 0, 2))
	var task := Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)

	assert_eq(village.task_destination(task, villager), Vector3(1, 0, 2))


func test_task_destination_still_uses_site_position_for_an_eat_task_even_with_a_house() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	villager.house = House.new(House.DEFAULT_CAPACITY, Vector3(1, 0, 2))
	var task := Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	assert_eq(village.task_destination(task, villager), Vector3(10, 0, 5))


func test_has_reached_destination_is_true_within_the_arrival_threshold() -> void:
	assert_true(Village.has_reached_destination(Vector3(1, 0, 0), Vector3.ZERO, 1.5))


func test_has_reached_destination_is_false_outside_the_arrival_threshold() -> void:
	assert_false(Village.has_reached_destination(Vector3(10, 0, 0), Vector3.ZERO, 1.5))


# --- begin_resolving_task()/advance_sleeping()/interrupt_task() ---


func test_begin_resolving_task_eat_consumes_food_and_recovers_hunger_when_enough_food() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)
	villager.hunger_state = Villager.HUNGER_HUNGRY
	var resources := {"food": 100}

	village.begin_resolving_task(villager, resources, 1.0)

	assert_eq(resources["food"], 100 - VillageNeeds.FOOD_PER_MEAL)
	assert_eq(villager.hunger_state, Villager.HUNGER_FINE)


func test_begin_resolving_task_eat_escalates_hunger_when_not_enough_food() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)
	villager.hunger_state = Villager.HUNGER_HUNGRY
	var resources := {"food": 0}

	village.begin_resolving_task(villager, resources, 1.0)

	assert_eq(resources["food"], 0)
	assert_eq(villager.hunger_state, Villager.HUNGER_STARVING)


func test_begin_resolving_task_eat_clears_current_task_immediately() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_EAT, VillageNeeds.EAT_PRIORITY_HUNGRY)

	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	assert_null(villager.current_task)
	assert_false(villager.task_resolving)


func test_begin_resolving_task_sleep_starts_resolving_without_clearing_current_task() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var task := Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.current_task = task

	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	assert_same(villager.current_task, task)
	assert_true(villager.task_resolving)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_FINE)  # not recovered yet.


func test_advance_sleeping_does_not_resolve_before_the_full_duration_elapses() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	# day_speed 1.0 in-game-hour/real-second -> SLEEP_DURATION_HOURS (8.0)
	# takes 8 real seconds.
	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	village.advance_sleeping(villager, 4.0)

	assert_not_null(villager.current_task)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


func test_advance_sleeping_recovers_tiredness_and_clears_the_task_once_the_full_duration_elapses() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	village.advance_sleeping(villager, 4.0)
	village.advance_sleeping(villager, 4.0)

	assert_null(villager.current_task)
	assert_false(villager.task_resolving)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_FINE)


func test_advance_sleeping_is_a_noop_while_still_traveling_not_yet_resolving() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	# begin_resolving_task() was never called, so task_resolving stays
	# false — still traveling toward the destination.

	village.advance_sleeping(villager, 100.0)

	assert_not_null(villager.current_task)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


func test_interrupt_task_cuts_a_resolving_sleep_task_short_without_recovering_tiredness() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	village.advance_sleeping(villager, 4.0)  # halfway through the 8s countdown.

	village.interrupt_task(villager)

	assert_null(villager.current_task)
	assert_false(villager.task_resolving)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)  # not recovered.


func test_interrupt_task_then_a_fresh_sleep_task_restarts_the_full_duration() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	village.advance_sleeping(villager, 7.0)  # nearly finished.
	village.interrupt_task(villager)

	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	village.advance_sleeping(villager, 4.0)  # only halfway through a fresh 8s.

	assert_not_null(villager.current_task)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


# --- Idle Task execution ---


func test_idle_destination_stays_within_the_wander_radius_of_site_position() -> void:
	var village := Village.new(1)
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	var destination := village.idle_destination(villager)

	assert_true(destination.distance_to(village.site_position) <= VillageTasks.IDLE_WANDER_RADIUS)


func test_idle_destination_keeps_returning_the_same_point_until_the_stand_phase_ends() -> void:
	var village := Village.new(1)
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	var first := village.idle_destination(villager)
	var second := village.idle_destination(villager)

	assert_eq(first, second)


func test_idle_destination_is_tracked_per_villager() -> void:
	var village := Village.new(1)
	var villager_a := Villager.new("v1", true, "The bread smells almost ready.")
	var villager_b := Villager.new("v2", true, "The bread smells almost ready.")

	village.idle_destination(villager_a)
	village.idle_destination(villager_b)

	assert_true(village.idle_destination(villager_a).distance_to(village.site_position) <= VillageTasks.IDLE_WANDER_RADIUS)
	assert_true(village.idle_destination(villager_b).distance_to(village.site_position) <= VillageTasks.IDLE_WANDER_RADIUS)


func test_begin_resolving_task_idle_starts_resolving_without_clearing_current_task() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var task := Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)
	villager.current_task = task

	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	assert_same(villager.current_task, task)
	assert_true(villager.task_resolving)


func test_advance_idle_does_not_pick_a_new_point_before_the_stand_duration_elapses() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	var destination_before := village.idle_destination(villager)

	var started_new_leg := village.advance_idle(villager, 0.01)

	assert_false(started_new_leg)
	assert_true(villager.task_resolving)
	assert_eq(village.idle_destination(villager), destination_before)


func test_advance_idle_picks_a_new_point_and_resumes_traveling_once_the_stand_duration_elapses() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)
	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	var started_new_leg := village.advance_idle(villager, VillageTasks.IDLE_STAND_SECONDS_MAX + 1.0)

	assert_true(started_new_leg)
	assert_not_null(villager.current_task)  # Idle never finishes on its own.
	assert_false(villager.task_resolving)


func test_advance_idle_is_a_noop_while_still_traveling_not_yet_resolving() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)

	var started_new_leg := village.advance_idle(villager, 1000.0)

	assert_false(started_new_leg)
	assert_not_null(villager.current_task)
	assert_false(villager.task_resolving)


func test_advance_idle_is_a_noop_for_a_villager_with_a_different_task_kind() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, VillageNeeds.SLEEP_PRIORITY_TIRED)
	villager.task_resolving = true

	village.advance_idle(villager, 1.0)

	assert_eq(villager.current_task.kind, Task.KIND_SLEEP)


func test_interrupt_task_clears_a_resolving_idle_tasks_wander_state() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)
	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	village.interrupt_task(villager)

	assert_null(villager.current_task)
	assert_false(villager.task_resolving)
	villager.current_task = Task.new(Task.KIND_IDLE, VillageTasks.IDLE_PRIORITY)
	assert_false(villager.task_resolving)
	village.advance_idle(villager, 1000.0)  # not resolving yet -> no-op.
	assert_eq(villager.current_task.kind, Task.KIND_IDLE)
