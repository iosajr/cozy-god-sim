class_name Sheep
extends Folk
## Sheep
## First animal Folk type (CONTEXT.md's Folk entry, issue #11) — a
## domesticated animal that shares Villager's Faith/Favored/Renown
## progression via the common Folk base (`id`, `has_faith`, `favored`,
## `is_renowned`, `gain_favored()`), but skips Survival Needs (issue #10)
## and has no Thought/Wish at all — not a lighter version of either, none
## of them, per the confirmed "domesticated animals get fewer systems
## entirely" principle (docs/systems-overview.md's Survival section /
## issue #11's Problem Statement). Plain data, no scene tree and no
## _ready() lifecycle — fully testable in isolation (Seam 1), same as
## Villager.

## A Sheep's skepticism threshold has no reason to differ from a
## Villager's yet, so — like Villager (see systems/villager.gd's doc
## comment) — Sheep relies directly on the inherited
## Folk.DEFAULT_FAITH_THRESHOLD rather than redeclaring it; only its
## Renown threshold below is deliberately raised (issue #11's User
## Story 6). RENOWN_THRESHOLD is deliberately its own, differently-named
## constant rather than another DEFAULT_RENOWN_THRESHOLD: GDScript's
## global-class member resolution can't disambiguate a same-named
## constant shadowed from a parent class — verified empirically while
## implementing this issue (attempting it broke external references like
## `Sheep.DEFAULT_RENOWN_THRESHOLD` from scripts/sheep_spawner.gd with a
## "Could not resolve external class member" parse error).
##
## Deliberately higher than Folk/Villager's DEFAULT_RENOWN_THRESHOLD
## (100.0) — a domesticated Sheep reaching Renown should be rare and
## difficult, per the user's explicit intent (issue #11's User Story 6),
## not equally achievable as a Villager's. Not a tuned design value, same
## disposable "swap freely" spirit as every other threshold in this
## project — just needs to stay clearly, deliberately harder than
## Villager's.
const RENOWN_THRESHOLD: float = 400.0

## Whether this Sheep is currently content — its only need, "being
## somewhere grassy" (issue #11's Problem Statement/User Story 4), checked
## as a simple boolean rather than any periodic/tracked state like
## Survival Needs' eating check (issue #10) — Sheep skip that system
## entirely. Set by check_contentment(); trivially always true on today's
## placeholder ground, which is uniformly grass-colored everywhere (docs/
## systems-overview.md's Survival section) — a real seam against a world
## that doesn't yet distinguish grass from non-grass regions (issue #11's
## Out of Scope), same "trivial today, meaningful once the world grows"
## spirit as other seams in this project.
var is_content: bool = false


## Sets `is_content` from whether this Sheep is currently near grass.
## Named as its own method (rather than inlined at the call site) so
## sheep_spawner.gd has one clear seam to call, mirroring how Village/
## Villager keep their own rules encapsulated instead of the scene script
## deciding them (issue #6's Implementation Decisions precedent).
func check_contentment(near_grass: bool) -> void:
	is_content = near_grass
