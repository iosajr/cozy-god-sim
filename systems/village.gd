class_name Village
extends TaskProvider
## Village
## Holds a real collection of Villagers (CONTEXT.md), replacing the old
## `GameState.population: int` headcount. No scene tree, no _ready() —
## fully testable in isolation (Seam 1, see issue #2 /
## docs/systems-overview.md).
##
## `Village extends TaskProvider` as of issue #22 (was `extends
## RefCounted`) — Village is the first/main TaskProvider implementation,
## mirroring the existing "Village owns periodic checks" precedent
## (advance_thoughts()/advance_eating_checks()) rather than a new
## ownership model. Behavior-preserving for everything that existed
## before issue #22 except the new methods it adds — see
## query_next_task() below.

## Fixed pool of placeholder flavor-Thoughts a Villager's `current_thought`
## is drawn from — flavor, not requests (CONTEXT.md's Thought entry).
## Placeholder content, same disposable spirit as world_gen.gd's
## primitives — swap freely once real writing exists.
const THOUGHT_POOL: Array[String] = [
	"The bread smells almost ready.",
	"I wonder if it'll rain before sundown.",
	"That cloud looks like a sleeping dog.",
	"Someone left the gate open again.",
	"I should mend that fence before winter.",
	"The well water tastes sweeter this morning.",
	"I keep humming a tune I can't place.",
	"The goats are in a mood today.",
]

## Smaller pool of Domain-tagged want-content a reroll may draw instead of
## plain flavor (see wish_chance, _maybe_generate_wish()) — CONTEXT.md's
## Wish entry: "not every Thought is a Wish." Each entry is a
## Dictionary with "text" and "domain" keys. Domains here deliberately
## overlap Pantheon's roster ("dying", "agriculture", "vermin", "storms",
## "lost things" — see systems/pantheon.gd) so linking succeeds sometimes,
## and "weaving" deliberately doesn't, so the no-match path
## (Village.resolve_wish()) gets exercised too. Placeholder content, same
## disposable spirit as THOUGHT_POOL above — swap freely once real writing
## exists.
const WISH_POOL: Array[Dictionary] = [
	{"text": "I wish the harvest holds through winter.", "domain": "agriculture"},
	{"text": "I wish the rats would leave the grain store be.", "domain": "vermin"},
	{"text": "I wish my grandmother's cough would ease.", "domain": "dying"},
	{"text": "I wish this storm would pass us by.", "domain": "storms"},
	{"text": "I wish I'd never lost my mother's ring.", "domain": "lost things"},
	{"text": "I wish the new loom worked half as well as it was promised.", "domain": "weaving"},
]

## Each Villager's Thought re-rolls on its own timer, randomized within
## this [min, max] range (seconds) so Villagers don't all change their
## Thought in lockstep — see advance_thoughts(). Flavor-cycling only;
## cadence isn't tied to any deeper simulation (issue #2's Implementation
## Decisions leaves the exact cadence an implementer choice).
var reroll_interval_min: float = 12.0
var reroll_interval_max: float = 24.0

## Chance (0.0-1.0) that a reroll draws a Wish from WISH_POOL instead of
## plain flavor from THOUGHT_POOL. Kept low by default so flavor Thoughts
## stay the norm (issue #4's User Story 9) — exact ratio is an implementer
## choice per the issue's Implementation Decisions. Instance var (like
## reroll_interval_min/max above) so tests can force it to 0.0/1.0 for
## deterministic coverage instead of hunting for a seed that happens to
## roll one way.
var wish_chance: float = 0.15

## Cadence for the periodic per-Villager eating check (issue #10, docs/
## systems-overview.md's Survival section: "roughly 1-2 times a day...
## not a continuously depleting meter"). Mirrors reroll_interval_min/max
## above exactly — a separate countdown (see _eating_countdowns) so Thought
## rerolls and eating checks tick independently. Deliberately larger than
## reroll_interval_min/max since eating is checked far less often than a
## Thought reroll; like reroll_interval_min/max, the exact translation from
## GameState.day_speed/time_of_day into a concrete real-time interval is an
## implementer's call (issue #10's Implementation Decisions) — a tunable
## placeholder, not a tuned design value.
var eating_check_interval_min: float = 60.0
var eating_check_interval_max: float = 90.0

## Named outcomes check_eating() can return — the three branches issue #10
## (docs/systems-overview.md's Survival section) calls for the periodic
## eating check. Only EATING_AT_VILLAGE does anything real this slice;
## EATING_PROVISIONED and EATING_FORAGING are reached and recorded (see
## Villager.last_eating_outcome) but carry no success/fail logic, no
## consequence, yet (issue #10's Out of Scope) — real hunting/foraging
## behavior is a separate, later, larger slice.
const EATING_AT_VILLAGE := "at_village"
const EATING_PROVISIONED := "provisioned"
const EATING_FORAGING := "foraging"
const EATING_OUTCOMES: Array[String] = [EATING_AT_VILLAGE, EATING_PROVISIONED, EATING_FORAGING]

## Food consumed from `resources["food"]` by a single successful
## at-Village eat (issue #22's User Story 4, revising issue #10/#16's
## originally trivial-regardless-of-food branch). Tunable placeholder,
## same implementer's-call spirit as every other threshold/rate in this
## project — not a tuned design value.
const FOOD_PER_MEAL: int = 5

