class_name Village
extends RefCounted
## Village
## Holds a real collection of Villagers (CONTEXT.md), replacing the old
## `GameState.population: int` headcount. No scene tree, no _ready() —
## fully testable in isolation (Seam 1, see issue #2 /
## docs/systems-overview.md).

## Fixed pool of placeholder flavor-Thoughts a Villager's `current_thought`
## is drawn from. Tone: warm, gentle, wondrous, low-stakes, high-charm —
## flavor, not requests (CONTEXT.md's Thought entry). Placeholder content,
## same disposable spirit as world_gen.gd's primitives — swap freely once
## real writing exists.
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

var villagers: Array[Villager] = []

var _rng := RandomNumberGenerator.new()


func populate(count: int) -> void:
	for i in count:
		villagers.append(Villager.new(
			"villager_%d" % villagers.size(),
			_rng.randf() < 0.5,
			_random_thought()
		))


## Re-rolls a given Villager onto a new random Thought from THOUGHT_POOL.
## Flavor-cycling only — not tied to any deeper simulation (see issue #2).
func reroll_thought(villager: Villager) -> void:
	villager.current_thought = _random_thought()


func _random_thought() -> String:
	return THOUGHT_POOL[_rng.randi_range(0, THOUGHT_POOL.size() - 1)]
