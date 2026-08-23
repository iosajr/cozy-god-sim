class_name Village
extends TaskProvider
## A collection of Villagers plus their Known Territory, Houses, and Farms.
## Plain data/logic, no scene tree (Seam 1). Delegates thought/wish,
## needs, task, and farm behavior to systems/village_thoughts.gd,
## village_needs.gd, village_tasks.gd, village_farms.gd.

const STARTING_LOCATION_NAME := "the Village"

## A freshly-populated Villager's age_years is randomized within this
## range so a starting population is immediately eligible for
## Reproducing's 18-year maturity floor, rather than needing 18 in-game
## years to pass first. Tunable, not defended (see issue #34).
const MIN_STARTING_AGE_YEARS: int = 20
const MAX_STARTING_AGE_YEARS: int = 40

var villagers: Array[Villager] = []
var known_locations: Array[Location] = []
var houses: Array[House] = []
var farms: Array[Farm] = []

## Placeholder "the store"/Sleep-fallback position; a spawner sets this to
## the Village's actual scattered position.
var site_position: Vector3 = Vector3.ZERO

## Tunables below just forward to the collaborator that actually owns
## them, so external code can keep setting them directly on Village.
var reroll_interval_min: float:
	get: return _thoughts.reroll_interval_min
	set(value): _thoughts.reroll_interval_min = value
var reroll_interval_max: float:
	get: return _thoughts.reroll_interval_max
	set(value): _thoughts.reroll_interval_max = value
var wish_chance: float:
	get: return _thoughts.wish_chance
	set(value): _thoughts.wish_chance = value

var eating_check_interval_min: float:
	get: return _needs.eating_check_interval_min
	set(value): _needs.eating_check_interval_min = value
var eating_check_interval_max: float:
	get: return _needs.eating_check_interval_max
	set(value): _needs.eating_check_interval_max = value
var sleep_check_interval_min: float:
	get: return _needs.sleep_check_interval_min
	set(value): _needs.sleep_check_interval_min = value
var sleep_check_interval_max: float:
	get: return _needs.sleep_check_interval_max
	set(value): _needs.sleep_check_interval_max = value

var farm_check_interval_min: float:
	get: return _farm_watering.farm_check_interval_min
	set(value): _farm_watering.farm_check_interval_min = value
var farm_check_interval_max: float:
	get: return _farm_watering.farm_check_interval_max
	set(value): _farm_watering.farm_check_interval_max = value
var rain_chance: float:
	get: return _farm_watering.rain_chance
	set(value): _farm_watering.rain_chance = value
var rain_water_amount: float:
	get: return _farm_watering.rain_water_amount
	set(value): _farm_watering.rain_water_amount = value

var _rng := RandomNumberGenerator.new()
var _thoughts: VillageThoughts
var _needs: VillageNeeds
var _tasks: VillageTasks
var _farm_watering: VillageFarms


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	_thoughts = VillageThoughts.new(_rng)
	_needs = VillageNeeds.new(_rng)
	_tasks = VillageTasks.new(_rng, _needs)
	_farm_watering = VillageFarms.new(_rng)
	var starting_tags: Array[String] = ["village"]
	known_locations.append(Location.new(STARTING_LOCATION_NAME, starting_tags))


func populate(count: int) -> void:
	for i in count:
		var villager := Villager.new(
			"villager_%d" % villagers.size(),
			_rng.randf() < 0.5,
			_thoughts.random_thought()
		)
		villager.age_years = _rng.randi_range(MIN_STARTING_AGE_YEARS, MAX_STARTING_AGE_YEARS)
		villagers.append(villager)


func reroll_thought(villager: Villager, pantheon: Pantheon) -> void:
	_thoughts.reroll_thought(villager, pantheon)


## Call once per frame/tick; Village itself has no _process.
func advance_thoughts(delta: float, pantheon: Pantheon) -> void:
	_thoughts.advance_thoughts(villagers, delta, pantheon)


func resolve_wish(wish: Wish, pantheon: Pantheon) -> void:
	_thoughts.resolve_wish(wish, pantheon)


func check_eating(villager: Villager) -> String:
	return _needs.check_eating(villager)


func advance_eating_checks(delta: float) -> void:
	_needs.advance_eating_checks(villagers, delta)


func check_sleep(villager: Villager) -> void:
	_needs.check_sleep(villager)


func advance_sleep_checks(delta: float) -> void:
	_needs.advance_sleep_checks(villagers, delta)


func advance_farms(delta: float) -> void:
	_farm_watering.advance_farms(farms, delta)


func should_interrupt(current_task: Task, candidate: Task) -> bool:
	return _tasks.should_interrupt(current_task, candidate)


## Returns true if the assignment actually changed, so the caller knows to
## redirect its Mover.
func advance_task_assignment(villager: Villager) -> bool:
	return _tasks.advance_task_assignment(villager)


func task_destination(task: Task, villager: Villager) -> Vector3:
	return _tasks.task_destination(task, villager, site_position)


static func has_reached_destination(
	position: Vector3, destination: Vector3, arrival_threshold: float = 0.1
) -> bool:
	return VillageTasks.has_reached_destination(position, destination, arrival_threshold)


func begin_resolving_task(villager: Villager, resources: Dictionary, day_speed: float) -> void:
	_tasks.begin_resolving_task(villager, resources, day_speed)


func advance_sleeping(villager: Villager, delta: float) -> void:
	_tasks.advance_sleeping(villager, delta)


func advance_idle(villager: Villager, delta: float) -> bool:
	return _tasks.advance_idle(villager, delta, site_position)


func idle_destination(villager: Villager) -> Vector3:
	return _tasks.idle_destination(villager, site_position)


func interrupt_task(villager: Villager) -> void:
	_tasks.interrupt_task(villager)


## TaskProvider override — only ever tasks its own Villagers.
func query_next_task(folk: Folk) -> Task:
	if not (folk is Villager):
		return null
	return _tasks.query_next_task(folk)


func knows_location_with_tag(tag: String) -> bool:
	for location: Location in known_locations:
		if tag in location.context_tags:
			return true
	return false
