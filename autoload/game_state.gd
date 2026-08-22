extends Node
## Global singleton (autoloaded) holding shared simulation state. Keep
## this thin: a bulletin board other systems read/write, not a place for
## gameplay logic.

signal time_of_day_changed(hours: float)
signal resource_changed(resource_name: String, amount: int)

## 0.0-24.0, wraps around. 12.0 = noon.
@export var time_of_day: float = 8.0
## In-game hours per real second.
@export var day_speed: float = 0.25
@export var paused: bool = false

## No "faith" key — Faith is a per-Folk trait, not a global stockpile.
var resources: Dictionary = {
	"food": 100,
	"wood": 50,
}

## Never null — defaults to an empty Village so reading this before a
## spawner runs is always safe.
var village: Village = Village.new()
## Never null, same reasoning as village above.
var pantheon: Pantheon = Pantheon.new()


func _process(delta: float) -> void:
	if paused:
		return
	time_of_day = fmod(time_of_day + delta * day_speed, 24.0)
	time_of_day_changed.emit(time_of_day)


func add_resource(resource_name: String, amount: int) -> void:
	resources[resource_name] = resources.get(resource_name, 0) + amount
	resource_changed.emit(resource_name, resources[resource_name])


func get_resource(resource_name: String) -> int:
	return resources.get(resource_name, 0)
