extends GutTest
## Tests for scripts/folk_spawner_support.gd's maybe_log_divine_exposure()
## (issue #60): logs a DivineExposure against a Folk member when a
## god-forced WeatherOverride (#58) is active at its body's position AND
## the body is within Presence-proximity of the camera rig -- the same
## camera_rig-distance gate maybe_gain_favored() already uses above it,
## reused rather than inventing a second proximity check.
##
## global_position needs a live SceneTree to resolve correctly (see
## test_village_spawner.gd's doc comment), so bodies/camera_rig here go
## in via add_child_autofree() rather than bare .new(), same as that file.
## WeatherOverrides is class-level static state, so it's cleared between
## tests the same way test_weather_overrides.gd does.


func after_each() -> void:
	WeatherOverrides.clear_all()


func _node_at(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	add_child_autofree(node)
	node.global_position = pos
	return node


func test_logs_an_exposure_when_witnessed_and_overridden() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 1)
	var entry: DivineExposure = folk.divine_exposures[0]
	assert_eq(entry.kind, "weather_override")
	assert_eq(entry.detail, WeatherQuery.CATEGORY_STORM)
	assert_eq(entry.absolute_time, 50.0)


func test_does_not_log_when_outside_the_camera_proximity_radius() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(500.0, 0.0, 0.0))

	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_does_not_log_when_no_override_is_active_at_the_body() -> void:
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_is_a_noop_when_camera_rig_is_null() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)

	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, null, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_is_a_noop_when_body_is_null() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var camera_rig := _node_at(Vector3.ZERO)

	FolkSpawnerSupport.maybe_log_divine_exposure(folk, null, camera_rig, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_repeated_calls_for_the_same_active_override_log_only_once() -> void:
	# The same override instance stays active/witnessed across several
	# consecutive _process() frames -- must not flood the log.
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 10.0)
	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 20.0)
	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 30.0)

	assert_eq(folk.divine_exposures.size(), 1)


func test_a_new_override_after_the_first_ends_logs_again() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 10.0)
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_RAIN, 20.0, 30.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 5.0)
	FolkSpawnerSupport.maybe_log_divine_exposure(folk, body, camera_rig, 8.0, 25.0)

	assert_eq(folk.divine_exposures.size(), 2)
