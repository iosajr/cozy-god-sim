class_name VillageThoughts
extends RefCounted
## Thought/Wish rerolling for a Village's Villagers.

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

## Domains deliberately overlap Pantheon's roster except "weaving", which
## never matches (exercises the no-link path in resolve_wish()).
const WISH_POOL: Array[Dictionary] = [
	{"text": "I wish the harvest holds through winter.", "domain": "agriculture"},
	{"text": "I wish the rats would leave the grain store be.", "domain": "vermin"},
	{"text": "I wish my grandmother's cough would ease.", "domain": "dying"},
	{"text": "I wish this storm would pass us by.", "domain": "storms"},
	{"text": "I wish I'd never lost my mother's ring.", "domain": "lost things"},
	{"text": "I wish the new loom worked half as well as it was promised.", "domain": "weaving"},
]

var reroll_interval_min: float = 12.0
var reroll_interval_max: float = 24.0
var wish_chance: float = 0.15

var _rng: RandomNumberGenerator
var _reroll_countdowns: Dictionary = {}  # Villager -> float seconds remaining


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func random_thought() -> String:
	return THOUGHT_POOL[_rng.randi_range(0, THOUGHT_POOL.size() - 1)]


func reroll_thought(villager: Villager, pantheon: Pantheon) -> void:
	var wish := _maybe_generate_wish(pantheon)
	if wish != null:
		villager.current_thought = wish.text
		villager.current_wish = wish
	else:
		villager.current_thought = random_thought()
		villager.current_wish = null


## Call once per frame/tick; Village itself has no _process.
func advance_thoughts(villagers: Array[Villager], delta: float, pantheon: Pantheon) -> void:
	for villager in villagers:
		if not _reroll_countdowns.has(villager):
			_reroll_countdowns[villager] = _random_reroll_interval()
		var remaining: float = _reroll_countdowns[villager] - delta
		if remaining <= 0.0:
			reroll_thought(villager, pantheon)
			remaining = _random_reroll_interval()
		_reroll_countdowns[villager] = remaining


## A null pantheon or a Domain no God claims resolves to OUTCOME_IGNORED
## rather than crashing.
func resolve_wish(wish: Wish, pantheon: Pantheon) -> void:
	wish.linked_god = pantheon.get_by_domain(wish.domain) if pantheon != null else null
	if wish.linked_god == null:
		wish.outcome = Wish.OUTCOME_IGNORED
	else:
		wish.outcome = Wish.OUTCOME_RESOLVED if _rng.randf() < 0.5 else Wish.OUTCOME_IGNORED


func _random_reroll_interval() -> float:
	return _rng.randf_range(reroll_interval_min, reroll_interval_max)


func _maybe_generate_wish(pantheon: Pantheon) -> Wish:
	if _rng.randf() >= wish_chance:
		return null
	var entry: Dictionary = WISH_POOL[_rng.randi_range(0, WISH_POOL.size() - 1)]
	var wish := Wish.new(entry["text"], entry["domain"])
	resolve_wish(wish, pantheon)
	return wish
