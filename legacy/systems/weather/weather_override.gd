class_name WeatherOverride
extends RefCounted
## A single God-forced weather interval (issue #58): plain data recording
## that a Domain-holding God deliberately forced `category` over a
## circular area (`position`, `radius`) for game-time in
## [start_time, end_time] -- consistent with existing Pantheon lore that a
## God can perform an act "deliberately, at will," parallel to a
## storms-domain God forcing rain the way a death-domain God causes a
## specific death.
##
## Just a record plus a pure membership check -- nothing here advances
## per-tick. WeatherOverrides (systems/weather_overrides.gd) is what
## register()s and later consults these.

var position: Vector3
var radius: float
var category: String
var start_time: float
var end_time: float


func _init(
	p_position: Vector3, p_radius: float, p_category: String, p_start_time: float, p_end_time: float
) -> void:
	position = p_position
	radius = p_radius
	category = p_category
	start_time = p_start_time
	end_time = p_end_time


## True if `query_position` falls within this override's radius of
## `position` and `absolute_time` falls within [start_time, end_time]
## (inclusive on both ends).
func covers(query_position: Vector3, absolute_time: float) -> bool:
	if absolute_time < start_time or absolute_time > end_time:
		return false
	return query_position.distance_to(position) <= radius
