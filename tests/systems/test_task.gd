extends GutTest
## Tests for systems/task.gd (issue #22) — Task is plain RefCounted data
## (Seam 1): a kind + a numeric priority, no fixed Must-do/Important/
## Passtime enum field (docs/systems-overview.md's Task Priority
## "Architecture, resolved" subsection — those stay vocabulary for
## priority *ranges*, not stored state).


func test_task_stores_kind_and_priority() -> void:
	var task := Task.new(Task.KIND_EAT, 42.0)

	assert_eq(task.kind, Task.KIND_EAT)
	assert_eq(task.priority, 42.0)


func test_is_must_do_is_false_below_the_threshold() -> void:
	var task := Task.new(Task.KIND_EAT, Task.PRIORITY_MUST_DO_THRESHOLD - 1.0)

	assert_false(task.is_must_do())


func test_is_must_do_is_true_at_the_threshold() -> void:
	var task := Task.new(Task.KIND_SLEEP, Task.PRIORITY_MUST_DO_THRESHOLD)

	assert_true(task.is_must_do())


func test_is_must_do_is_true_above_the_threshold() -> void:
	var task := Task.new(Task.KIND_SLEEP, Task.PRIORITY_MUST_DO_THRESHOLD + 10.0)

	assert_true(task.is_must_do())


func test_kind_idle_is_never_must_do_at_villages_idle_priority() -> void:
	# issue #29: Task.KIND_IDLE always uses Village.IDLE_PRIORITY, which
	# must sit well below PRIORITY_MUST_DO_THRESHOLD so Idle can never be
	# mistaken for a genuine emergency.
	var task := Task.new(Task.KIND_IDLE, Village.IDLE_PRIORITY)

	assert_false(task.is_must_do())