## Cadence for the periodic per-Villager sleep check (issue #22, folding
## in issue #18) — mirrors eating_check_interval_min/max above exactly,
## its own independent countdown (see _sleep_countdowns) so Sleep checks
## tick on their own schedule, the same "periodic, not per-frame"
## performance shape eating_check_interval_min/max uses. As of issue #28,
## check_sleep() is pure escalation (see its doc comment) — this countdown
## just governs how often tiredness escalates, not a schedule-driven
## nightfall calculation anymore. An implementer's call, since no issue
## specifies this driver-loop cadence explicitly.
var sleep_check_interval_min: float = 60.0
var sleep_check_interval_max: float = 90.0

## Placeholder Eat/Sleep destination every Task execution seam travels
## to (issue #28, revising issue #22's check_sleep()-only lookahead
## use) — there's no real store-position concept yet (issue #15's Farm
## delivery already reuses this same placeholder), so the Village's own
## site position stands in for "the store" always, and for Sleep too
## whenever a Villager has no House. Plain Vector3 data, no scene tree
## involved — same Seam-1 spirit as known_locations above. Defaults to
## the origin; a real spawner sets this to wherever the Village is
## actually scattered in the world. As of issue #30, House (systems/
## house.gd) has its own real spatial `position` — see task_destination()
## below for how a Sleep Task now prefers it over this fallback.
var site_position: Vector3 = Vector3.ZERO

## Fixed in-game-hour duration a resolving Sleep Task occupies (issue
## #28's User Story 5) before recovering tiredness — replaces issue
## #22's nightfall + travel-time lookahead (check_sleep() no longer
## does that math; recovery is now entirely gated behind actually
## executing a Sleep Task, see advance_sleeping() below). Converted to
## real seconds via GameState.day_speed at the point a Sleep Task
## starts resolving (see _sleep_duration_seconds()), mirroring the same
## hours/day_speed conversion the old lookahead used.
const SLEEP_DURATION_HOURS: float = 8.0

## Priority Village.query_next_task() assigns an Eat/Sleep Task once
## hunger/tiredness crosses into "worth surfacing" territory (issue #22's
## Implementation Decisions: "an implementer's call... the only hard
## requirement is that it monotonically rises with escalation and that
## Starving/Exhausted are high enough to cross
## Task.PRIORITY_MUST_DO_THRESHOLD"). HUNGER_FINE/TIREDNESS_FINE never
## produce a Task at all — see _eat_task_for()/_sleep_task_for() — so
## "nothing urgent" stays null rather than a fabricated low-priority idle
## Task (issue #22's User Story 13 / Out of Scope).
const EAT_PRIORITY_HUNGRY: float = 50.0
const EAT_PRIORITY_STARVING: float = 90.0
const SLEEP_PRIORITY_TIRED: float = 50.0
const SLEEP_PRIORITY_EXHAUSTED: float = 90.0

## Priority query_next_task() assigns the fallback Idle Task
## (Task.KIND_IDLE) whenever neither Eat nor Sleep applies (issue #29,
## revising issue #22's original "return null when nothing urgent
## applies" behavior) — deliberately below EAT_PRIORITY_HUNGRY/
## SLEEP_PRIORITY_TIRED (the lowest currently-assigned real-need
## priorities) so Idle never outranks an actual need, per the issue's
## Implementation Decisions. Well clear of Task.PRIORITY_MUST_DO_THRESHOLD
## too, so Idle is never mistaken for a Must-do emergency.
const IDLE_PRIORITY: float = 0.0

## How far (world units) an Idle Task's wander point may land from
## site_position (issue #29's User Story 4 — "wander radius centered on
## somewhere sensible... so wandering Villagers don't drift arbitrarily
## far from home"). Tunable placeholder, same implementer's-call spirit
## as every other numeric default in this project (reroll_interval_min/
## max and friends) — not a defended design value.
const IDLE_WANDER_RADIUS: float = 12.0

## [min, max] real-seconds range a resolving Idle Task stands still once
## it reaches a wander point, before picking a new one and walking again
## (issue #29's "wandering, interlaced with standing still" — exact
## timing left an implementer's call). Same tunable-placeholder spirit
## as IDLE_WANDER_RADIUS above.
const IDLE_STAND_SECONDS_MIN: float = 3.0
const IDLE_STAND_SECONDS_MAX: float = 8.0

## Placeholder name for the starting Location a new Village already knows
## about (its own site) — see known_locations below. Village currently has
## no name field of its own, so this is a placeholder value, not a design
## decision (issue #8's Implementation Decisions).
const STARTING_LOCATION_NAME := "the Village"

## Cadence for the periodic per-Farm watering-check (issue #15's
## Implementation Decisions: "Village.advance_farms(delta) — new periodic
## method alongside the existing advance_thoughts/advance_eating_checks"),
## mirroring eating_check_interval_min/max's shape exactly — its own
## independent countdown (see _farm_countdowns) so Farm checks tick on
## their own schedule, not per-frame (User Story 5).
var farm_check_interval_min: float = 20.0
var farm_check_interval_max: float = 40.0

## Chance (0.0-1.0) that a periodic Farm check counts as "it rained" and
## waters that Farm (User Story 4: "watering to come from rain or a
## Villager manually watering it" — manual watering has no
## assignment/trigger mechanism this slice, same "no task/worker-
## assignment system exists yet" scoping as the harvest-delivery walker,
## so rain is this slice's only real watering source). Tunable
## placeholder, same implementer's-call spirit as wish_chance above.
var rain_chance: float = 0.5

