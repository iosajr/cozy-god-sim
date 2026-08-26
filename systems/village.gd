class_name Village
extends TaskProvider
## A collection of Villagers plus their Known Territory, Houses, and Farms.
## Plain data/logic, no scene tree (Seam 1). Delegates needs, task, and
## farm behavior to village_needs.gd, village_tasks.gd, village_farms.gd
## (weather-driven watering, issue #59), village_farm_seeding.gd (Seed claim state),
## village_farm_watering.gd (Water claim + fetch-leg state),
## village_farm_labor.gd (Collect/Deliver claim+carry state),
## village_resource_recovery.gd (Recover claim+carry state, issue #37),
## village_pairing.gd (pairing-formation detection, issue #41), and
## village_tasks.gd's own VillageReproduction collaborator (Reproduce Task
## candidacy + gestation countdown, issue #42).

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

## How many of the very first populate() call's Villagers start already
## Renowned (issue #56, spec'd in #54's "Seeding" section) -- so a
## Renowned Folk member is always immediately available to interact with,
## rather than every starter needing to climb Faith->Renown from zero.
## Only applies to the Village's starting population (see populate()'s
## is_starting_population check below) -- a later populate() call, e.g.
## _spawn_newborn()'s populate(1), never forces this. Fixed/tunable, not
## randomized: the first STARTER_RENOWNED_COUNT Villagers in creation
## order are chosen, so this stays deterministic without consuming any
## extra RNG draws (existing seeded-populate() tests are unaffected).
const STARTER_RENOWNED_COUNT: int = 2

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

## Perishable resource entries a Village's Folk have spotted (ADR-0004,
## issue #37) — dropped Deliver-Task cargo is currently the only source
## (see VillageTasks.interrupt_task()); a spotted wild herd or other local
## event is real future direction, not built here. A sibling collection to
## known_locations, not merged into it — see systems/location_resource.gd
## for why LocationResource is kept as its own shape.
var known_resources: Array[LocationResource] = []

## Placeholder "the store"/Sleep-fallback position; a spawner sets this to
## the Village's actual scattered position.
var site_position: Vector3 = Vector3.ZERO

## Placeholder water-source position for the Water Task (issue #38) —
## same tier as site_position ("the store"): a single fixed point, not a
## real river/Location (see docs/systems-overview.md's Watering section
## for why that's still an open question). A spawner sets this alongside
## site_position.
var water_source_position: Vector3 = Vector3.ZERO

## Recent-history context for the villager-ideas prompt (issue #51).
var event_log := VillageEventLog.new()

## Tunables below just forward to the collaborator that actually owns
## them, so external code can keep setting them directly on Village.
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

## Dose-per-second applied while it's raining/storming at a Farm's
## position, forwarded to VillageFarms (issue #59).
var rain_water_rate: float:
	get: return _farm_periodic_watering.rain_water_rate
	set(value): _farm_periodic_watering.rain_water_rate = value

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

## Recovered-per-Recover-Task amount, forwarded to VillageResourceRecovery
## (issue #37).
var recovery_carry_capacity: int:
	get: return _resource_recovery.carry_capacity
	set(value): _resource_recovery.carry_capacity = value

## How close two eligible Villagers must stay to accumulate pairing
## progress, forwarded to VillagePairing (issue #41).
var pairing_proximity_threshold: float:
	get: return _pairing.proximity_threshold
	set(value): _pairing.proximity_threshold = value

## How long two eligible Villagers must stay within
## pairing_proximity_threshold of each other before they pair, forwarded
## to VillagePairing (issue #41).
var pairing_duration: float:
	get: return _pairing.pairing_duration
	set(value): _pairing.pairing_duration = value

