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

const PRIORITY_MUST_DO_THRESHOLD: float = 80.0

var kind: String
var priority: float


func _init(p_kind: String, p_priority: float) -> void:
	kind = p_kind
	priority = p_priority


func is_must_do() -> bool:
	return priority >= PRIORITY_MUST_DO_THRESHOLD
