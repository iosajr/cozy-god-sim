class_name VillageNeeds
extends RefCounted
## Hunger/tiredness escalation and recovery for a Village's Villagers.
## Escalation-only clocks; recovery happens via resolve_eat()/
## recover_tiredness() once a real Eat/Sleep Task actually resolves
## (see systems/village_tasks.gd).

const EATING_AT_VILLAGE := "at_village"
const EATING_PROVISIONED := "provisioned"
const EATING_FORAGING := "foraging"
const EATING_OUTCOMES: Array[String] = [EATING_AT_VILLAGE, EATING_PROVISIONED, EATING_FORAGING]

const FOOD_PER_MEAL: int = 5

const EAT_PRIORITY_HUNGRY: float = 50.0
const EAT_PRIORITY_STARVING: float = 90.0
const SLEEP_PRIORITY_TIRED: float = 50.0
const SLEEP_PRIORITY_EXHAUSTED: float = 90.0

var eating_check_interval_min: float = 60.0
var eating_check_interval_max: float = 90.0
var sleep_check_interval_min: float = 60.0
var sleep_check_interval_max: float = 90.0

var _rng: RandomNumberGenerator
var _eating_countdowns: Dictionary = {}  # Villager -> float seconds remaining
var _sleep_countdowns: Dictionary = {}  # Villager -> float seconds remaining


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func check_eating(villager: Villager) -> String:
	if not villager.is_away:
		_escalate_hunger(villager)
		return EATING_AT_VILLAGE
	if villager.is_provisioned:
		_recover_hunger(villager)
		return EATING_PROVISIONED
	_escalate_hunger(villager)
	return EATING_FORAGING


func advance_eating_checks(villagers: Array[Villager], delta: float) -> void:
	for villager in villagers:
		if not _eating_countdowns.has(villager):
			_eating_countdowns[villager] = _random_eating_check_interval()
		var remaining: float = _eating_countdowns[villager] - delta
		if remaining <= 0.0:
			villager.last_eating_outcome = check_eating(villager)
			remaining = _random_eating_check_interval()
		_eating_countdowns[villager] = remaining


func check_sleep(villager: Villager) -> void:
	_escalate_tiredness(villager)


func advance_sleep_checks(villagers: Array[Villager], delta: float) -> void:
	for villager in villagers:
		if not _sleep_countdowns.has(villager):
			_sleep_countdowns[villager] = _random_sleep_check_interval()
		var remaining: float = _sleep_countdowns[villager] - delta
		if remaining <= 0.0:
			check_sleep(villager)
			remaining = _random_sleep_check_interval()
		_sleep_countdowns[villager] = remaining


## Consumes FOOD_PER_MEAL from resources["food"] and recovers hunger if
## there's enough; escalates without consuming otherwise.
func resolve_eat(villager: Villager, resources: Dictionary) -> void:
	if resources.get("food", 0) >= FOOD_PER_MEAL:
		resources["food"] = resources.get("food", 0) - FOOD_PER_MEAL
		_recover_hunger(villager)
	else:
		_escalate_hunger(villager)


func recover_tiredness(villager: Villager) -> void:
	villager.tiredness_state = _step_state(villager.tiredness_state, Villager.TIREDNESS_STATES, -1)


func eat_task_for(villager: Villager) -> Task:
	return _task_for_state(
		Task.KIND_EAT, villager.hunger_state, Villager.HUNGER_STATES, EAT_PRIORITY_HUNGRY, EAT_PRIORITY_STARVING
	)


func sleep_task_for(villager: Villager) -> Task:
	return _task_for_state(
		Task.KIND_SLEEP,
		villager.tiredness_state,
		Villager.TIREDNESS_STATES,
		SLEEP_PRIORITY_TIRED,
		SLEEP_PRIORITY_EXHAUSTED
	)


func _random_eating_check_interval() -> float:
	return _rng.randf_range(eating_check_interval_min, eating_check_interval_max)


func _random_sleep_check_interval() -> float:
	return _rng.randf_range(sleep_check_interval_min, sleep_check_interval_max)


static func _step_state(state: String, states: Array[String], step: int) -> String:
	var index := states.find(state)
	if index == -1:
		return state
	return states[clampi(index + step, 0, states.size() - 1)]


func _escalate_hunger(villager: Villager) -> void:
	villager.hunger_state = _step_state(villager.hunger_state, Villager.HUNGER_STATES, 1)


func _recover_hunger(villager: Villager) -> void:
	villager.hunger_state = _step_state(villager.hunger_state, Villager.HUNGER_STATES, -1)


func _escalate_tiredness(villager: Villager) -> void:
	villager.tiredness_state = _step_state(villager.tiredness_state, Villager.TIREDNESS_STATES, 1)


## `states` is the [Fine, mid, worst] array; null (no Task) when Fine.
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
