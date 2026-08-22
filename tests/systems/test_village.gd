extends GutTest
## Tests for systems/village.gd (Seam 1). No scene tree involved — Village
## is plain RefCounted data, per CONTEXT.md/docs/systems-overview.md and
## issue #2.


func test_populate_creates_n_villagers() -> void:
	var village := Village.new()

	village.populate(6)

	assert_eq(village.villagers.size(), 6)


func test_populated_villager_has_faith_flag_and_thought_from_pool() -> void:
	var village := Village.new()

	village.populate(1)

	var villager: Villager = village.villagers[0]
	assert_typeof(villager.has_faith, TYPE_BOOL)
	assert_has(Village.THOUGHT_POOL, villager.current_thought)


func test_same_seed_produces_the_same_villagers() -> void:
	var village_a := Village.new(42)
	village_a.populate(6)

	var village_b := Village.new(42)
	village_b.populate(6)

	for i in 6:
		assert_eq(village_a.villagers[i].has_faith, village_b.villagers[i].has_faith)
		assert_eq(village_a.villagers[i].current_thought, village_b.villagers[i].current_thought)


func test_reroll_thought_produces_a_value_from_the_pool() -> void:
	var village := Village.new()
	village.wish_chance = 0.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_has(Village.THOUGHT_POOL, villager.current_thought)


func test_villager_defaults_current_wish_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.current_wish)


func test_villager_defaults_favored_to_zero() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.favored, 0.0)


func test_villager_defaults_is_renowned_to_false() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_false(villager.is_renowned)


func test_gain_favored_accumulates_over_repeated_calls() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(0.5, 100.0)
	villager.gain_favored(0.5, 100.0)
	villager.gain_favored(0.25, 100.0)

	assert_eq(villager.favored, 1.25)


func test_gain_favored_grants_faith_to_a_skeptic_who_crosses_the_threshold() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(10.0, 10.0)

	assert_true(villager.has_faith)


func test_gain_favored_leaves_a_skeptic_faithless_below_the_threshold() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(5.0, 10.0)

	assert_false(villager.has_faith)


func test_gain_favored_on_a_villager_who_already_has_faith_keeps_accumulating_without_incident() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(10.0, 10.0)
	villager.gain_favored(10.0, 10.0)

	assert_eq(villager.favored, 20.0)
	assert_true(villager.has_faith)


func test_gain_favored_grants_renown_to_a_faithful_villager_who_crosses_the_renown_threshold() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(10.0, 5.0, 10.0)

	assert_true(villager.is_renowned)


func test_gain_favored_leaves_a_faithful_villager_unrenowned_below_the_renown_threshold() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(5.0, 5.0, 10.0)

	assert_false(villager.is_renowned)


func test_gain_favored_never_grants_renown_to_a_skeptic_even_past_the_renown_threshold() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(10.0, 100.0, 10.0)

	assert_false(villager.is_renowned)


func test_gain_favored_can_grant_faith_and_renown_in_the_same_call_that_crosses_both_thresholds() -> void:
	var villager := Villager.new("v1", false, "The bread smells almost ready.")

	villager.gain_favored(10.0, 5.0, 10.0)

	assert_true(villager.has_faith)
	assert_true(villager.is_renowned)


func test_renown_persists_across_further_gain_favored_calls() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	villager.gain_favored(10.0, 5.0, 10.0)
	villager.gain_favored(1.0, 5.0, 10.0)

	assert_true(villager.is_renowned)


func test_resolve_wish_links_to_the_god_who_claims_its_domain() -> void:
	var village := Village.new()
	var pantheon := Pantheon.new()
	var wish := Wish.new("I wish the rats would leave the grain store.", "vermin")

	village.resolve_wish(wish, pantheon)

	assert_not_null(wish.linked_god)
	assert_eq(wish.linked_god.domain, "vermin")
	assert_has(Wish.OUTCOMES, wish.outcome)


func test_resolve_wish_with_unclaimed_domain_leaves_it_unlinked_but_resolved() -> void:
	var village := Village.new()
	var pantheon := Pantheon.new()
	var wish := Wish.new("I wish the loom worked better.", "weaving")

	village.resolve_wish(wish, pantheon)

	assert_null(wish.linked_god)
	assert_eq(wish.outcome, Wish.OUTCOME_IGNORED)


func test_resolve_wish_with_a_null_pantheon_resolves_to_ignored_without_crashing() -> void:
	var village := Village.new()
	var wish := Wish.new("I wish the rats would leave the grain store.", "vermin")

	village.resolve_wish(wish, null)

	assert_null(wish.linked_god)
	assert_eq(wish.outcome, Wish.OUTCOME_IGNORED)


