extends Node3D
## Spawns one Village's Villagers as placeholder 3D bodies + nameplates,
## drives their Thought/Wish rerolling, Favored/Renown, Survival, and Task
## execution each frame, and opens the dialogue box for a Renowned
## Villager's click.

@export var villager_count: int = 6
@export var ground_size: float = 200.0
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 2
@export var reroll_interval_min: float = 12.0
@export var reroll_interval_max: float = 24.0
## Stands in for the Player's position.
@export var camera_rig_path: NodePath = ^"../CameraRig"
@export var favored_radius: float = 8.0
@export var favored_gain_rate: float = 5.0
@export var dialogue_box_path: NodePath = ^"../DialogueBox"
@export var villager_move_speed: float = 4.0

## No real per-Villager name exists yet.
const RENOWNED_VILLAGER_SPEAKER_NAME := "A Renowned Villager"

## Placeholder water-source position (issue #38), fixed relative to the
## Village's own site_position — same "single fixed point" tier, just a
## second one a Water Task's fetch leg visits before the claimed Farm.
const WATER_SOURCE_OFFSET := Vector3(12.0, 0.0, 0.0)

var village: Village

var _rng := RandomNumberGenerator.new()
var _nameplates: Dictionary = {}  # Villager -> VillagerNameplate
var _bodies: Dictionary = {}  # Villager -> MeshInstance3D
var _click_bodies: Dictionary = {}  # Villager -> StaticBody3D
var _villagers_by_click_body: Dictionary = {}  # StaticBody3D -> Villager
var _movers: Dictionary = {}  # Villager -> Mover (also the spawned root)
var _debug_infos: Dictionary = {}  # Villager -> FolkDebugInfo

## Shared across every spawned body -- built once, reused by both the
## initial batch (_spawn_villagers()) and any newborn spawned later
## (_spawn_one_villager(), issue #42).
var _body_mat: StandardMaterial3D
var _body_mesh: CapsuleMesh
var _click_shape: CapsuleShape3D


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value

	village = Village.new(seed_value)
	village.reroll_interval_min = reroll_interval_min
	village.reroll_interval_max = reroll_interval_max
	# Real spawned world position, not the Vector3.ZERO default -- Eat/
	# Sleep/Farm-delivery/Watering destinations read this (issue #31).
	village.site_position = global_position
	village.water_source_position = global_position + WATER_SOURCE_OFFSET
	village.populate(villager_count)
	GameState.village = village

	_spawn_villagers()

	var camera_rig: CameraRig = get_node_or_null(camera_rig_path)
	if camera_rig:
		camera_rig.dialogue_target_clicked.connect(_on_dialogue_target_clicked)


func _process(delta: float) -> void:
	village.advance_thoughts(delta, GameState.pantheon)
	village.advance_eating_checks(delta)
	village.advance_sleep_checks(delta)
	# Issue #41 built and tested this but never wired it in here -- without
	# it no Villager ever actually gets paired_with set in a running game,
	# which would make issue #42's Reproduce Task unreachable too.
	village.advance_pairing(delta)
	var camera_rig: Node3D = get_node_or_null(camera_rig_path)
	for villager in village.villagers:
		if not _movers.has(villager):
			# A newborn added by advance_gestation() (issue #42) -- give it
			# the same body/nameplate/click-body/debug-info every other
			# Villager gets, same shape as _spawn_villagers()'s initial
			# batch, or every dictionary lookup below crashes on it.
			_spawn_one_villager(villager)
		villager.advance(delta)
		_advance_task_execution(villager, delta)
		var nameplate: VillagerNameplate = _nameplates[villager]
		_update_nameplate(villager, nameplate)
		if villager.is_renowned and nameplate.modulate != VillagerNameplate.RENOWNED_COLOR:
			nameplate.set_renowned(true)
			var click_body: StaticBody3D = _click_bodies.get(villager)
			if click_body and not click_body.is_in_group(CameraRig.DIALOGUE_CLICK_GROUP):
				click_body.add_to_group(CameraRig.DIALOGUE_CLICK_GROUP)
		FolkSpawnerSupport.maybe_gain_favored(
			villager, _bodies.get(villager), camera_rig, favored_radius, favored_gain_rate, delta,
			Villager.DEFAULT_FAITH_THRESHOLD, Villager.DEFAULT_RENOWN_THRESHOLD
		)
		_debug_infos[villager].sync(villager)