## Water amount a single rain event adds via Farm.water() — tunable
## placeholder, same spirit as FOOD_PER_MEAL.
var rain_water_amount: float = 1.0

var villagers: Array[Villager] = []

## A Village's shared, known-to-the-whole-community Known Territory
## (CONTEXT.md's Known Territory entry) — not tracked per-Villager. Starts
## with exactly one Location representing the Village's own site (issue
## #8's User Story 5); grows only via the (not-yet-built) expedition
## mechanic. See knows_location_with_tag() below for the query helper.
var known_locations: Array[Location] = []

## PROVISIONAL, NOT FINAL (issue #17's Housing data slice) — a Village's
## collection of Houses, mirroring known_locations/villagers above. No
## assignment logic and no construction trigger exist this slice (issue
## #17's Out of Scope), so a fresh Village starts with an empty
## collection; nothing appends to it automatically. See
## systems/house.gd's doc comment for the full "not final" framing —
## this is one provisional guess at Housing's real shape, not a
## resolution.
var houses: Array[House] = []

## `Village.farms: Array[Farm]` (issue #15's Implementation Decisions) —
## mirrors known_locations/villagers/houses above. No construction
## trigger exists this slice (issue #15's Out of Scope, mirroring issue
## #8/#10/#17's own precedent for not blocking on an undesigned trigger
## mechanism) — a fresh Village starts with an empty collection; a Farm
## is added directly (a test/debug seam, User Story 13), typically by
## scripts/farm_spawner.gd once it spawns one with a real position.
var farms: Array[Farm] = []

var _rng := RandomNumberGenerator.new()
var _reroll_countdowns: Dictionary = {}  # Villager -> float seconds remaining
var _eating_countdowns: Dictionary = {}  # Villager -> float seconds remaining
var _sleep_countdowns: Dictionary = {}  # Villager -> float seconds remaining
var _farm_countdowns: Dictionary = {}  # Farm -> float seconds remaining

## Tracks a resolving Sleep Task's remaining real-seconds countdown
## (issue #28's User Story 5) — Villager -> float, only ever holding an
## entry while that Villager's current_task is a resolving Sleep Task.
## See begin_resolving_task()/advance_sleeping()/interrupt_task() below.
var _sleep_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining

## Tracks each Villager currently on an Idle Task's current wander-point
## destination (issue #29) — Villager -> Vector3. Lazily populated by
## idle_destination() the first time a fresh Idle Task needs somewhere
## to walk; replaced by advance_idle() once a standing phase ends and a
## new leg begins. Erased by interrupt_task() so a freshly (re-)started
## Idle Task never resumes a stale point.
var _idle_targets: Dictionary = {}  # Villager -> Vector3

## Tracks a resolving (standing-still) Idle Task's remaining
## real-seconds countdown (issue #29) — mirrors _sleep_seconds_remaining
## above exactly, except reaching zero never finishes the Task (see
## advance_idle()): Idle loops (wander, stand, wander, stand, ...) until
## something else interrupts it.
var _idle_stand_seconds_remaining: Dictionary = {}  # Villager -> float seconds remaining

## A single shared Task.KIND_IDLE instance, lazily built and reused by
## every query_next_task() call that falls through to Idle (issue #29) —
## Task is immutable plain data once constructed (nothing in this
## codebase ever mutates `kind`/`priority` after _init()), and Idle's
## per-Villager state (wander target, stand countdown) lives entirely in
## the dictionaries above, keyed by Villager, never on the Task instance
## itself — so every idle Villager sharing the exact same Task object is
## safe. query_next_task() is called once per Villager per frame (see
## scripts/village_spawner.gd's _advance_task_execution()), and most of a
## small population is idle most of the time, so avoiding a fresh
## allocation there avoids real per-frame GC churn for no behavioral
## difference (should_interrupt()'s Idle-vs-Idle guard already discarded
## every such candidate as a non-replacement anyway).
var _idle_task: Task = null


## `seed_value`: pass a non-negative int to make Faith flips and Thought
## draws deterministic (e.g. for tests, or to match a scene's placement
## seed); omit it (or pass -1) to stay randomized, RandomNumberGenerator's
## default.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	var starting_tags: Array[String] = ["village"]
	known_locations.append(Location.new(STARTING_LOCATION_NAME, starting_tags))


func populate(count: int) -> void:
	for i in count:
		var villager := Villager.new(
			"villager_%d" % villagers.size(),
			_rng.randf() < 0.5,
			_random_thought()
		)
		villagers.append(villager)
		_reroll_countdowns[villager] = _random_reroll_interval()
		_eating_countdowns[villager] = _random_eating_check_interval()


## Re-rolls a given Villager onto a new random Thought — most of the time
## plain flavor from THOUGHT_POOL (as before), occasionally a Wish from
## WISH_POOL (see wish_chance), immediately resolved against `pantheon`
## (see resolve_wish()). `pantheon` is passed in explicitly rather than
## read from a global, so Village/Villager (Seam 1) stay testable without
## GameState or the scene tree (issue #4's User Story 7) — the caller
## (village_spawner.gd) is what supplies a real one.
func reroll_thought(villager: Villager, pantheon: Pantheon) -> void:
	var wish := _maybe_generate_wish(pantheon)
	if wish != null:
		villager.current_thought = wish.text
		villager.current_wish = wish
	else:
		villager.current_thought = _random_thought()
		villager.current_wish = null


