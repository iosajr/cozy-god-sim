class_name Village
extends TaskProvider
## A collection of Villagers plus their Known Territory, Houses, and Farms.
## Plain data/logic, no scene tree (Seam 1). Delegates thought/wish,
## needs, task, and farm behavior to systems/village_thoughts.gd,
## village_needs.gd, village_tasks.gd, village_farms.gd (periodic
## watering), village_farm_seeding.gd (Seed claim state),
## village_farm_watering.gd (Water claim + fetch-leg state),
## village_farm_labor.gd (Collect/Deliver claim+carry state).

const STARTING_LOCATION_NAME := "the Village"

## A freshly-populated Villager's age_years is randomized within this
## range so a starting population is immediately eligible for
## Reproducing's 18-year maturity floor, rather than needing 18 in-game
## years to pass first. Tunable, not defended (see issue #34).
const MIN_STARTING_AGE_YEARS: int = 20
const MAX_STARTING_AGE_YEARS: int = 40

## Baseline probability a freshly-populated Villager starts with farming
## Interest (Villager.is_farmer, issue #39) -- tunable, not defended,
## same spirit as MIN/MAX_STARTING_AGE_YEARS above. Applies to a Villager
## whose Family (see below) does not carry the farming business bias.
const FARMER_CHANCE: float = 0.5

## A freshly-populated Villager is grouped into a Family sized within this
## range (issue #40) -- tunable, not defended. A single-Villager populate()
## call is the one exception: with nobody else to group with, it gets a
## lone Family of its own rather than being left family-less.
const MIN_FAMILY_SIZE: int = 2
const MAX_FAMILY_SIZE: int = 4

## Probability a freshly-formed Family is assigned a farming business bias
## at populate() time -- tunable, not defended.
const FAMILY_FARMING_BIAS_CHANCE: float = 0.25

## Probability a Villager whose Family carries the farming business bias
## starts with is_farmer = true -- must stay above FARMER_CHANCE (the
## flat baseline a non-biased Family's members still get). Tunable, not
## defended.
const FARMER_CHANCE_WITH_FAMILY_BIAS: float = 0.85

## Minimal, mechanical placeholder pool (issue #43) -- plain first names,
## not worldbuilding/naming lore.
const NAME_POOL: Array[String] = [
	"Ada", "Ben", "Cora", "Dane", "Elin", "Finn", "Gwen", "Hale",
	"Iris", "Jonah", "Kira", "Leo", "Maren", "Noor", "Otto", "Priya",
]

var villagers: Array[Villager] = []
var known_locations: Array[Location] = []
var houses: Array[House] = []
var farms: Array[Farm] = []

## Placeholder "the store"/Sleep-fallback position; a spawner sets this to
## the Village's actual scattered position.
var site_position: Vector3 = Vector3.ZERO

## Placeholder water-source position for the Water Task (issue #38) —
## same tier as site_position ("the store"): a single fixed point, not a
## real river/Location (see docs/systems-overview.md's Watering section
## for why that's still an open question). A spawner sets this alongside
## site_position.
var water_source_position: Vector3 = Vector3.ZERO

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
var empty_chance: float:
	get: return _thoughts.empty_chance
	set(value): _thoughts.empty_chance = value

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
	get: return _farm_periodic_watering.farm_check_interval_min
	set(value): _farm_periodic_watering.farm_check_interval_min = value
var farm_check_interval_max: float:
	get: return _farm_periodic_watering.farm_check_interval_max
	set(value): _farm_periodic_watering.farm_check_interval_max = value
var rain_chance: float:
	get: return _farm_periodic_watering.rain_chance
	set(value): _farm_periodic_watering.rain_chance = value
var rain_water_amount: float:
	get: return _farm_periodic_watering.rain_water_amount
	set(value): _farm_periodic_watering.rain_water_amount = value

## Harvested-per-Collect-Task amount, forwarded to VillageFarmLabor.
var carry_capacity: int:
	get: return _farm_labor.carry_capacity
	set(value): _farm_labor.carry_capacity = value

## How many Villagers can concurrently hold a Collect Task claim against the
## same Farm, forwarded to VillageFarmLabor (issue #35).
var farm_worker_capacity: int:
	get: return _farm_labor.capacity
	set(value): _farm_labor.capacity = value

