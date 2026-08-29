extends Node
## Holds the world, advances it every frame, and wires the scene's parts
## to it. The one place the scene tree drives the simulation.

const FAST_SPEED: float = 10.0
const SEED_VALUE: int = 1

@onready var _rig: CameraRig = $CameraRig
@onready var _spawner: ViewSpawner = $ViewSpawner
@onready var _inspector: InspectorPanel = $InspectorPanel

var _world: World = World.new()


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED_VALUE
	WorldSeed.populate(_world, rng)

	_spawner.world = _world
	_spawner.focus = _rig

	_inspector.world = _world
	_inspector.spawner = _spawner
	_inspector.record_selected.connect(_on_record_selected)
	_inspector.record_focused.connect(_on_record_focused)


func _process(delta: float) -> void:
	_world.tick(delta)


## Picking a row marks that entity out in the world.
func _on_record_selected(id: int) -> void:
	_spawner.highlight(id)


## Flying to a record means its own position, or its settlement's centre.
func _on_record_focused(id: int) -> void:
	var entity: Entity = _world.get_record(id) as Entity
	if entity != null:
		_rig.focus_on(entity.position)
		return
	var settlement: Settlement = _world.get_record(id) as Settlement
	if settlement != null:
		_rig.focus_on(settlement.centre)


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
