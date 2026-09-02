class_name ViewSpawner
extends Node3D
## Creates a visual for the entities nearest the camera and frees the rest.
## Reads the world and never writes to it.

const HIGHLIGHT_COLOR := Color(1.0, 0.93, 0.62)

## How far out to consider anything at all.
@export var view_radius: float = 200.0

## The most visuals to hold at once. Nearest win, so this is the real
## limit and the radius is only a first cut.
@export var max_visuals: int = 200

## The most to build in one frame, so a big camera move cannot hitch.
@export var spawn_budget: int = 8

## What to read, and the point to measure distance from.
var world: World = null
var focus: Node3D = null

var _visuals: Dictionary[int, Node3D] = {}
var _materials: Dictionary = {}
var _highlight_material: StandardMaterial3D = null
var _highlighted_id: int = 0


func _process(_delta: float) -> void:
	if world == null or focus == null:
		return
	var wanted: Array[int] = _nearest_ids()
	_free_visuals_outside(wanted)

	var built: int = 0
	for id: int in wanted:
		var entity: Entity = world.get_record(id) as Entity
		if entity == null:
			continue
		if not _visuals.has(id):
			if built >= spawn_budget:
				continue
			var visual: Node3D = _build_visual(entity)
			_visuals[id] = visual
			add_child(visual)
			built += 1
		_visuals[id].position = entity.position


## Entities within reach, nearest first, cut off at the cap.
func _nearest_ids() -> Array[int]:
	var centre: Vector3 = focus.global_position
	var reach: float = view_radius * view_radius
	var candidates: Array = []
	for record: Record in world.records():
		var entity: Entity = record as Entity
		if entity == null:
			continue
		var distance: float = entity.position.distance_squared_to(centre)
		if distance > reach:
			continue
		candidates.append([distance, entity.id])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var ids: Array[int] = []
	for candidate: Array in candidates:
		if ids.size() >= max_visuals:
			break
		ids.append(int(candidate[1]))
	return ids


## The entities actually inside the camera's view, which is a narrower
## question than which ones have a visual.
func on_screen_ids() -> Array[int]:
	var ids: Array[int] = []
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return ids
	for id: int in _visuals:
		var entity: Entity = world.get_record(id) as Entity
		if entity == null or entity.species == null:
			continue
		var middle: Vector3 = entity.position + Vector3(0.0, entity.species.height * 0.5, 0.0)
		if camera.is_position_in_frustum(middle):
			ids.append(id)
	return ids


## Picks one entity out. An id with nothing spawned just clears the last.
func highlight(id: int) -> void:
	if id == _highlighted_id:
		return
	_paint(_highlighted_id, false)
	_highlighted_id = id
	_paint(_highlighted_id, true)


func _build_visual(entity: Entity) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Entity%d" % entity.id

	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.height = entity.species.height
	capsule.radius = entity.species.height * 0.17

	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = capsule
	body.position = Vector3(0.0, entity.species.height * 0.5, 0.0)
	body.material_override = _highlight() if entity.id == _highlighted_id else _material_for(entity.species)
	root.add_child(body)
	return root


## One material per species, made the first time it is asked for.
func _material_for(species: Species) -> StandardMaterial3D:
	if not _materials.has(species):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = species.body_color
		material.metallic = 0.0
		material.roughness = 1.0
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_materials[species] = material
	var cached: StandardMaterial3D = _materials[species]
	return cached


func _highlight() -> StandardMaterial3D:
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.albedo_color = HIGHLIGHT_COLOR
		_highlight_material.metallic = 0.0
		_highlight_material.roughness = 1.0
		_highlight_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_highlight_material.emission_enabled = true
		_highlight_material.emission = HIGHLIGHT_COLOR
		_highlight_material.emission_energy_multiplier = 0.5
	return _highlight_material


## Repaints one entity in either its species colour or the highlight.
func _paint(id: int, highlighted: bool) -> void:
	if id == 0 or not _visuals.has(id):
		return
	var body: MeshInstance3D = _visuals[id].get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	if highlighted:
		body.material_override = _highlight()
		return
	var entity: Entity = world.get_record(id) as Entity
	if entity != null:
		body.material_override = _material_for(entity.species)


func _free_visuals_outside(wanted: Array[int]) -> void:
	var keep: Dictionary[int, bool] = {}
	for id: int in wanted:
		keep[id] = true
	for id: int in _visuals.keys():
		if keep.has(id):
			continue
		_visuals[id].queue_free()
		_visuals.erase(id)
