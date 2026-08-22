class_name Villager
extends Folk
## Villager
## A single human inhabitant of a Village (CONTEXT.md). Plain data, no
## scene tree and no _ready() lifecycle — fully testable in isolation
## (Seam 1, see issue #2 / docs/systems-overview.md).
##
## Extends Folk (issue #11) — `id`, `has_faith`, `favored`, `is_renowned`,
## and `gain_favored()` now live there, shared with Sheep. This refactor
## is meant to be fully behavior-preserving (issue #11's User Story 2):
## every field below, the constructor signature, and gain_favored()'s
## call shape all stay externally identical to before the extraction.
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

## Villager's Faith/Renown thresholds now live on Folk as
## DEFAULT_FAITH_THRESHOLD/DEFAULT_RENOWN_THRESHOLD (30.0/100.0) — Villager
## doesn't redeclare them here. GDScript's global-class member resolution
## can't disambiguate a subclass constant that shares a parent class's
## constant name (verified empirically while implementing issue #11: doing
## so broke `Villager.DEFAULT_FAITH_THRESHOLD`-style external references,
## e.g. from village_spawner.gd, with a "Could not resolve external class
## member" parse error) — so, unlike the issue's Implementation Decisions
## suggested, Villager relies on Folk's constants directly rather than
## redeclaring same-named ones of its own. Values are unchanged from
## before this refactor either way. Sheep, which genuinely needs a
## different Renown threshold, avoids the same trap by naming its own
## constant distinctly (see systems/sheep.gd).

var current_thought: String
var current_wish: Wish

## Whether this Villager is currently away from the Village (issue #10's
## Survival Needs eating-check slice — CONTEXT.md doesn't cover Survival
## yet, see docs/systems-overview.md's Survival section). Gates which
## Village.check_eating() branch applies: false (the default) always takes
## the trivial at-the-Village branch. Nothing sets this to true yet — no
## expedition mechanic exists — it's purely the data shape the future
## Known Territory expedition slice will set (issue #10's Out of Scope).
var is_away: bool = false
## Only meaningful when `is_away` is true — whether this Villager brought
## food for the journey (issue #10). Nothing sets this to true yet, same
## "seam, not behavior" reasoning as `is_away` above.
var is_provisioned: bool = false
## Last outcome Village.check_eating() recorded for this Villager, via
## Village.advance_eating_checks() — one of Village.EATING_OUTCOMES, or
## empty string before the first periodic check ever fires. Recorded for
## observability only; no Faith/Favored/Renown/Wish/resource consequence
## is attached to any outcome this slice (issue #10's Out of Scope).
var last_eating_outcome: String = ""

## PROVISIONAL, NOT FINAL (issue #17's Housing data slice) — a direct
## reference to this Villager's House, or null if they don't have one.
## The simplest possible pointer, not a considered ownership model (see
## systems/house.gd's doc comment for the full "not final" framing).
## Nothing sets this yet — no assignment logic exists this slice (issue
## #17's Out of Scope); it's set directly (tests, a future debug seam)
## until real House-assignment is designed. The paired Sleeping spec is
## the first real consumer, though it doesn't yet branch on it
## meaningfully either.
var house: House = null


func _init(p_id: String, p_has_faith: bool, p_current_thought: String, p_current_wish: Wish = null) -> void:
	super(p_id, p_has_faith)
	current_thought = p_current_thought
	current_wish = p_current_wish
