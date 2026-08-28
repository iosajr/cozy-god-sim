class_name TaskProvider
extends RefCounted
## Ownership abstraction for "who groups a set of Folk and hands out
## tasks" — generalized past Village so a lone Folk member could get its
## own minimal provider without needing to resolve as a Village.

## Base implementation always returns null; Village overrides this for
## its own Villagers. Not a continuous re-scoring loop — callers call this
## at real decision points (Task finished, interrupted, periodic tick).
func query_next_task(_folk: Folk) -> Task:
	return null