## Advances every Villager's reroll countdown by `delta` seconds,
## re-rolling any Villager whose countdown has elapsed onto a fresh one.
## Call this once per frame/tick from whatever owns the game loop (e.g.
## village_spawner.gd's _process) — Village itself has no _process, per
## Seam 1's no-scene-tree rule. `pantheon` is forwarded to reroll_thought()
## for any Wish that gets drawn — see its doc comment.
func advance_thoughts(delta: float, pantheon: Pantheon) -> void:
	for villager in villagers:
		if not _reroll_countdowns.has(villager):
			_reroll_countdowns[villager] = _random_reroll_interval()
		var remaining: float = _reroll_countdowns[villager] - delta
		if remaining <= 0.0:
			reroll_thought(villager, pantheon)
			remaining = _random_reroll_interval()
		_reroll_countdowns[villager] = remaining


## Answers "has this Villager eaten recently?" (issue #10, docs/
## systems-overview.md's Survival section), returning one of the three
## EATING_* outcomes above as *why*-context (issue #22's Implementation
## Decisions), while the real, tracked result — `villager.hunger_state` —
## is mutated as a side effect. As of issue #28, this is the escalation
## clock only ("how long has it been") — it never recovers hunger for an
## at-Village Villager anymore; recovery now only happens once a real Eat
## Task has actually been executed (see begin_resolving_task() below),
## since eating always requires physically traveling to the food source,
## even at the Village (issue #28's User Story 8). The away branches are
## unaffected by this slice (issue #28's Solution):
## - At the Village: always escalates hunger — no more trivial recovery
##   here (revises issue #22's "consumes FOOD_PER_MEAL and recovers if
##   there's enough" branch; food is now spent by begin_resolving_task()
##   instead, once an Eat Task actually resolves).
## - Away and provisioned: trivially recovers hunger — they brought food
##   for the journey, so they're self-sufficient (CONTEXT.md-adjacent
##   Survival section, unchanged from #10's original branch, carried
##   forward unaffected by issue #28).
## - Away and unprovisioned ("foraging"): no real hunting/foraging AI
##   exists yet (issue #22's Out of Scope, carried over from #16/#28) —
##   every such check still escalates hunger as a failed attempt, an
##   implementer's call, same as before. Real forage/hunt success
##   chances are a separate, later, larger slice.
func check_eating(villager: Villager) -> String:
	if not villager.is_away:
		_escalate_hunger(villager)
		return EATING_AT_VILLAGE
	if villager.is_provisioned:
		_recover_hunger(villager)
		return EATING_PROVISIONED
	_escalate_hunger(villager)
	return EATING_FORAGING


## Advances every Villager's eating-check countdown by `delta` seconds,
## calling check_eating() for any Villager whose countdown has elapsed and
## recording the result on Villager.last_eating_outcome (issue #10's User
## Story 7, now why-context per issue #22 — see check_eating()'s doc
## comment for the real, tracked result). Mirrors advance_thoughts()
## above exactly, just against `_eating_countdowns` instead of
## `_reroll_countdowns` — a separate timer per issue #10's User Story 2, so
## Thought rerolls and eating checks tick independently. Same "call once
## per frame/tick, Village itself has no _process" contract as
## advance_thoughts(). Runs on this schedule regardless of whatever Task a
## Villager currently has assigned (issue #28's User Story 7 — the
## escalation clock never pauses for a busy Villager); no longer takes a
## `resources` parameter since check_eating() no longer touches it (issue
## #28 moves food consumption into begin_resolving_task() below).
func advance_eating_checks(delta: float) -> void:
	for villager in villagers:
		if not _eating_countdowns.has(villager):
			_eating_countdowns[villager] = _random_eating_check_interval()
		var remaining: float = _eating_countdowns[villager] - delta
		if remaining <= 0.0:
			villager.last_eating_outcome = check_eating(villager)
			remaining = _random_eating_check_interval()
		_eating_countdowns[villager] = remaining


## Answers "has this Villager slept recently?" — the tiredness escalation
## clock (issue #22, folding in issue #18's original Sleeping spec).
## Always escalates `villager.tiredness_state` one stage: as of issue
## #28, the nightfall + travel-time lookahead issue #22 shipped here is
## retired — recovery is no longer decided inline at all, it's entirely
## gated behind actually executing a Sleep Task (Mover travel to
## site_position, then a real fixed SLEEP_DURATION_HOURS occupancy, see
## begin_resolving_task()/advance_sleeping() below), including for a
## Villager already at the Village (issue #28's Solution: "there is no
## more trivially-instant at-Village branch"). `villager.position`/
## `site_position` are no longer read here for that reason — they matter
## to Task execution instead (see task_destination()/
## has_reached_destination() below).
func check_sleep(villager: Villager) -> void:
	_escalate_tiredness(villager)


## Advances every Villager's sleep-check countdown by `delta` seconds,
## calling check_sleep() for any Villager whose countdown has elapsed.
## Mirrors advance_eating_checks() above exactly, just against its own
## `_sleep_countdowns`. Same "call once per frame/tick, Village itself has
## no _process" contract as advance_thoughts()/advance_eating_checks() —
## and same "runs on schedule regardless of a Villager's current Task"
## guarantee (issue #28's User Story 7). No longer takes `time_of_day`/
## `day_speed` parameters since check_sleep() no longer needs them (issue
## #28 retires the nightfall lookahead — see its doc comment).
func advance_sleep_checks(delta: float) -> void:
	for villager in villagers:
		if not _sleep_countdowns.has(villager):
			_sleep_countdowns[villager] = _random_sleep_check_interval()
		var remaining: float = _sleep_countdowns[villager] - delta
		if remaining <= 0.0:
			check_sleep(villager)
			remaining = _random_sleep_check_interval()
		_sleep_countdowns[villager] = remaining