func test_reroll_thought_can_draw_a_wish_and_resolve_it_against_the_pantheon() -> void:
	var village := Village.new(1)
	village.wish_chance = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_not_null(villager.current_wish)
	assert_eq(villager.current_thought, villager.current_wish.text)
	assert_has(Wish.OUTCOMES, villager.current_wish.outcome)


func test_reroll_thought_never_draws_a_wish_when_wish_chance_is_zero() -> void:
	var village := Village.new()
	village.wish_chance = 0.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	var pantheon := Pantheon.new()

	village.reroll_thought(villager, pantheon)

	assert_null(villager.current_wish)
	assert_has(Village.THOUGHT_POOL, villager.current_thought)


func test_new_village_starts_knowing_exactly_one_location_its_own_site() -> void:
	var village := Village.new()

	assert_eq(village.known_locations.size(), 1)
	assert_true(village.known_locations[0] is Location)


func test_knows_location_with_tag_finds_a_tag_present_on_a_known_location() -> void:
	var village := Village.new()
	var starting_tags: Array[String] = village.known_locations[0].context_tags

	for tag in starting_tags:
		assert_true(village.knows_location_with_tag(tag))


func test_knows_location_with_tag_reports_absence_for_an_unknown_tag() -> void:
	var village := Village.new()

	assert_false(village.knows_location_with_tag("this-tag-does-not-exist"))


func test_same_seed_produces_the_same_wish_vs_flavor_choice_and_outcome() -> void:
	var pantheon := Pantheon.new()

	var village_a := Village.new(7)
	village_a.wish_chance = 1.0
	village_a.populate(6)
	for villager in village_a.villagers:
		village_a.reroll_thought(villager, pantheon)

	var village_b := Village.new(7)
	village_b.wish_chance = 1.0
	village_b.populate(6)
	for villager in village_b.villagers:
		village_b.reroll_thought(villager, pantheon)

	for i in 6:
		var villager_a: Villager = village_a.villagers[i]
		var villager_b: Villager = village_b.villagers[i]
		assert_eq(villager_a.current_thought, villager_b.current_thought)
		assert_not_null(villager_a.current_wish)
		assert_not_null(villager_b.current_wish)
		assert_eq(villager_a.current_wish.domain, villager_b.current_wish.domain)
		assert_eq(villager_a.current_wish.outcome, villager_b.current_wish.outcome)


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


func test_villager_defaults_position_to_zero() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_eq(villager.position, Vector3.ZERO)


func test_village_is_a_task_provider() -> void:
	var village := Village.new()

	assert_true(village is TaskProvider)


# --- check_eating() (issue #22, folds in #16; issue #28 revises the
# --- at-Village branch to pure escalation — recovery is now Task-gated) ---


func test_check_eating_at_village_always_escalates_hunger_regardless_of_food() -> void:
	# issue #28: at-Village no longer trivially/conditionally recovers —
	# recovery only happens once a real Eat Task has been executed (see
	# begin_resolving_task()). Plenty of food on hand doesn't change that.
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	var outcome := village.check_eating(villager)

	assert_eq(outcome, Village.EATING_AT_VILLAGE)
	assert_eq(villager.hunger_state, Villager.HUNGER_HUNGRY)


func test_check_eating_provisioned_recovers_hunger() -> void:
	# Unaffected by issue #28 (its Solution: "the away/provisioned...
	# branches are unaffected by this slice").
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.is_away = true
	villager.is_provisioned = true
	villager.hunger_state = Villager.HUNGER_HUNGRY

	var outcome := village.check_eating(villager)

	assert_eq(outcome, Village.EATING_PROVISIONED)
	assert_eq(villager.hunger_state, Villager.HUNGER_FINE)


func test_check_eating_foraging_unprovisioned_escalates_hunger() -> void:
	# No real hunting/foraging AI exists yet (issue #22's Out of Scope,
	# carried over from #16/#28) — every away+unprovisioned check is a
	# failed attempt until it does, same as before.
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.is_away = true
	villager.is_provisioned = false

	var outcome := village.check_eating(villager)

	assert_eq(outcome, Village.EATING_FORAGING)
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

	assert_eq(villager.last_eating_outcome, Village.EATING_AT_VILLAGE)


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
	assert_eq(villager.last_eating_outcome, Village.EATING_AT_VILLAGE)


func test_advance_eating_checks_escalates_hunger_on_schedule_even_while_a_villager_has_a_current_task() -> void:
	# issue #28's Testing Decisions: the escalation clock keeps ticking
	# on schedule even while a Villager is mid-Task — being busy with a
	# Sleep Task doesn't silently pause hunger escalation.
	var village := Village.new()
	village.eating_check_interval_min = 1.0
	village.eating_check_interval_max = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	villager.task_resolving = true

	village.advance_eating_checks(2.0)

	assert_eq(villager.hunger_state, Villager.HUNGER_HUNGRY)


