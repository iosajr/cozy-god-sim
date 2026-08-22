class_name TaskProvider
extends RefCounted
## TaskProvider
## Ownership abstraction for "who groups a set of Folk and hands out
## tasks" (issue #22, docs/systems-overview.md's Task Priority
## "Architecture, resolved" subsection) — deliberately generalized past
## `Village` on purpose: a lone Folk member with no Village still needs
## tasking, the same shape as the still-open Buildings-section question
## ("is a solitary Folk with just their own Shelter a Village of
## population 1, or not a Village at all?"). TaskProvider sidesteps
## needing an answer to that rather than picking one — a true loner just
## gets its own minimal TaskProvider instead of being forced to resolve
## as a Village either way. Same "generalize only once a second concrete
## need actually requires it" spirit as the Folk base-class extraction
## (issue #11), not a preemptive abstraction: `Village` is the first and,
## this slice, only real implementation (see systems/village.gd,
## `Village extends TaskProvider`).
##
## Plain data/logic, no scene tree — same Seam 1 conventions as
## Village/Villager/Folk (see issue #2 / docs/systems-overview.md).


## Pure query: "what's the single highest-priority real Task `folk`
## should be doing right now?" Not a continuous loop that proactively
## re-scores every Folk member every tick — callers invoke this at real
## decision points (a Folk member's current Task finished, a Must-do
## escalation interrupted it, its own periodic tick fired), per this
## issue's Problem Statement. Base implementation always returns null —
## no tasks to hand out with no Folk grouping behind it; `Village`
## overrides this for its own Villagers.
func query_next_task(_folk: Folk) -> Task:
	return null
