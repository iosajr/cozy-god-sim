class_name Task
extends RefCounted
## Task
## The queryable unit of work a Folk member is or could be doing (issue
## #22, docs/systems-overview.md's Task Priority "Architecture, resolved"
## subsection) — this is what the old Daily Routine notes' "current
## activity" state actually is, formalized. `priority` is a numeric
## urgency score, not a fixed enum field — this is what makes "Band is
## dynamic" (docs/systems-overview.md) cheap: escalating urgency is just
## recomputing a number, not mutating a category. Must-do/Important/
## Passtime stay vocabulary for describing *ranges* of `priority`, never
## stored data — see is_must_do() below, the one range this slice
## actually checks. Plain data, no scene tree — same Seam 1 conventions
## as Village/Villager/Folk (see issue #2 / docs/systems-overview.md).

## Named Task kinds this slice produces (issue #22's Implementation
## Decisions — mirrors Village.EATING_*'s constant-pool style). Not an
## exhaustive enum of every Task kind the game will ever have — just
## what Village.query_next_task() hands out today (Eat, Sleep); more
## kinds (Farm work, gathering, exploring, ...) are explicitly Out of
## Scope for this slice.
const KIND_EAT := "eat"
const KIND_SLEEP := "sleep"

## Priority floor a Task must clear to count as Must-do-tier (docs/
## systems-overview.md's Task Priority section — "genuinely
## life-threatening... is exactly this band"). An implementer's-call
## tunable, same disposable spirit as every other threshold in this
## project (reroll_interval_min/max and friends) — not a defended design
## value. Callers never compare `priority` against this directly; see
## is_must_do() below.
const PRIORITY_MUST_DO_THRESHOLD: float = 80.0

var kind: String
var priority: float


func _init(p_kind: String, p_priority: float) -> void:
	kind = p_kind
	priority = p_priority


## "Does this Task's priority clear Must-do territory?" — one clearly
## named check instead of a magic-number comparison scattered at call
## sites (issue #22's User Story 12).
func is_must_do() -> bool:
	return priority >= PRIORITY_MUST_DO_THRESHOLD