# --- check_sleep() (issue #22, folds in #18; issue #28 retires the
# --- nightfall + travel-time lookahead — recovery is now Task-gated) ---


func test_check_sleep_always_escalates_tiredness_regardless_of_location() -> void:
	# issue #28: no more trivial at-Village recovery and no more
	# nightfall lookahead — recovery only happens once a real Sleep Task
	# has been executed (see begin_resolving_task()/advance_sleeping()).
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
	# Mirrors test_advance_eating_checks_escalates_hunger_..._current_task
	# above, against tiredness instead — issue #28's Testing Decisions.
	var village := Village.new()
	village.sleep_check_interval_min = 1.0
	village.sleep_check_interval_max = 1.0
	village.populate(1)
	var villager: Villager = village.villagers[0]
	villager.current_task = Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)

	village.advance_sleep_checks(2.0)

	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


# --- query_next_task() (issue #22 — the TaskProvider override) ---


func test_query_next_task_returns_null_for_a_non_villager_folk() -> void:
	var village := Village.new()
	var folk := Folk.new("f1", true)

	assert_null(village.query_next_task(folk))


func test_query_next_task_returns_null_when_nothing_is_urgent() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(village.query_next_task(villager))


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


# --- should_interrupt() (issue #28's User Story 3 — reuses Task.is_must_do()) ---


func test_should_interrupt_is_true_when_the_villager_has_no_current_task() -> void:
	var village := Village.new()
	var candidate := Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)

	assert_true(village.should_interrupt(null, candidate))


func test_should_interrupt_is_false_when_there_is_no_candidate() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)

	assert_false(village.should_interrupt(current, null))


func test_should_interrupt_is_false_when_candidate_is_not_must_do() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	var candidate := Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)

	assert_false(village.should_interrupt(current, candidate))


func test_should_interrupt_is_true_when_candidate_is_must_do() -> void:
	var village := Village.new()
	var current := Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	var candidate := Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_STARVING)

	assert_true(village.should_interrupt(current, candidate))


# --- advance_task_assignment() (issue #28's User Stories 2/3, "no literal
# --- task queue") ---


func test_advance_task_assignment_assigns_a_task_to_a_free_villager() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.hunger_state = Villager.HUNGER_HUNGRY

	var changed := village.advance_task_assignment(villager)

	assert_true(changed)
	assert_not_null(villager.current_task)
	assert_eq(villager.current_task.kind, Task.KIND_EAT)


func test_advance_task_assignment_leaves_a_free_villager_with_nothing_urgent_untasked() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	var changed := village.advance_task_assignment(villager)

	assert_false(changed)
	assert_null(villager.current_task)


func test_advance_task_assignment_leaves_a_running_task_alone_when_the_new_candidate_is_not_must_do() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var running := Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	villager.current_task = running
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	villager.hunger_state = Villager.HUNGER_HUNGRY  # merely-Important, not Must-do.

	var changed := village.advance_task_assignment(villager)

	assert_false(changed)
	assert_same(villager.current_task, running)


func test_advance_task_assignment_interrupts_a_running_task_when_a_must_do_candidate_appears() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
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
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	villager.task_resolving = true
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	villager.hunger_state = Villager.HUNGER_STARVING  # Must-do.

	village.advance_task_assignment(villager)

	assert_false(villager.task_resolving)


func test_re_querying_after_a_task_finishes_naturally_resurfaces_the_still_pending_need() -> void:
	# issue #28's "no literal task queue" — a still-pending need isn't
	# stored anywhere; asking again once the current Task finishes is
	# what re-surfaces it.
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


# --- task_destination()/has_reached_destination() (issue #28's User
# --- Story 4 travel-then-resolve seam, revised by issue #30's real
# --- House position preference) ---


func test_task_destination_is_site_position_for_an_eat_task() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	var task := Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)

	assert_eq(village.task_destination(task, villager), Vector3(10, 0, 5))


func test_task_destination_is_site_position_for_a_sleep_task_without_a_house() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	var task := Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)

	assert_eq(village.task_destination(task, villager), Vector3(10, 0, 5))


func test_task_destination_prefers_the_villagers_house_position_for_a_sleep_task() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	villager.house = House.new(House.DEFAULT_CAPACITY, Vector3(1, 0, 2))
	var task := Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)

	assert_eq(village.task_destination(task, villager), Vector3(1, 0, 2))


func test_task_destination_still_uses_site_position_for_an_eat_task_even_with_a_house() -> void:
	var village := Village.new()
	village.site_position = Vector3(10, 0, 5)
	var villager := Villager.new("v1", true, "sleepy")
	villager.house = House.new(House.DEFAULT_CAPACITY, Vector3(1, 0, 2))
	var task := Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)

	assert_eq(village.task_destination(task, villager), Vector3(10, 0, 5))


