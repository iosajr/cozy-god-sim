class_name FolkSpawnerSupport
extends RefCounted
## Shared helpers for the per-type spawners (village_spawner.gd,
## sheep_spawner.gd, farm_spawner.gd, house_spawner.gd).


## Grants Favored (scaled by delta) if `body` is within `radius` of
## `camera_rig`. No-op if either is null.
static func maybe_gain_favored(
	folk: Folk,
	body: Node3D,
	camera_rig: Node3D,
	radius: float,
	gain_rate: float,
	delta: float,
	faith_threshold: float,
	renown_threshold: float
) -> void:
	if camera_rig == null or body == null:
		return
	if body.global_position.distance_to(camera_rig.global_position) <= radius:
		folk.gain_favored(gain_rate * delta, faith_threshold, renown_threshold)


## Appends any item from `spawned` not already present in `target`.
static func sync_new_items(spawned: Array, target: Array) -> void:
	for item in spawned:
		if not target.has(item):
			target.append(item)


## Placeholder body: a MeshInstance3D with `mesh`/`material`, added as a
## child of `parent` at `y_offset`. `material` is caller-owned — pass a
## shared instance to tint a whole population at once, or a fresh one per
## call for independently-tintable bodies.
static func spawn_body(parent: Node3D, mesh: Mesh, material: StandardMaterial3D, y_offset: float) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = material
	body.position.y = y_offset
	parent.add_child(body)
	return body
