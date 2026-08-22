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
## tick on their own schedule. The real "schedule-driven, not a random
## countdown" design (docs/systems-overview.md's Daily Routine notes)
## lives inside check_sleep() itself, which reasons about
## `time_of_day`/`sleep_start_hour` directly — this countdown only
## governs how often that reasoning gets re-run, the same "periodic, not
## per-frame" performance shape eating_check_interval_min/max already
## uses, not a second competing schedule concept. An implementer's call,
## since issue #22 doesn't specify this driver-loop cadence explicitly.
var sleep_check_interval_min: float = 60.0
var sleep_check_interval_max: float = 90.0

## Target in-game hour (GameState.time_of_day terms, 0.0-24.0) Sleep
## aims to have a Villager asleep by — the "nightfall" placeholder docs/
## systems-overview.md's Daily Routine notes describe. Tunable
## placeholder, implementer's call, same spirit as every other threshold
## in this project.
var sleep_start_hour: float = 20.0

## Assumed travel speed (world units / real second) check_sleep()'s
## lookahead uses to estimate travel time back to `site_position` —
## mirrors Mover's own default `speed` (issue #14) without this Seam-1
## pure logic depending on a live Mover Node (no scene tree here, same
## as everywhere else in Village). Tunable placeholder, implementer's
## call.
var sleep_travel_speed: float = 4.0

## Placeholder Sleep destination for every Villager's check_sleep()
## lookahead (issue #22's User Story 10) — House (issue #17) has no
## spatial position this slice, so the Village's own site position
## stands in, same "ship without waiting on Housing to become spatial"
## reasoning the issue calls for. Plain Vector3 data, no scene tree
## involved — same Seam-1 spirit as known_locations above. Defaults to
## the origin; a real spawner (none wired up this slice) would set this
## to wherever the Village is actually scattered in the world.
var site_position: Vector3 = Vector3.ZERO

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

## Placeholder name for the starting Location a new Village already knows
## about (its own site) — see known_locations below. Village currently has
## no name field of its own, so this is a placeholder value, not a design
## decision (issue #8's Implementation Decisions).
const STARTING_LOCATION_NAME := "the Village"

var villagers: Array[Villager] = []

## A Village's shared, known-to-the-whole-community Known Territory
## (CONTEXT.md's Known Territory entry) — not tracked per-Villager. Starts
## with exactly one Location representing the Village's own site (issue
## #8's User Story 5); grows only via the (not-yet-built) expedition
## mechanic. See knows_location_with_tag() below for the query helper.
var known_locations: Array[Location] = []

var _rng := RandomNumberGenerator.new()
var _reroll_countdowns: Dictionary = {}  # Villager -> float seconds remaining
var _eating_countdowns: Dictionary = {}  # Villager -> float seconds remaining
var _sleep_countdowns: Dictionary = {}  # Villager -> float seconds remaining


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


## Answers "is this Villager in a position to eat?" (issue #10, docs/
## systems-overview.md's Survival section), returning one of the three
## EATING_* outcomes above as *why*-context (issue #22's Implementation
## Decisions), while the real, tracked result — `villager.hunger_state` —
## is mutated as a side effect:
## - At the Village: actually consumes FOOD_PER_MEAL from
##   `resources["food"]` and recovers hunger if there's enough; escalates
##   hunger without consuming anything if there isn't (issue #22's User
##   Story 4, revising issue #10/#16's original "trivially fine
##   regardless of food" branch).
## - Away and provisioned: trivially recovers hunger — they brought food
##   for the journey, so they're self-sufficient (CONTEXT.md-adjacent
##   Survival section, unchanged from #10's original branch).
## - Away and unprovisioned ("foraging"): no real hunting/foraging AI
##   exists yet (issue #22's Out of Scope, carried over from #16) — every
##   such check currently escalates hunger as a failed attempt, an
##   implementer's call, same as an empty store at the Village. Real
##   forage/hunt success chances are a separate, later, larger slice.
## `resources` is a Dictionary (expected to carry a `"food"` key),
## forwarded and mutated by reference — mirroring how `pantheon` is
## forwarded into reroll_thought() (issue #4's User Story 7) — so Village
## stays testable without GameState/the scene tree (issue #22's Testing
## Decisions) while still consuming real, shared stock. The caller
## (village_spawner.gd) is what supplies the real GameState.resources.
func check_eating(villager: Villager, resources: Dictionary) -> String:
	if not villager.is_away:
		if resources.get("food", 0) >= FOOD_PER_MEAL:
			resources["food"] = resources.get("food", 0) - FOOD_PER_MEAL
			_recover_hunger(villager)
		else:
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
## advance_thoughts(). `resources` is forwarded straight through to
## check_eating() — see its doc comment.
func advance_eating_checks(delta: float, resources: Dictionary) -> void:
	for villager in villagers:
		if not _eating_countdowns.has(villager):
			_eating_countdowns[villager] = _random_eating_check_interval()
		var remaining: float = _eating_countdowns[villager] - delta
		if remaining <= 0.0:
			villager.last_eating_outcome = check_eating(villager, resources)
			remaining = _random_eating_check_interval()
		_eating_countdowns[villager] = remaining


