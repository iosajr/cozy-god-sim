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
##
## `favored` (CONTEXT.md's Favored entry) is a growing per-Villager stat
## that rises the longer the Player lingers near them — see
## gain_favored() and scripts/village_spawner.gd's proximity-detection
## loop, which is what actually calls it. Doesn't require Faith to start
## (CONTEXT.md: "doesn't require Faith to begin"); no cap, no decay this
## slice (issue #6).

## Placeholder threshold `gain_favored()` compares accumulated `favored`
## against to decide whether a skeptic crosses over into Faith — per
## CONTEXT.md's Favored entry, "the attention itself can be what earns a
## skeptic their Faith." Not a tuned design value, same disposable spirit
## as wish_chance/reroll_interval_min/max on Village — swap freely once
## real balancing exists (issue #6's Implementation Decisions).
const DEFAULT_FAITH_THRESHOLD: float = 30.0

var id: String
var has_faith: bool
var current_thought: String
var current_wish: Wish
var favored: float = 0.0


func _init(p_id: String, p_has_faith: bool, p_current_thought: String, p_current_wish: Wish = null) -> void:
	id = p_id
	has_faith = p_has_faith
	current_thought = p_current_thought
	current_wish = p_current_wish


## Adds `amount` to `favored` (expected to already be scaled by the
## caller, e.g. by delta and a gain-per-second rate — see
## village_spawner.gd). If this Villager is still a skeptic
## (`has_faith == false`) and the new total meets or crosses
## `faith_threshold`, grants them Faith right here — encapsulating the
## Faith-unlock rule on Villager (not the caller) keeps it testable
## without the scene tree (issue #6's Implementation Decisions). A
## Villager who already has Faith just keeps accumulating `favored`
## past the threshold with no further effect this slice — Renown is a
## separate, later slice (CONTEXT.md's Renown entry).
func gain_favored(amount: float, faith_threshold: float = DEFAULT_FAITH_THRESHOLD) -> void:
	favored += amount
	if not has_faith and favored >= faith_threshold:
		has_faith = true