## Shows the Name/Age baseline whenever there's no active Thought to
## display (issue #43); otherwise shows the Thought, same as before.
## Skips the write if the nameplate already shows the right text, same
## guard the pre-#43 code used for Thought alone.
func _update_nameplate(villager: Villager, nameplate: VillagerNameplate) -> void:
	if villager.current_thought.is_empty():
		var baseline := VillagerNameplate.format_baseline(villager.villager_name, villager.age_years)
		if nameplate.text != baseline:
			nameplate.text = baseline
	elif nameplate.text != villager.current_thought:
		nameplate.show_thought(villager.current_thought)


## Drives one Villager's Task through Village's execution seam: (re)assign,
## move the Mover toward the destination, resolve once arrived.
func _advance_task_execution(villager: Villager, delta: float) -> void:
	# GameState.time_of_day stamps a dropped-cargo resource entry's
	# last_observed marker (issue #37) when this interrupts a carrying
	# Villager -- see Village.advance_task_assignment()/interrupt_task().
	var task_changed := village.advance_task_assignment(villager, GameState.time_of_day)
	var mover: Mover = _movers[villager]
	villager.position = mover.global_position
	var task := villager.current_task
	if task == null:
		return
	var is_idle := task.kind == Task.KIND_IDLE
	var destination := village.idle_destination(villager) if is_idle else village.task_destination(task, villager)
	if task_changed:
		mover.move_to(destination)
	if not villager.task_resolving:
		if village.has_reached_destination(villager.position, destination, mover.arrival_threshold):
			var food_before: int = GameState.resources.food
			village.begin_resolving_task(villager, GameState.resources, GameState.day_speed)
			if GameState.resources.food != food_before:
				GameState.resource_changed.emit("food", GameState.resources.food)
			# A Water Task's fetch leg (issue #38) doesn't finish on
			# reaching the water source -- current_task survives, just
			# pointed at a new destination (the claimed Farm). Nothing else
			# calls move_to() again here since task_changed is false (same
			# Task instance), so redirect explicitly, mirroring how
			# advance_idle()'s fresh wander leg below gets its own.
			if task.kind == Task.KIND_WATER and villager.current_task == task:
				mover.move_to(village.task_destination(task, villager))
	elif task.kind == Task.KIND_SLEEP:
		village.advance_sleeping(villager, delta)
	elif task.kind == Task.KIND_REPRODUCE:
		village.advance_gestation(villager, delta)
	elif is_idle:
		if village.advance_idle(villager, delta):
			mover.move_to(village.idle_destination(villager))


func _spawn_villagers() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.85, 0.72, 0.58)

	_body_mesh = CapsuleMesh.new()
	_body_mesh.radius = 0.3
	_body_mesh.height = 1.6

	_click_shape = CapsuleShape3D.new()
	_click_shape.radius = 0.3
	_click_shape.height = 1.6

	for villager in village.villagers:
		_spawn_one_villager(villager)


## Spawned body/click-body/nameplate/debug-info for one Villager -- the
## initial batch (_spawn_villagers()) and a newborn added mid-game by
## advance_gestation() (issue #42) both go through this.
func _spawn_one_villager(villager: Villager) -> void:
	var root := Mover.new()
	root.name = villager.id
	root.position = GroundScatter.random_ground_position(ground_size, _rng)
	root.speed = villager_move_speed
	add_child(root)
	_movers[villager] = root

	_bodies[villager] = FolkSpawnerSupport.spawn_body(root, _body_mesh, _body_mat, 0.8)

	var click_body := StaticBody3D.new()
	click_body.position.y = 0.8
	root.add_child(click_body)
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = _click_shape
	click_body.add_child(collision_shape)
	_click_bodies[villager] = click_body
	_villagers_by_click_body[click_body] = villager

	var nameplate := VillagerNameplate.new()
	nameplate.position.y = 1.9
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.font_size = 24
	nameplate.outline_size = 6
	root.add_child(nameplate)
	_nameplates[villager] = nameplate
	_update_nameplate(villager, nameplate)

	var debug_info := FolkDebugInfo.new()
	debug_info.name = "DebugInfo"
	root.add_child(debug_info)
	_debug_infos[villager] = debug_info


func _on_dialogue_target_clicked(body: Node3D) -> void:
	var villager: Villager = _villagers_by_click_body.get(body)
	if villager == null or not villager.is_renowned:
		return
	var dialogue_box: DialogueBox = get_node_or_null(dialogue_box_path)
	if dialogue_box == null:
		return
	dialogue_box.show_dialogue(RENOWNED_VILLAGER_SPEAKER_NAME, _dialogue_lines_for(villager))


## Reuses existing data only — no invented dialogue writing.
func _dialogue_lines_for(villager: Villager) -> Array[String]:
	var lines: Array[String] = [villager.current_thought]
	if villager.current_wish != null:
		lines.append(villager.current_wish.text)
	return lines