## Answers "is this Villager going to make it to sleep in time?" (issue
## #22, folding in issue #18's nightfall + lookahead + Mover design) by
## escalating or recovering `villager.tiredness_state`:
## - At the Village: trivially recovers tiredness — Shelter's "as
##   minimal as a nearby tree" framing (docs/systems-overview.md's
##   Survival section) means this branch is never a real gate this slice,
##   mirroring check_eating()'s own at-Village-is-trivial shape before
##   food-consumption applies to *that* branch specifically.
## - Away: a real lookahead — how many in-game hours remain before
##   `sleep_start_hour` (see _hours_until()) versus how long it'd take,
##   at `sleep_travel_speed`, to travel from `villager.position` back to
##   `site_position` (the House-issue-#17-isn't-spatial-yet placeholder —
##   see its own doc comment). `day_speed` converts the in-game-hours
##   figure into real seconds so it's comparable to the travel-time
##   figure (GameState.day_speed's own doc comment: "in-game hours per
##   real second"). Enough time remaining recovers tiredness; not enough
##   escalates it — a real, mechanically-grounded failure condition
##   instead of a dice roll (issue #22's User Story 8).
## `time_of_day`/`day_speed` are forwarded explicitly rather than read
## from GameState — same Seam-1 "Village/Villager never reach into
## GameState directly" rule check_eating()'s `resources` parameter
## follows above.
func check_sleep(villager: Villager, time_of_day: float, day_speed: float) -> void:
	if not villager.is_away:
		_recover_tiredness(villager)
		return
	var hours_remaining := _hours_until(time_of_day, sleep_start_hour)
	var seconds_remaining := hours_remaining / day_speed if day_speed > 0.0 else 0.0
	var distance := villager.position.distance_to(site_position)
	var travel_seconds := distance / sleep_travel_speed if sleep_travel_speed > 0.0 else 0.0
	if travel_seconds <= seconds_remaining:
		_recover_tiredness(villager)
	else:
		_escalate_tiredness(villager)


## Advances every Villager's sleep-check countdown by `delta` seconds,
## calling check_sleep() for any Villager whose countdown has elapsed.
## Mirrors advance_eating_checks() above exactly, just against its own
## `_sleep_countdowns` — see sleep_check_interval_min/max's doc comment
## for why this countdown doesn't compete with check_sleep()'s own
## nightfall-based reasoning. Same "call once per frame/tick, Village
## itself has no _process" contract as advance_thoughts()/
## advance_eating_checks(). `time_of_day`/`day_speed` are forwarded
## straight through to check_sleep() — see its doc comment.
func advance_sleep_checks(delta: float, time_of_day: float, day_speed: float) -> void:
	for villager in villagers:
		if not _sleep_countdowns.has(villager):
			_sleep_countdowns[villager] = _random_sleep_check_interval()
		var remaining: float = _sleep_countdowns[villager] - delta
		if remaining <= 0.0:
			check_sleep(villager, time_of_day, day_speed)
			remaining = _random_sleep_check_interval()
		_sleep_countdowns[villager] = remaining


## TaskProvider override (issue #22's User Story 3) — the single
## highest-priority real Task `folk` should be doing right now, or null
## if nothing urgent applies (issue #22's User Story 13: "find
## something/anything to do" stays unspecified rather than guessed at).
## Village only tasks its own Villagers; any other Folk type gets null,
## the same "not my population" answer TaskProvider's own base
## implementation gives everyone.
func query_next_task(folk: Folk) -> Task:
	if not (folk is Villager):
		return null
	var villager: Villager = folk
	var eat_task := _eat_task_for(villager)
	var sleep_task := _sleep_task_for(villager)
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


## In-game hours remaining from `current_hour` before `target_hour`, both
## in GameState.time_of_day terms (0.0-24.0). Deliberately NOT a
## wraps-forward-to-tomorrow calculation: check_sleep() calls this to ask
## "is `target_hour` still ahead of us today," not "when does this
## recur" — a Villager already past `target_hour` (current_hour >
## target_hour) is simply out of time, 0.0 hours remaining, not "almost
## a full day until tomorrow's bedtime" (an earlier version of this
## function wrapped that case forward and silently treated an overdue,
## still-far-from-home Villager as having plenty of time — a real
## regression caught in this issue's own code review, see
## tests/systems/test_village.gd's
## test_check_sleep_already_past_sleep_start_hour_and_still_far_escalates_tiredness).
func _hours_until(current_hour: float, target_hour: float) -> float:
	return max(target_hour - current_hour, 0.0)


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