## Advances every Farm's watering-check countdown by `delta` seconds
## (issue #15's Implementation Decisions/Testing Decisions: mirrors
## advance_eating_checks()'s exact countdown-ticking shape, against
## `_farm_countdowns` instead of `_eating_countdowns`). Any Farm whose
## countdown has elapsed rolls `rain_chance`; on a hit, that Farm gets
## watered via Farm.water(rain_water_amount) (User Story 4) — a miss just
## resets the countdown without watering anything, same as a real rain
## check that came up dry. Same "call once per frame/tick, Village itself
## has no _process" contract as advance_thoughts()/advance_eating_checks()
## above.
func advance_farms(delta: float) -> void:
	for farm in farms:
		if not _farm_countdowns.has(farm):
			_farm_countdowns[farm] = _random_farm_check_interval()
		var remaining: float = _farm_countdowns[farm] - delta
		if remaining <= 0.0:
			if _rng.randf() < rain_chance:
				farm.water(rain_water_amount)
			remaining = _random_farm_check_interval()
		_farm_countdowns[farm] = remaining


## Whether a newly-queried candidate Task should replace `villager`'s
## currently-executing one (issue #28's User Story 3) — reuses
## Task.is_must_do() exactly, no new heuristic invented, matching docs/
## systems-overview.md's already-resolved interruption rule (near-
## finished/consequential tasks generally finish; genuine Must-do
## emergencies interrupt, full stop). A Villager with no current Task
## always accepts whatever candidate exists (including null, which
## simply leaves them with nothing assigned).
##
## Idle is a deliberate exception (issue #29's User Story 3: "preempted
## the same way any other Task is — a higher-priority candidate...takes
## over immediately, since Idle is always the lowest priority by
## construction"): a Villager currently on an Idle Task accepts *any*
## non-Idle candidate immediately, not just a Must-do one — wandering
## has no near-finished/consequential cost worth protecting, unlike a
## real Task. Idle-vs-Idle (query_next_task() constructs a fresh Task
## instance every call) deliberately does NOT count as a replacement
## here — accepting it would re-interrupt (and reset) the wander loop
## every single frame nothing has actually changed.
##
## Any other already-executing Task only accepts a candidate that clears
## Task.PRIORITY_MUST_DO_THRESHOLD.
func should_interrupt(current_task: Task, candidate: Task) -> bool:
	if candidate == null:
		return false
	if current_task == null:
		return true
	if current_task.kind == Task.KIND_IDLE:
		return candidate.kind != Task.KIND_IDLE
	return candidate.is_must_do()


## Queries query_next_task() for `villager` and, per should_interrupt()
## above, either assigns the candidate as villager.current_task or leaves
## whatever's currently running untouched (issue #28's User Stories 2/3).
## No literal task queue (issue #28's Solution: "once asked again this
## has priority") — a pending need is never stored; asking again once the
## current Task finishes (current_task back to null) naturally re-surfaces
## it, because the state that produced it (hunger_state/tiredness_state)
## never went away. Returns true if the assignment actually changed (a
## free Villager got a new Task, or a running one got interrupted and
## replaced) so the caller (scripts/village_spawner.gd) knows to redirect
## its Mover; false means "keep doing whatever you were already doing."
func advance_task_assignment(villager: Villager) -> bool:
	var candidate := query_next_task(villager)
	if not should_interrupt(villager.current_task, candidate):
		return false
	if villager.current_task != null:
		interrupt_task(villager)
	villager.current_task = candidate
	villager.task_resolving = false
	return true


## Where `task` should send `villager` before resolving (issue #28's User
## Story 4, revised by issue #30's real House position). KIND_EAT still
## always resolves to the Village's own site_position — "the store" stays
## the same placeholder ground-spot destination it always has been (issue
## #28's Solution, issue #15's Farm delivery reuses the same spot). Now
## that House (issue #17) has a real spatial `position` (issue #30),
## KIND_SLEEP prefers `villager.house.position` when `villager.house` is
## set, falling back to `site_position` exactly as before when it isn't
## — nothing currently assigns `Villager.house` (issue #17's Out of
## Scope, unchanged by #30), so in practice every existing Villager still
## uses the site_position fallback; this only adds the *capability* to
## prefer a real House once assignment eventually exists. Takes `task`
## (rather than being a bare constant lookup) so a future Task kind with
## a genuinely different destination slots in without changing every call
## site.
func task_destination(task: Task, villager: Villager) -> Vector3:
	if task.kind == Task.KIND_SLEEP and villager.house != null:
		return villager.house.position
	return site_position


## Pure "has this tracked position reached `destination`" check (issue
## #28's Testing Decisions: "a pure/testable seam for 'has this Task's
## destination been reached'") — mirrors Mover.advance()'s own
## arrival-threshold math (issue #14, scripts/mover.gd) at the
## Task-execution level, without needing a live Mover Node. The real
## spawner (scripts/village_spawner.gd) keeps `villager.position` synced
## from its Mover's actual position each frame and passes
## `mover.arrival_threshold` through here, so this never drifts from what
## the real Mover instance considers "arrived"; tests can call this
## directly against a synthetic position to exercise the travel-then-
## resolve flow without booting the engine.
static func has_reached_destination(
	position: Vector3, destination: Vector3, arrival_threshold: float = 0.1
) -> bool:
	return position.distance_to(destination) <= arrival_threshold


