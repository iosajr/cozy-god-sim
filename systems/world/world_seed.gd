class_name WorldSeed
extends RefCounted
## Fills an empty world with the people it starts with. Plain data, so it
## runs with or without anything watching.

const HUMAN_PATH := "res://systems/entities/species/human.tres"
const DRYAD_PATH := "res://systems/entities/species/dryad.tres"

const VILLAGE_CENTRE := Vector3(-32.0, 0.0, 0.0)
const VILLAGE_POPULATION: int = 12
const FOREST_CENTRE := Vector3(32.0, 0.0, 12.0)
const FOREST_POPULATION: int = 8

## How far from its centre a settlement scatters its people.
const SETTLEMENT_RADIUS: float = 11.0

## The spread of ages the world opens with, in years.
const YOUNGEST_YEARS: float = 5.0
const OLDEST_YEARS: float = 60.0


static func populate(world: World, rng: RandomNumberGenerator) -> void:
	var human: Species = load(HUMAN_PATH)
	var dryad: Species = load(DRYAD_PATH)
	_settle(world, rng, human, VILLAGE_CENTRE, VILLAGE_POPULATION)
	_settle(world, rng, dryad, FOREST_CENTRE, FOREST_POPULATION)


## Founds one settlement and the people who live in it.
static func _settle(
	world: World,
	rng: RandomNumberGenerator,
	species: Species,
	centre: Vector3,
	population: int
) -> void:
	var settlement: Settlement = Settlement.new()
	settlement.species = species
	settlement.display_name = species.settlement_name
	settlement.centre = centre
	var home_id: int = world.add_record(settlement)

	for index in population:
		var entity: Entity = Entity.new()
		entity.species = species
		entity.display_name = _name_for(species, index)
		entity.position = _scatter(world.terrain, rng, centre)
		entity.born_at = -_random_age_minutes(rng)
		entity.home_id = home_id
		world.add_record(entity)


## A point somewhere in the settlement, standing on whatever the terrain
## says is there.
static func _scatter(terrain: Terrain, rng: RandomNumberGenerator, centre: Vector3) -> Vector3:
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = SETTLEMENT_RADIUS * sqrt(rng.randf())
	var x: float = centre.x + cos(angle) * distance
	var z: float = centre.z + sin(angle) * distance
	return Vector3(x, terrain.height_at(x, z), z)


static func _random_age_minutes(rng: RandomNumberGenerator) -> float:
	var years: float = rng.randf_range(YOUNGEST_YEARS, OLDEST_YEARS)
	return years * Clock.DAYS_PER_YEAR * Clock.MINUTES_PER_DAY


## A name from the species' pool, or its kind and a number once the pool
## runs out.
static func _name_for(species: Species, index: int) -> String:
	if index < species.names.size():
		return species.names[index]
	return "%s %d" % [species.display_name, index + 1]