func test_has_reached_destination_is_true_within_the_arrival_threshold() -> void:
	assert_true(Village.has_reached_destination(Vector3(1, 0, 0), Vector3.ZERO, 1.5))


func test_has_reached_destination_is_false_outside_the_arrival_threshold() -> void:
	assert_false(Village.has_reached_destination(Vector3(10, 0, 0), Vector3.ZERO, 1.5))


# --- begin_resolving_task()/advance_sleeping()/interrupt_task() (issue
# --- #28's User Stories 4/5/6 — resolving a Task once its destination is
# --- reached) ---


func test_begin_resolving_task_eat_consumes_food_and_recovers_hunger_when_enough_food() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)
	villager.hunger_state = Villager.HUNGER_HUNGRY
	var resources := {"food": 100}

	village.begin_resolving_task(villager, resources, 1.0)

	assert_eq(resources["food"], 100 - Village.FOOD_PER_MEAL)
	assert_eq(villager.hunger_state, Villager.HUNGER_FINE)


func test_begin_resolving_task_eat_escalates_hunger_when_not_enough_food() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)
	villager.hunger_state = Villager.HUNGER_HUNGRY
	var resources := {"food": 0}

	village.begin_resolving_task(villager, resources, 1.0)

	assert_eq(resources["food"], 0)
	assert_eq(villager.hunger_state, Villager.HUNGER_STARVING)


func test_begin_resolving_task_eat_clears_current_task_immediately() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_EAT, Village.EAT_PRIORITY_HUNGRY)

	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	assert_null(villager.current_task)
	assert_false(villager.task_resolving)


func test_begin_resolving_task_sleep_starts_resolving_without_clearing_current_task() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var task := Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	villager.current_task = task

	village.begin_resolving_task(villager, {"food": 100}, 1.0)

	assert_same(villager.current_task, task)
	assert_true(villager.task_resolving)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_FINE)  # not recovered yet.


func test_advance_sleeping_does_not_resolve_before_the_full_duration_elapses() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
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
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
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
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	# Note: begin_resolving_task() was never called, so task_resolving
	# stays false — still traveling toward the destination.

	village.advance_sleeping(villager, 100.0)

	assert_not_null(villager.current_task)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


func test_interrupt_task_cuts_a_resolving_sleep_task_short_without_recovering_tiredness() -> void:
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	village.advance_sleeping(villager, 4.0)  # halfway through the 8s countdown.

	village.interrupt_task(villager)

	assert_null(villager.current_task)
	assert_false(villager.task_resolving)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)  # not recovered.


func test_interrupt_task_then_a_fresh_sleep_task_restarts_the_full_duration() -> void:
	# Regression: interrupting a resolving Sleep Task must clear its
	# countdown, not leave a stale near-finished one behind for whatever
	# Sleep Task comes next.
	var village := Village.new()
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	villager.tiredness_state = Villager.TIREDNESS_TIRED
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	village.advance_sleeping(villager, 7.0)  # nearly finished.
	village.interrupt_task(villager)

	villager.current_task = Task.new(Task.KIND_SLEEP, Village.SLEEP_PRIORITY_TIRED)
	village.begin_resolving_task(villager, {"food": 100}, 1.0)
	village.advance_sleeping(villager, 4.0)  # only halfway through a fresh 8s.

	assert_not_null(villager.current_task)
	assert_eq(villager.tiredness_state, Villager.TIREDNESS_TIRED)


# --- Housing (issue #17, provisional data slice) ---


func test_new_village_starts_with_no_houses() -> void:
	# issue #17's Housing data slice: no construction trigger this
	# slice, so a fresh Village's houses collection starts empty.
	var village := Village.new()

	assert_eq(village.houses.size(), 0)


func test_a_house_can_be_appended_to_village_houses() -> void:
	# No assignment logic in this slice (issue #17's Out of Scope) — a
	# House is just directly appendable, mirroring known_locations.
	var village := Village.new()
	var house := House.new()

	village.houses.append(house)

	assert_eq(village.houses.size(), 1)
	assert_same(village.houses[0], house)


func test_villager_defaults_house_to_null() -> void:
	# issue #17: no assignment logic ships this slice, so a Villager's
	# House pointer stays unset until something (a test, a debug seam)
	# sets it directly.
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.house)


func test_villagers_house_can_be_set_directly() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")
	var house := House.new()

	villager.house = house

	assert_same(villager.house, house)


# --- Task execution (issue #28) ---


func test_villager_defaults_current_task_to_null() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_null(villager.current_task)


func test_villager_defaults_task_resolving_to_false() -> void:
	var villager := Villager.new("v1", true, "The bread smells almost ready.")

	assert_false(villager.task_resolving)