## Called once `villager.current_task`'s destination has been reached
## (issue #28's User Story 4) — the moment travel ends and resolution
## begins. Eat resolves immediately and clears current_task the same
## call (User Story 4: eating is a single action once you've arrived,
## same shape as issue #22's old at-Village branch, just moved here from
## the escalation clock): consumes FOOD_PER_MEAL from `resources["food"]`
## and recovers hunger if there's enough, escalates hunger without
## consuming anything if there isn't. Sleep instead starts its fixed
## SLEEP_DURATION_HOURS countdown (User Story 5) rather than resolving on
## the spot — see advance_sleeping() below to tick it forward. Idle
## (issue #29) starts its own IDLE_STAND_SECONDS_MIN/MAX countdown the
## same way — see advance_idle() below; unlike Sleep, reaching zero never
## finishes an Idle Task, it just starts a new wander leg. `day_speed`
## converts SLEEP_DURATION_HOURS into real seconds (GameState.day_speed's
## own doc comment: "in-game hours per real second"), mirroring the same
## conversion issue #22's old lookahead used — Idle's countdown is
## already in real seconds, so it ignores `day_speed`. A no-op if
## `villager.current_task` is null.
func begin_resolving_task(villager: Villager, resources: Dictionary, day_speed: float) -> void:
	var task := villager.current_task
	if task == null:
		return
	villager.task_resolving = true
	match task.kind:
		Task.KIND_EAT:
			_resolve_eat(villager, resources)
			_finish_task(villager)
		Task.KIND_SLEEP:
			_sleep_seconds_remaining[villager] = _sleep_duration_seconds(day_speed)
		Task.KIND_IDLE:
			_idle_stand_seconds_remaining[villager] = _random_idle_stand_seconds()
		_:
			_finish_task(villager)


## Ticks a resolving Sleep Task's fixed SLEEP_DURATION_HOURS countdown
## forward by `delta` real seconds (issue #28's User Story 5) — recovers
## tiredness one stage and clears current_task once the countdown reaches
## zero. A no-op for any Villager who isn't mid-way through a resolving
## Sleep Task (wrong kind, not yet resolving, or no countdown tracked —
## e.g. already finished/interrupted), so callers can call this
## unconditionally every frame without guarding it themselves.
func advance_sleeping(villager: Villager, delta: float) -> void:
	var task := villager.current_task
	if task == null or task.kind != Task.KIND_SLEEP or not villager.task_resolving:
		return
	if not _sleep_seconds_remaining.has(villager):
		return
	var remaining: float = _sleep_seconds_remaining[villager] - delta
	if remaining <= 0.0:
		_recover_tiredness(villager)
		_sleep_seconds_remaining.erase(villager)
		_finish_task(villager)
	else:
		_sleep_seconds_remaining[villager] = remaining


## Ticks a resolving (standing-still) Idle Task's IDLE_STAND_SECONDS_MIN/
## MAX countdown forward by `delta` real seconds (issue #29) — mirrors
## advance_sleeping() above exactly, except reaching zero never finishes
## the Task: an Idle Task keeps going (wandering interlaced with
## standing still) until a higher-priority candidate interrupts it via
## advance_task_assignment()/should_interrupt() above. Instead, it picks
## a fresh nearby wander point (see _random_idle_point()) and flips
## task_resolving back to false, so the caller (scripts/
## village_spawner.gd) resumes driving this Villager's Mover toward it.
## Returns true exactly on the call that starts a fresh wander leg (the
## countdown just elapsed) — mirrors advance_task_assignment()'s own
## "did something actually change" return, so the caller knows to
## re-command its Mover right away instead of re-issuing move_to() every
## single frame of an already-underway leg. A no-op (returns false) for
## any Villager not mid-way through a resolving Idle Task (wrong kind,
## not yet resolving, or no countdown tracked), same guard shape as
## advance_sleeping(), so callers can call this unconditionally every
## frame without guarding it themselves.
func advance_idle(villager: Villager, delta: float) -> bool:
	var task := villager.current_task
	if task == null or task.kind != Task.KIND_IDLE or not villager.task_resolving:
		return false
	if not _idle_stand_seconds_remaining.has(villager):
		return false
	var remaining: float = _idle_stand_seconds_remaining[villager] - delta
	if remaining <= 0.0:
		_idle_stand_seconds_remaining.erase(villager)
		_idle_targets[villager] = _random_idle_point()
		villager.task_resolving = false
		return true
	_idle_stand_seconds_remaining[villager] = remaining
	return false


## Returns `villager`'s current Idle wander destination (issue #29),
## lazily picking a fresh point within IDLE_WANDER_RADIUS of
## site_position (see _random_idle_point()) the first time this
## Villager's Idle Task needs somewhere to walk. advance_idle() above is
## what replaces the tracked point once a standing phase ends; this just
## returns whatever's currently tracked (or creates it, the first time).
## The caller (scripts/village_spawner.gd) uses this instead of
## task_destination() for a Task.KIND_IDLE Task, since Idle — unlike
## Eat/Sleep — has a genuinely per-Villager, changing destination rather
## than one fixed placeholder position.
func idle_destination(villager: Villager) -> Vector3:
	if not _idle_targets.has(villager):
		_idle_targets[villager] = _random_idle_point()
	return _idle_targets[villager]


