class_name FolkSpawnerSupport
extends RefCounted
## Shared helpers for the per-type spawners (village_spawner.gd,
## sheep_spawner.gd, farm_spawner.gd, house_spawner.gd).


## Logs a divine-exposure entry (issue #60) against `folk` if a
## god-forced WeatherOverride (#58) is active at `body`'s position AND
## `body` is within `radius` of `camera_rig` -- a placeholder Presence-
## proximity gate ("proximity gates whether it counts as witnessed, per
## Presence needing the Player's actual attention"), not a deep new
## Presence subsystem. No-op if camera_rig/body are null, the body is out
## of range, or nothing is currently overriding weather there.
##
## When an entry is actually logged (not deduped -- see
## Folk.log_divine_exposure()'s return value), also grants a discrete
## `favored_gain_amount` step of Favored via `folk.gain_favored()`,
## reusing its existing Faith/Renown threshold-crossing logic unchanged
## (issue #61). This replaces the old continuous per-frame proximity-
## based Favored gain (formerly maybe_gain_favored(), removed) --
## Favored now rises only *because* something was actually witnessed and
## logged, never from idle proximity/dwell-time alone.
static func maybe_log_divine_exposure(
	folk: Folk,
	body: Node3D,
	camera_rig: Node3D,
	radius: float,
	absolute_time: float,
	favored_gain_amount: float,
	faith_threshold: float,
	renown_threshold: float
) -> void:
	if not _is_within_presence(body, camera_rig, radius):
		return
	var override := WeatherOverrides.active_override_at(body.global_position, absolute_time)
	if override == null:
		return
	var logged := folk.log_divine_exposure("weather_override", override.category, absolute_time, override)
	if logged:
		folk.gain_favored(favored_gain_amount, faith_threshold, renown_threshold)


## Shared Presence-proximity gate: true if both `body` and `camera_rig`
## exist and `body` is within `radius` of it. Kept as a single spot
## rather than re-deriving distance_to() every frame.
static func _is_within_presence(body: Node3D, camera_rig: Node3D, radius: float) -> bool:
	if camera_rig == null or body == null:
		return false
	return body.global_position.distance_to(camera_rig.global_position) <= radius


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
