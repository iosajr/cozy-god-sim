extends Node
## GameState
## Global singleton (autoloaded) holding shared simulation state.
## Keep this thin: it's a bulletin board other systems read/write,
## not a dumping ground for gameplay logic.

signal time_of_day_changed(hours: float)
signal resource_changed(resource_name: String, amount: int)

## 0.0-24.0, wraps around. 12.0 = noon.
@export var time_of_day: float = 8.0
## In-game hours per real second. 1.0 = a full day every 24 real seconds.
@export var day_speed: float = 0.25
@export var paused: bool = false

## No "faith" here on purpose: CONTEXT.md defines Faith as a per-Folk
## belief trait, not a global spendable stockpile. See docs/adr/0001.
var resources: Dictionary = {
	"food": 100,
	"wood": 50,
}

## The one Village that exists so far (per issue #2's "no multi-Village
## support" scope). GameState only holds whatever reference is assigned to
## it — populating it is systems/village.gd's job (via the spawner), not
## GameState's, per the doc comment above.
var village: Village = null


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
