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

var villagers: Array[Villager] = []

var _rng := RandomNumberGenerator.new()
var _reroll_countdowns: Dictionary = {}  # Villager -> float seconds remaining


## `seed_value`: pass a non-negative int to make Faith flips and Thought
## draws deterministic (e.g. for tests, or to match a scene's placement
## seed); omit it (or pass -1) to stay randomized, RandomNumberGenerator's
## default.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value


func populate(count: int) -> void:
	for i in count:
		var villager := Villager.new(
			"villager_%d" % villagers.size(),
			_rng.randf() < 0.5,
			_random_thought()
		)
		villagers.append(villager)
		_reroll_countdowns[villager] = _random_reroll_interval()


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


func _random_reroll_interval() -> float:
	return _rng.randf_range(reroll_interval_min, reroll_interval_max)


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
