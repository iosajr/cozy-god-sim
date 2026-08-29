class_name World
extends RefCounted
## Owns every simulated record and the one tick that advances them. Plain
## data, no scene tree, runs headless.

## Game time, advanced by this world and read by everything else.
var clock: Clock = Clock.new()

## The ground every position is answered against.
var terrain: Terrain = FlatTerrain.new()

var _records: Dictionary[int, Record] = {}
var _systems: Array[WorldSystem] = []
var _next_id: int = 1


## Stores the record, gives it its id, and returns that id.
func add_record(record: Record) -> int:
	record.id = _next_id
	_records[record.id] = record
	_next_id += 1
	return record.id


func remove_record(id: int) -> void:
	_records.erase(id)


func has_record(id: int) -> bool:
	return _records.has(id)


## Null if nothing holds that id.
func get_record(id: int) -> Record:
	if not _records.has(id):
		return null
	return _records[id]


## Every record, oldest first.
func records() -> Array[Record]:
	var out: Array[Record] = []
	for id: int in _records:
		out.append(_records[id])
	return out


func count() -> int:
	return _records.size()


## Systems advance in the order they were added.
func add_system(system: WorldSystem) -> void:
	_systems.append(system)


## The one entry point. Advances the clock by the real seconds that
## passed, then every system by the in-game minutes that produced.
func tick(real_delta: float) -> void:
	var elapsed: float = clock.advance(real_delta)
	for system: WorldSystem in _systems:
		system.advance(elapsed)
