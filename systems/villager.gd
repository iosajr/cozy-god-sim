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
## observability/why-context only as of issue #22 — the *result* that
## actually matters is `hunger_state` below, not this string (issue #10's
## original Out of Scope; issue #22 folds in the real consequence).
var last_eating_outcome: String = ""

## Unified Hungry→Starving progression (issue #22, folding in issue #16's
## originally-separate Hungry/Starving spec) — covers every way a
## Villager can fail to eat: an empty communal store at the Village
## (Village.check_eating()'s at-Village branch), or an away+unprovisioned
## attempt (Village.check_eating()'s foraging branch — no real
## hunting/foraging AI exists yet, so every such attempt currently counts
## as a failure; an implementer's call, documented on check_eating()
## itself). A successful eat recovers one stage rather than resetting
## straight to HUNGER_FINE — "possibly a progression," per
## docs/systems-overview.md's Survival section, which leaves the exact
## pace explicitly open; one stage per check in either direction is this
## slice's implementer's-call default (see Village._escalate_hunger()/
## _recover_hunger()). No stage beyond HUNGER_STARVING, and reaching it
## still carries no gameplay consequence beyond the Task priority
## Village.query_next_task() produces from it (issue #22's Out of
## Scope — still "temporary, not final," the same caveat #16 originally
## carried).
const HUNGER_FINE := "fine"
const HUNGER_HUNGRY := "hungry"
const HUNGER_STARVING := "starving"
const HUNGER_STATES: Array[String] = [HUNGER_FINE, HUNGER_HUNGRY, HUNGER_STARVING]
var hunger_state: String = HUNGER_FINE

## Unified Tired→Exhausted progression (issue #22, folding in issue #18's
## originally-separate Sleeping spec) — mirrors hunger_state's shape
## exactly. Escalated only by Village.check_sleep(): an away Villager
## whose real nightfall + travel-time lookahead finds not enough time
## remains to reach `position` — Village.site_position, since House
## (issue #17) has no spatial position yet — before Village.
## sleep_start_hour. Recovers one stage per check otherwise, including
## trivially while at the Village (Shelter's "as minimal as a nearby
## tree" framing means that branch is never a real gate this slice). No
## stage beyond TIREDNESS_EXHAUSTED, same "no consequence yet" caveat as
## hunger_state above.
const TIREDNESS_FINE := "fine"
const TIREDNESS_TIRED := "tired"
const TIREDNESS_EXHAUSTED := "exhausted"
const TIREDNESS_STATES: Array[String] = [TIREDNESS_FINE, TIREDNESS_TIRED, TIREDNESS_EXHAUSTED]
var tiredness_state: String = TIREDNESS_FINE

## Current world position — a plain data stand-in Village's Task
## execution seam needs for its has_reached_destination() arrival check
## (issue #28's User Story 4; originally added for issue #22's
## check_sleep() lookahead, since retired). As of issue #28, this is kept
## synced with the spawned body's actual position every frame by
## scripts/village_spawner.gd's `_advance_task_execution()` (its own
## Mover, issue #14) — the first real consumer, resolving the "nothing
## keeps this in sync yet" gap this field used to carry. Defaults to
## Vector3.ZERO.
var position: Vector3 = Vector3.ZERO

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

## Task currently assigned to/executing for this Villager (issue #28) —
## null means free to accept a new one from TaskProvider.query_next_task().
## Set (and cleared) by Village's advance_task_assignment()/
## begin_resolving_task()/advance_sleeping()/interrupt_task() — Villager
## itself stays plain data with no behavior of its own (Seam 1), same as
## every other field here.
var current_task: Task = null

## Whether current_task's destination has already been reached (issue
## #28's travel-then-resolve split) — false while still traveling there
## via Mover (the spawner's job, scripts/village_spawner.gd), true once
## resolution has actually started: Eat resolves and clears current_task
## the same call that flips this true (see Village.begin_resolving_task());
## Sleep instead starts its fixed 8-hour countdown (see
## Village.advance_sleeping()). Meaningless when current_task is null.
var task_resolving: bool = false


func _init(p_id: String, p_has_faith: bool, p_current_thought: String, p_current_wish: Wish = null) -> void:
	super(p_id, p_has_faith)
	current_thought = p_current_thought
	current_wish = p_current_wish