## Cuts `villager`'s currently-executing Task short (issue #28's User
## Story 6 — a genuine Must-do interrupt cutting a resolving Sleep Task
## short rather than forcing it to finish; issue #29 extends this to a
## real Task immediately preempting an Idle one, see should_interrupt()
## above). Clears any in-progress Sleep countdown and Idle wander
## state/countdown along with current_task/task_resolving; called by
## advance_task_assignment() above right before replacing an interrupted
## Task with its successor. A no-op-safe clear regardless of which phase
## (traveling or resolving) or kind the interrupted Task was in.
func interrupt_task(villager: Villager) -> void:
	_sleep_seconds_remaining.erase(villager)
	_idle_stand_seconds_remaining.erase(villager)
	_idle_targets.erase(villager)
	_finish_task(villager)


func _finish_task(villager: Villager) -> void:
	villager.current_task = null
	villager.task_resolving = false


## Shared Eat-resolution logic behind begin_resolving_task()'s
## Task.KIND_EAT branch — mirrors issue #22's old at-Village check_eating()
## branch exactly, just invoked at Task-resolution time instead of on the
## escalation clock's own schedule.
func _resolve_eat(villager: Villager, resources: Dictionary) -> void:
	if resources.get("food", 0) >= FOOD_PER_MEAL:
		resources["food"] = resources.get("food", 0) - FOOD_PER_MEAL
		_recover_hunger(villager)
	else:
		_escalate_hunger(villager)


## SLEEP_DURATION_HOURS converted into real seconds via `day_speed`
## (GameState.day_speed's own doc comment: "in-game hours per real
## second") — same conversion issue #22's old nightfall lookahead used.
## Defensive against a non-positive `day_speed` (paused/misconfigured
## GameState), same "avoid a divide-by-zero" spirit as check_sleep()'s
## old lookahead had.
func _sleep_duration_seconds(day_speed: float) -> float:
	return SLEEP_DURATION_HOURS / day_speed if day_speed > 0.0 else 0.0


## TaskProvider override (issue #22's User Story 3) — the single
## highest-priority real Task `folk` should be doing right now. As of
## issue #29, this never returns null for a Villager anymore: once
## neither Eat nor Sleep applies, it returns a real Task.KIND_IDLE Task
## (IDLE_PRIORITY) instead of null (revising issue #22's User Story 13,
## which had originally left "find something/anything to do"
## unspecified). Village only tasks its own Villagers; any other Folk
## type still gets null, the same "not my population" answer
## TaskProvider's own base implementation gives everyone.
func query_next_task(folk: Folk) -> Task:
	if not (folk is Villager):
		return null
	var villager: Villager = folk
	var eat_task := _eat_task_for(villager)
	var sleep_task := _sleep_task_for(villager)
	if eat_task == null and sleep_task == null:
		if _idle_task == null:
			_idle_task = Task.new(Task.KIND_IDLE, IDLE_PRIORITY)
		return _idle_task
	if eat_task == null:
		return sleep_task
	if sleep_task == null:
		return eat_task
	return eat_task if eat_task.priority >= sleep_task.priority else sleep_task


## Links `wish` to whichever God in `pantheon` claims its Domain (via the
## already-existing Pantheon.get_by_domain()), and sets a placeholder
## outcome on it — deliberately inert this slice, no visible effect on the
## Villager or world (issue #4's Implementation Decisions: "Outcome").
## `pantheon` is passed in explicitly rather than read from a global, so
## Village/Villager (Seam 1) stay testable without GameState or the scene
## tree (issue #4's User Story 7).
##
## A Wish whose Domain matches no God in `pantheon` resolves to
## Wish.OUTCOME_IGNORED rather than crashing (User Story 4) — the same
## "ignored" shape a matched-but-unlucky Wish can also land on below, so a
## Wish is never assumed to always be granted (User Story 5). A null
## `pantheon` (GameState.pantheon itself is never null, but this seam
## doesn't assume every caller honors that) gets the same safe fallback
## rather than crashing.
func resolve_wish(wish: Wish, pantheon: Pantheon) -> void:
	wish.linked_god = pantheon.get_by_domain(wish.domain) if pantheon != null else null
	if wish.linked_god == null:
		wish.outcome = Wish.OUTCOME_IGNORED
	else:
		# Simple coin-flip placeholder — same disposable spirit as Faith's
		# coin-flip in issue #2. Not meant to model how a God actually
		# decides anything; wishes should not always be granted (User
		# Story 5).
		wish.outcome = Wish.OUTCOME_RESOLVED if _rng.randf() < 0.5 else Wish.OUTCOME_IGNORED


## Returns true if any Location in known_locations (this Village's Known
## Territory) carries `tag` among its context_tags. No caller yet this
## slice — a seam for later systems (a foraging restriction, the
## expedition mechanic) to call into, the same "give it a seam before it
## has a consumer" precedent as Pantheon.get_by_domain() had in issue #3
## (issue #8's Implementation Decisions).
func knows_location_with_tag(tag: String) -> bool:
	for location: Location in known_locations:
		if tag in location.context_tags:
			return true
	return false


func _random_reroll_interval() -> float:
	return _rng.randf_range(reroll_interval_min, reroll_interval_max)


func _random_eating_check_interval() -> float:
	return _rng.randf_range(eating_check_interval_min, eating_check_interval_max)


