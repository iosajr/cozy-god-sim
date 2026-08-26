extends GutTest
## Tests for scripts/folk_spawner_support.gd's maybe_log_divine_exposure()
## (issues #60/#61): logs a DivineExposure against a Folk member when a
## god-forced WeatherOverride (#58) is active at its body's position AND
## the body is within Presence-proximity of the camera rig, and -- as of
## issue #61 -- grants a discrete step of Favored at the exact moment an
## entry is actually logged, reusing Folk.gain_favored()'s existing
## Faith/Renown threshold-crossing logic unchanged. Mere proximity with
## no logged exposure (no override active, out of range, or a repeat
## frame of the same still-active override) must never grant Favored --
## the old continuous per-frame proximity timer (maybe_gain_favored()) is
## gone, not supplemented.
##
## global_position needs a live SceneTree to resolve correctly (see
## test_village_spawner.gd's doc comment), so bodies/camera_rig here go
## in via add_child_autofree() rather than bare .new(), same as that file.
## WeatherOverrides is class-level static state, so it's cleared between
## tests the same way test_weather_overrides.gd does.

const FAVORED_GAIN_AMOUNT := 5.0
const FAITH_THRESHOLD := 30.0
const RENOWN_THRESHOLD := 100.0


func after_each() -> void:
	WeatherOverrides.clear_all()


func _node_at(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	add_child_autofree(node)
	node.global_position = pos
	return node


func _log(folk: Folk, body: Node3D, camera_rig: Node3D, radius: float, absolute_time: float) -> void:
	FolkSpawnerSupport.maybe_log_divine_exposure(
		folk, body, camera_rig, radius, absolute_time,
		FAVORED_GAIN_AMOUNT, FAITH_THRESHOLD, RENOWN_THRESHOLD
	)


func test_logs_an_exposure_when_witnessed_and_overridden() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 50.0)

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

	_log(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_does_not_log_when_no_override_is_active_at_the_body() -> void:
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_is_a_noop_when_camera_rig_is_null() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)

	_log(folk, body, null, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_is_a_noop_when_body_is_null() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var camera_rig := _node_at(Vector3.ZERO)

	_log(folk, null, camera_rig, 8.0, 50.0)

	assert_eq(folk.divine_exposures.size(), 0)


func test_repeated_calls_for_the_same_active_override_log_only_once() -> void:
	# The same override instance stays active/witnessed across several
	# consecutive _process() frames -- must not flood the log.
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 10.0)
	_log(folk, body, camera_rig, 8.0, 20.0)
	_log(folk, body, camera_rig, 8.0, 30.0)

	assert_eq(folk.divine_exposures.size(), 1)


func test_a_new_override_after_the_first_ends_logs_again() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 10.0)
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_RAIN, 20.0, 30.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 5.0)
	_log(folk, body, camera_rig, 8.0, 25.0)

	assert_eq(folk.divine_exposures.size(), 2)


## Discrete Favored grant (issue #61): fires exactly when a divine-exposure
## entry gets logged, not from mere per-frame proximity. Replaces the old
## continuous per-frame proximity-based maybe_gain_favored(), removed
## entirely rather than kept alongside this.


func test_logging_an_exposure_grants_the_expected_favored_amount() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.favored, FAVORED_GAIN_AMOUNT)


func test_repeated_calls_for_the_same_active_override_grant_favored_only_once() -> void:
	# One logged entry, one Favored grant -- re-checking the same
	# still-active override across frames must not re-grant every frame.
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 10.0)
	_log(folk, body, camera_rig, 8.0, 20.0)
	_log(folk, body, camera_rig, 8.0, 30.0)

	assert_eq(folk.favored, FAVORED_GAIN_AMOUNT)


func test_a_new_override_after_the_first_grants_favored_again() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 10.0)
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_RAIN, 20.0, 30.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 5.0)
	_log(folk, body, camera_rig, 8.0, 25.0)

	assert_eq(folk.favored, FAVORED_GAIN_AMOUNT * 2.0)


func test_mere_proximity_with_no_active_override_grants_no_favored() -> void:
	# No logged exposure at all -- proximity alone must not increase
	# Favored (acceptance criterion, issue #61).
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.favored, 0.0)


func test_out_of_proximity_with_an_active_override_grants_no_favored() -> void:
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", true)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(500.0, 0.0, 0.0))

	_log(folk, body, camera_rig, 8.0, 50.0)

	assert_eq(folk.favored, 0.0)


func test_favored_grant_can_cross_the_faith_threshold() -> void:
	# Reuses Folk.gain_favored()'s existing threshold-crossing logic
	# unchanged -- only the trigger/amount-per-event changed, not the
	# Faith/Renown math itself.
	WeatherOverrides.register(Vector3.ZERO, WeatherQuery.CATEGORY_STORM, 0.0, 100.0)
	var folk := Folk.new("f1", false)
	var body := _node_at(Vector3.ZERO)
	var camera_rig := _node_at(Vector3(2.0, 0.0, 0.0))

	FolkSpawnerSupport.maybe_log_divine_exposure(
		folk, body, camera_rig, 8.0, 50.0, 40.0, FAITH_THRESHOLD, RENOWN_THRESHOLD
	)

	assert_true(folk.has_faith)