var _rng := RandomNumberGenerator.new()
var _needs: VillageNeeds
var _farm_labor: VillageFarmLabor
var _farm_seeding: VillageFarmSeeding
var _farm_watering: VillageFarmWatering
var _resource_recovery: VillageResourceRecovery
var _tasks: VillageTasks
var _farm_periodic_watering: VillageFarms
var _pairing: VillagePairing


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	_needs = VillageNeeds.new(_rng)
	_farm_labor = VillageFarmLabor.new()
	_farm_seeding = VillageFarmSeeding.new()
	_farm_watering = VillageFarmWatering.new()
	_resource_recovery = VillageResourceRecovery.new()
	_tasks = VillageTasks.new(
		_rng, _needs, _farm_labor, _farm_seeding, _farm_watering, _resource_recovery
	)
	_farm_periodic_watering = VillageFarms.new()
	_pairing = VillagePairing.new()
	var starting_tags: Array[String] = ["village"]
	known_locations.append(Location.new(STARTING_LOCATION_NAME, starting_tags))


func populate(count: int) -> void:
	var is_starting_population := villagers.is_empty()
	var new_villagers: Array[Villager] = []
	for i in count:
		var villager := Villager.new(
			"villager_%d" % villagers.size(),
			_rng.randf() < 0.5,
			""
		)
		villager.age_years = _rng.randi_range(MIN_STARTING_AGE_YEARS, MAX_STARTING_AGE_YEARS)
		villager.villager_name = NAME_POOL[_rng.randi_range(0, NAME_POOL.size() - 1)]
		villager.sex = Villager.Sex.FEMALE if _rng.randf() < 0.5 else Villager.Sex.MALE
		villagers.append(villager)
		new_villagers.append(villager)
	_group_into_families(new_villagers)
	for villager in new_villagers:
		var farmer_chance: float = (
			FARMER_CHANCE_WITH_FAMILY_BIAS if villager.family.has_farming_bias else FARMER_CHANCE
		)
		villager.is_farmer = _rng.randf() < farmer_chance
	if is_starting_population:
		_seed_renowned_starters(new_villagers)


## Forces the first STARTER_RENOWNED_COUNT of the starting population's
## Villagers (in creation order) to already be Renowned -- see
## STARTER_RENOWNED_COUNT's own comment. Routes through
## Folk.gain_favored() (rather than setting is_renowned directly) so
## Renown's documented Faith prerequisite stays honored: has_faith also
## ends up true, per gain_favored()'s own crossing logic.
func _seed_renowned_starters(new_villagers: Array[Villager]) -> void:
	var renowned_count: int = mini(STARTER_RENOWNED_COUNT, new_villagers.size())
	for i in renowned_count:
		new_villagers[i].gain_favored(Folk.DEFAULT_RENOWN_THRESHOLD)


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


func check_eating(villager: Villager) -> String:
	return _needs.check_eating(villager)


func advance_eating_checks(delta: float) -> void:
	_needs.advance_eating_checks(villagers, delta)


func check_sleep(villager: Villager) -> void:
	_needs.check_sleep(villager)


func advance_sleep_checks(delta: float) -> void:
	_needs.advance_sleep_checks(villagers, delta)


## `absolute_time` (default 0.0, e.g. `GameState.absolute_game_time`) is
## the point in game time the weather check is made at (issue #59) --
## same optional-default pattern as advance_task_assignment()'s
## observed_at, for callers/tests that don't have/care about one.
func advance_farms(delta: float, absolute_time: float = 0.0) -> void:
	_farm_periodic_watering.advance_farms(farms, delta, absolute_time)


## Call once per frame/tick; Village itself has no _process. Detection
## only -- no Task, no offspring (issue #41; see issue #42).
func advance_pairing(delta: float) -> void:
	var previously_paired: Array[bool] = []
	for villager in villagers:
		previously_paired.append(villager.paired_with != null)
	_pairing.advance_pairing(villagers, delta)
	for i in villagers.size():
		var partner: Villager = villagers[i].paired_with
		# id < partner.id: log the pair once, not once per side.
		if not previously_paired[i] and partner != null and villagers[i].id < partner.id:
			event_log.log_event("%s paired with %s" % [villagers[i].villager_name, partner.villager_name])


func should_interrupt(current_task: Task, candidate: Task) -> bool:
	return _tasks.should_interrupt(current_task, candidate)


