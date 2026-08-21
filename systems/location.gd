class_name Location
extends RefCounted
## Location
## A single point of interest a Village's Folk know about (CONTEXT.md's
## Known Territory entry) — a name plus free-form context tags describing
## what's there ("forest", "water", "farmland", "mountains", "animals",
## "village", ...). These are examples, not an exhaustive enum — matching
## this project's existing preference for free-form strings over enums
## (see God.domain). Explicitly NOT tied to resource production this
## slice (issue #8's User Story 3): a point of interest/information, not
## a resource list. Plain data, no scene tree — same Seam 1 conventions as
## Village/Villager/God (see issue #2 / docs/systems-overview.md, and
## issue #8's Implementation Decisions).

var location_name: String
var context_tags: Array[String]


## `p_context_tags` is duplicated rather than stored by reference, so a
## caller who reuses/mutates their own tags array across multiple
## Location.new() calls can't retroactively corrupt an already-created
## Location (a real bug caught in an earlier attempt at this slice).
func _init(p_location_name: String, p_context_tags: Array[String]) -> void:
	location_name = p_location_name
	context_tags = p_context_tags.duplicate()
