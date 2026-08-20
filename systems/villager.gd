class_name Villager
extends RefCounted
## Villager
## A single human inhabitant of a Village (CONTEXT.md). Plain data, no
## scene tree and no _ready() lifecycle — fully testable in isolation
## (Seam 1, see issue #2 / docs/systems-overview.md).
##
## `id` is a stable internal identifier for tests/debugging only — it is
## not an in-world visible name (only `current_thought` is ever shown to
## the Player, via the nameplate seam).
##
## `current_wish` is non-null only when `current_thought` is a Wish
## (CONTEXT.md's Wish entry — "not every Thought is a Wish"); most
## Thoughts stay plain flavor and leave this null. See Village.WISH_POOL /
## Village.resolve_wish().

var id: String
var has_faith: bool
var current_thought: String
var current_wish: Wish


func _init(p_id: String, p_has_faith: bool, p_current_thought: String, p_current_wish: Wish = null) -> void:
	id = p_id
	has_faith = p_has_faith
	current_thought = p_current_thought
	current_wish = p_current_wish
