class_name Task
extends RefCounted
## The queryable unit of work a Folk member is or could be doing.
## `priority` is a numeric urgency score, not a fixed enum — Must-do/
## Important/Passtime are vocabulary for priority *ranges*, never stored
## data (see is_must_do()).

const KIND_EAT := "eat"
const KIND_SLEEP := "sleep"
## Always the lowest-priority Task in play (see VillageTasks.IDLE_PRIORITY).
const KIND_IDLE := "idle"
## Walk to a claimed awaiting-planting Farm and plant it, done in one
## visit (issue #36).
const KIND_SEED := "seed"
## Fetch-then-deposit round trip (issue #38): walk to the Village's water
## source, then to a claimed Farm below its growth threshold, and deposit
## one fixed dose. Two legs, one Task — see VillageTasks.task_destination()/
## begin_resolving_task().
const KIND_WATER := "water"
## Walk to a claimed Farm and harvest it up to carry capacity (issue #33).
const KIND_COLLECT := "collect"
## Walk to the store and deposit carried goods (issue #33). Deliberately
## generic over what's being carried, not farm-specific — see
## docs/systems-overview.md's Farm Labor section.
const KIND_DELIVER := "deliver"
## Walk to a claimed Known Territory resource entry and recover it up to
## carry capacity (issue #37) — the Collect-equivalent half of a second
## Collect/Deliver pipeline for dropped/found cargo, not gated behind
## Villager.is_farmer the way Seed/Water/Collect are.
const KIND_RECOVER := "recover"
## Offered to a paired Villager (issue #42) at a fixed low/Passtime-tier
## priority — resolving starts a gestation countdown (see
## systems/village_reproduction.gd) rather than resolving instantly, same
## countdown-based shape as Sleep. Villager-only; see Village.query_next_task().
const KIND_REPRODUCE := "reproduce"

const PRIORITY_MUST_DO_THRESHOLD: float = 80.0

var kind: String
var priority: float


func _init(p_kind: String, p_priority: float) -> void:
	kind = p_kind
	priority = p_priority


func is_must_do() -> bool:
	return priority >= PRIORITY_MUST_DO_THRESHOLD