## Returns true if the assignment actually changed, so the caller knows to
## redirect its Mover. `observed_at` (default the epoch, i.e. no real time
## source) only matters when this assignment interrupts a running Task
## while carrying cargo — see interrupt_task().
## Kinds routine/frequent enough (multiple times per in-game day) that
## logging every start would be noise, not a notable event.
const _ROUTINE_TASK_KINDS: Array[String] = [Task.KIND_EAT, Task.KIND_SLEEP, Task.KIND_IDLE]


func advance_task_assignment(villager: Villager, observed_at: float = 0.0) -> bool:
	var assigned := _tasks.advance_task_assignment(villager, farms, known_resources, observed_at)
	if assigned and not _ROUTINE_TASK_KINDS.has(villager.current_task.kind):
		event_log.log_event("%s started a %s task" % [villager.villager_name, villager.current_task.kind])
	return assigned


func task_destination(task: Task, villager: Villager) -> Vector3:
	return _tasks.task_destination(task, villager, site_position, water_source_position)


static func has_reached_destination(
	position: Vector3, destination: Vector3, arrival_threshold: float = 0.1
) -> bool:
	return VillageTasks.has_reached_destination(position, destination, arrival_threshold)


func begin_resolving_task(villager: Villager, resources: Dictionary, day_speed: float) -> void:
	_tasks.begin_resolving_task(villager, resources, day_speed, known_resources)


func advance_sleeping(villager: Villager, delta: float) -> void:
	_tasks.advance_sleeping(villager, delta)


## Call once per frame/tick for a Villager whose current_task is a
## resolving Reproduce Task (mirrors advance_sleeping()). VillageTasks
## can't itself add the newborn (it only knows farms/known_resources, not
## villagers/populate()) — Village does that here, the moment gestation
## reports complete (issue #42).
func advance_gestation(villager: Villager, delta: float) -> void:
	if _tasks.advance_gestation(villager, delta):
		_spawn_newborn()
		event_log.log_event("%s and %s had a child" % [villager.villager_name, villager.paired_with.villager_name])


## Adds exactly one newborn Villager, generated the same way populate()
## already generates one (issue #42's acceptance criteria) — reusing
## populate(1) wholesale (id/has_faith/thought/name/sex/Family/is_farmer,
## all rolled the same way) is simpler and more DRY than duplicating that
## generation logic here, then overriding age_years to 0 (populate()'s own
## MIN/MAX_STARTING_AGE_YEARS roll is for a fresh starting population, not
## a newborn). age_years == 0 also means the newborn correctly fails
## VillagePairing's maturity gate and paired_with stays null (populate()'s
## defaults), so it's never itself eligible for pairing.
func _spawn_newborn() -> void:
	var newborn_index := villagers.size()
	populate(1)
	villagers[newborn_index].age_years = 0


func advance_idle(villager: Villager, delta: float) -> bool:
	return _tasks.advance_idle(villager, delta, site_position)


func idle_destination(villager: Villager) -> Vector3:
	return _tasks.idle_destination(villager, site_position)


## `observed_at` is stamped onto a dropped-cargo resource entry's
## last_observed marker, if this interruption catches the villager
## carrying anything — see VillageTasks.interrupt_task()/
## LocationResource. Defaults to 0.0 (no real time source) for callers
## that don't have/care about one, same as advance_task_assignment().
func interrupt_task(villager: Villager, observed_at: float = 0.0) -> void:
	_tasks.interrupt_task(villager, known_resources, observed_at)


## TaskProvider override — only ever tasks its own Villagers.
func query_next_task(folk: Folk) -> Task:
	if not (folk is Villager):
		return null
	return _tasks.query_next_task(folk, farms, known_resources)


func knows_location_with_tag(tag: String) -> bool:
	for location: Location in known_locations:
		if tag in location.context_tags:
			return true
	return false


## JSON-safe snapshot for the local-LLM idea pipeline in Request/ (see
## Request/README.md). Delegates to VillageStateExport, same pattern as
## the collaborator delegation above.
func export_state() -> Dictionary:
	return VillageStateExport.export_village(self)
