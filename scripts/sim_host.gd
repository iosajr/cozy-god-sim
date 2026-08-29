extends Node
## Builds the world, advances it every frame, and owns the keys that
## change game speed. The one place the scene tree drives the simulation.

const FAST_SPEED: float = 10.0

@onready var _inspector: InspectorPanel = $InspectorPanel

var _world: World = World.new()


func _ready() -> void:
	_inspector.world = _world


func _process(delta: float) -> void:
	_world.tick(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_world.clock.speed = 0.0
		KEY_2:
			_world.clock.speed = 1.0
		KEY_3:
			_world.clock.speed = FAST_SPEED
		KEY_F3:
			_inspector.visible = not _inspector.visible
		_:
			return
	get_viewport().set_input_as_handled()
