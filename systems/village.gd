class_name Village
extends RefCounted
## Village
## Holds a real collection of Villagers (CONTEXT.md), replacing the old
## `GameState.population: int` headcount. No scene tree, no _ready() —
## fully testable in isolation (Seam 1, see issue #2 /
## docs/systems-overview.md).

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
## systems-overview.md's Survival section) with one of the three EATING_*
## outcomes above. `village_has_food` is accepted — and forwarded by
## village_spawner.gd from GameState.resources.food, mirroring how
## `pantheon` is forwarded into reroll_thought() (User Story 6) — for the
## seam's sake, but this slice's only real branch (an at-the-Village
## Villager) is trivially fine regardless of its value (User Story 4); it's
## not yet consulted by either away branch either, since both are reached
## and recorded only, with no success/fail logic (issue #10's Testing
## Decisions / Out of Scope). `village_has_food` starts mattering once a
## Villager can actually go hungry, which is exactly what this slice
## deliberately leaves unresolved.
func check_eating(villager: Villager, village_has_food: bool) -> String:
	if not villager.is_away:
		return EATING_AT_VILLAGE
	if villager.is_provisioned:
		return EATING_PROVISIONED
	return EATING_FORAGING


## Advances every Villager's eating-check countdown by `delta` seconds,
## calling check_eating() for any Villager whose countdown has elapsed and
## recording the result on Villager.last_eating_outcome (issue #10's User
## Story 7 — reached and recorded, not acted on). Mirrors advance_thoughts()
## above exactly, just against `_eating_countdowns` instead of
## `_reroll_countdowns` — a separate timer per issue #10's User Story 2, so
## Thought rerolls and eating checks tick independently. Same "call once
## per frame/tick, Village itself has no _process" contract as
## advance_thoughts(). `village_has_food` is forwarded straight through to
## check_eating() — see its doc comment.
func advance_eating_checks(delta: float, village_has_food: bool) -> void:
	for villager in villagers:
		if not _eating_countdowns.has(villager):
			_eating_countdowns[villager] = _random_eating_check_interval()
		var remaining: float = _eating_countdowns[villager] - delta
		if remaining <= 0.0:
			villager.last_eating_outcome = check_eating(villager, village_has_food)
			remaining = _random_eating_check_interval()
		_eating_countdowns[villager] = remaining


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