func _random_sleep_check_interval() -> float:
	return _rng.randf_range(sleep_check_interval_min, sleep_check_interval_max)


func _random_farm_check_interval() -> float:
	return _rng.randf_range(farm_check_interval_min, farm_check_interval_max)


## A random point within IDLE_WANDER_RADIUS of site_position (issue
## #29) — uniform over the disc's area (angle uniform over [0, TAU],
## radius scaled by sqrt() of a uniform sample — the standard disc-
## sampling correction; a bare linear randf_range(0, R) on the radius
## would bias points toward the center instead), on the same ground
## plane as site_position (keeps its y, same "no elevation system"
## assumption task_destination()'s site_position stand-in already
## makes).
func _random_idle_point() -> Vector3:
	var angle := _rng.randf_range(0.0, TAU)
	var radius := IDLE_WANDER_RADIUS * sqrt(_rng.randf())
	return site_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _random_idle_stand_seconds() -> float:
	return _rng.randf_range(IDLE_STAND_SECONDS_MIN, IDLE_STAND_SECONDS_MAX)


## Shared one-stage-at-a-time progression math behind
## _escalate_hunger()/_escalate_tiredness() and
## _recover_hunger()/_recover_tiredness() below — hunger_state and
## tiredness_state are two instances of the exact same "ordered
## Fine/mid/worst stage list, move one step, clamp at either end" shape
## (see Villager.HUNGER_STATES/TIREDNESS_STATES), so the stepping logic
## itself lives here once rather than copy-pasted per state machine.
## `step` is +1 to escalate, -1 to recover; an unrecognized `state` (or a
## step that would run off either end of `states`) is returned
## unchanged rather than erroring.
static func _step_state(state: String, states: Array[String], step: int) -> String:
	var index := states.find(state)
	if index == -1:
		return state
	return states[clampi(index + step, 0, states.size() - 1)]


## Escalates `villager.hunger_state` one stage (Fine -> Hungry -> Starving),
## a no-op once already Starving — no stage beyond it this slice (see
## Villager.hunger_state's doc comment).
func _escalate_hunger(villager: Villager) -> void:
	villager.hunger_state = _step_state(villager.hunger_state, Villager.HUNGER_STATES, 1)


## Recovers `villager.hunger_state` one stage (Starving -> Hungry -> Fine),
## a no-op once already Fine.
func _recover_hunger(villager: Villager) -> void:
	villager.hunger_state = _step_state(villager.hunger_state, Villager.HUNGER_STATES, -1)


## Mirrors _escalate_hunger() above, against tiredness_state instead.
func _escalate_tiredness(villager: Villager) -> void:
	villager.tiredness_state = _step_state(villager.tiredness_state, Villager.TIREDNESS_STATES, 1)


## Mirrors _recover_hunger() above, against tiredness_state instead.
func _recover_tiredness(villager: Villager) -> void:
	villager.tiredness_state = _step_state(villager.tiredness_state, Villager.TIREDNESS_STATES, -1)


## Shared "escalation stage -> Task candidate" lookup behind
## _eat_task_for()/_sleep_task_for() below — both ask the exact same
## question of their own state machine ("is this at the worst stage, the
## middle stage, or Fine") and differ only in which Task.KIND_* and
## priority constants apply, so that mapping lives here once. `states`
## is the state's own [Fine, mid, worst] array (Villager.HUNGER_STATES/
## TIREDNESS_STATES); null (no Task at all) when `state` is Fine (index
## 0) — "nothing urgent" per issue #22's User Story 13.
func _task_for_state(
	kind: String, state: String, states: Array[String], mid_priority: float, worst_priority: float
) -> Task:
	match states.find(state):
		2:
			return Task.new(kind, worst_priority)
		1:
			return Task.new(kind, mid_priority)
		_:
			return null


## Eat candidate for query_next_task() — see EAT_PRIORITY_HUNGRY/
## EAT_PRIORITY_STARVING's doc comment above.
func _eat_task_for(villager: Villager) -> Task:
	return _task_for_state(
		Task.KIND_EAT, villager.hunger_state, Villager.HUNGER_STATES, EAT_PRIORITY_HUNGRY, EAT_PRIORITY_STARVING
	)


## Sleep candidate for query_next_task() — mirrors _eat_task_for() above,
## against tiredness_state/SLEEP_PRIORITY_* instead.
func _sleep_task_for(villager: Villager) -> Task:
	return _task_for_state(
		Task.KIND_SLEEP,
		villager.tiredness_state,
		Villager.TIREDNESS_STATES,
		SLEEP_PRIORITY_TIRED,
		SLEEP_PRIORITY_EXHAUSTED
	)


func _random_thought() -> String:
	return THOUGHT_POOL[_rng.randi_range(0, THOUGHT_POOL.size() - 1)]


## With probability `wish_chance`, draws a WISH_POOL entry, builds a Wish
## from it, resolves it against `pantheon` (see resolve_wish()), and
## returns it; otherwise returns null (stay plain flavor). Wish generation
## and linking happen together, once — no re-resolution later (issue #4's
## Implementation Decisions: "Outcome").
func _maybe_generate_wish(pantheon: Pantheon) -> Wish:
	if _rng.randf() >= wish_chance:
		return null
	var entry: Dictionary = WISH_POOL[_rng.randi_range(0, WISH_POOL.size() - 1)]
	var wish := Wish.new(entry["text"], entry["domain"])
	resolve_wish(wish, pantheon)
	return wish
