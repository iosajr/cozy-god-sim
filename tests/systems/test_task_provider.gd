extends GutTest
## Tests for systems/task_provider.gd (issue #22) — the base TaskProvider
## itself, deliberately generalized past Village per docs/
## systems-overview.md's Task Priority "Architecture, resolved"
## subsection ("a lone Folk member with no Village still needs
## tasking"). Village's own query_next_task() override is covered in
## tests/systems/test_village.gd instead, mirroring how check_eating()
## already lives there.


func test_base_query_next_task_returns_null() -> void:
	var provider := TaskProvider.new()
	var folk := Folk.new("f1", true)

	assert_null(provider.query_next_task(folk))