## Fixed dose deposited per Water Task visit, forwarded to
## VillageFarmWatering.
var water_dose_amount: float:
	get: return _farm_watering.water_dose_amount
	set(value): _farm_watering.water_dose_amount = value

var _rng := RandomNumberGenerator.new()
var _thoughts: VillageThoughts
var _needs: VillageNeeds
var _farm_labor: VillageFarmLabor
var _farm_seeding: VillageFarmSeeding
var _farm_watering: VillageFarmWatering
var _tasks: VillageTasks
var _farm_periodic_watering: VillageFarms


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	_thoughts = VillageThoughts.new(_rng)
	_needs = VillageNeeds.new(_rng)
	_farm_labor = VillageFarmLabor.new()
	_farm_seeding = VillageFarmSeeding.new()
	_farm_watering = VillageFarmWatering.new()
	_tasks = VillageTasks.new(_rng, _needs, _farm_labor, _farm_seeding, _farm_watering)
	_farm_periodic_watering = VillageFarms.new(_rng)
	var starting_tags: Array[String] = ["village"]
	known_locations.append(Location.new(STARTING_LOCATION_NAME, starting_tags))


func populate(count: int) -> void:
	var new_villagers: Array[Villager] = []
	for i in count:
		var villager := Villager.new(
			"villager_%d" % villagers.size(),
			_rng.randf() < 0.5,
			_thoughts.random_thought()
		)
		villager.age_years = _rng.randi_range(MIN_STARTING_AGE_YEARS, MAX_STARTING_AGE_YEARS)
		villager.villager_name = NAME_POOL[_rng.randi_range(0, NAME_POOL.size() - 1)]
		villagers.append(villager)
		new_villagers.append(villager)
	_group_into_families(new_villagers)
	for villager in new_villagers:
		var farmer_chance: float = (
			FARMER_CHANCE_WITH_FAMILY_BIAS if villager.family.has_farming_bias else FARMER_CHANCE
		)
		villager.is_farmer = _rng.randf() < farmer_chance


## Groups this populate() call's freshly-created Villagers into Families
## sized within [MIN_FAMILY_SIZE, MAX_FAMILY_SIZE], leaving none
## family-less -- every chunk taken here stays in range (any remaining
## count of MIN_FAMILY_SIZE or more can always be split into in-range
## pieces; see the leftover correction below), except a population
## smaller than MIN_FAMILY_SIZE, which necessarily gets a single
## out-of-range Family of its own.
func _group_into_families(new_villagers: Array[Villager]) -> void:
	var i := 0
	var n := new_villagers.size()
	while i < n:
		var remaining: int = n - i
		var size: int
		if remaining <= MAX_FAMILY_SIZE:
			size = remaining
		else:
			size = _rng.randi_range(MIN_FAMILY_SIZE, MAX_FAMILY_SIZE)
			# A too-small leftover can't stand as its own Family -- shift
			# it onto this chunk instead. Falls back to taking everyone
			# remaining if even that adjustment can't reach
			# MIN_FAMILY_SIZE (only possible with unusually tuned
			# MIN/MAX_FAMILY_SIZE values), preferring an out-of-range
			# Family over a family-less Villager.
			var leftover: int = remaining - size
			if leftover > 0 and leftover < MIN_FAMILY_SIZE:
				var adjusted_size: int = remaining - MIN_FAMILY_SIZE
				size = adjusted_size if adjusted_size >= MIN_FAMILY_SIZE else remaining
		var family := Family.new(_rng.randf() < FAMILY_FARMING_BIAS_CHANCE)
		for j in size:
			family.add_member(new_villagers[i + j])
		i += size


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
	_farm_periodic_watering.advance_farms(farms, delta)


func should_interrupt(current_task: Task, candidate: Task) -> bool:
	return _tasks.should_interrupt(current_task, candidate)


## Returns true if the assignment actually changed, so the caller knows to
## redirect its Mover.
func advance_task_assignment(villager: Villager) -> bool:
	return _tasks.advance_task_assignment(villager, farms)


func task_destination(task: Task, villager: Villager) -> Vector3:
	return _tasks.task_destination(task, villager, site_position, water_source_position)


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
	return _tasks.query_next_task(folk, farms)


func knows_location_with_tag(tag: String) -> bool:
	for location: Location in known_locations:
		if tag in location.context_tags:
			return true
	return false
