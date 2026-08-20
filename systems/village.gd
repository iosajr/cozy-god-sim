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

## Each Villager's Thought re-rolls on its own timer, randomized within
## this [min, max] range (seconds) so Villagers don't all change their
## Thought in lockstep — see advance_thoughts(). Flavor-cycling only;
## cadence isn't tied to any deeper simulation (issue #2's Implementation
## Decisions leaves the exact cadence an implementer choice).
var reroll_interval_min: float = 12.0
var reroll_interval_max: float = 24.0

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


## Re-rolls a given Villager onto a new random Thought from THOUGHT_POOL.
## Flavor-cycling only — not tied to any deeper simulation (see issue #2).
func reroll_thought(villager: Villager) -> void:
	villager.current_thought = _random_thought()


## Advances every Villager's reroll countdown by `delta` seconds,
## re-rolling any Villager whose countdown has elapsed onto a fresh one.
## Call this once per frame/tick from whatever owns the game loop (e.g.
## village_spawner.gd's _process) — Village itself has no _process, per
## Seam 1's no-scene-tree rule.
func advance_thoughts(delta: float) -> void:
	for villager in villagers:
		var remaining: float = _reroll_countdowns.get(villager, _random_reroll_interval()) - delta
		if remaining <= 0.0:
			reroll_thought(villager)
			remaining = _random_reroll_interval()
		_reroll_countdowns[villager] = remaining


func _random_reroll_interval() -> float:
	return _rng.randf_range(reroll_interval_min, reroll_interval_max)


func _random_thought() -> String:
	return THOUGHT_POOL[_rng.randi_range(0, THOUGHT_POOL.size() - 1)]
