class_name InspectorPanel
extends PanelContainer
## Reads the world and shows it while the game runs. Reads only, never
## writes, and works for records whether or not anything is spawned.

@onready var _clock_line: Label = $Margin/Rows/ClockLine
@onready var _elapsed_line: Label = $Margin/Rows/ElapsedLine
@onready var _speed_line: Label = $Margin/Rows/SpeedLine
@onready var _records_line: Label = $Margin/Rows/RecordsLine
@onready var _records: Tree = $Margin/Rows/Records

## Set by whoever owns the world. Nothing is shown until it is.
var world: World = null

var _shown_count: int = -1


func _ready() -> void:
	_records.columns = 2
	_records.hide_root = true
	_records.set_column_title(0, "Field")
	_records.set_column_title(1, "Value")
	_records.set_column_titles_visible(true)
	_records.set_column_expand_ratio(0, 1)
	_records.set_column_expand_ratio(1, 2)
	_records.set_column_clip_content(0, true)
	_records.set_column_clip_content(1, true)


func _process(_delta: float) -> void:
	if world == null or not visible:
		return
	_refresh_time()
	if world.count() != _shown_count:
		_rebuild_records()


func _refresh_time() -> void:
	var clock: Clock = world.clock
	_clock_line.text = "Year %d   %s   day %d of %d   %02d:%02d   %s" % [
		clock.year() + 1,
		clock.season_name(),
		clock.day_of_season() + 1,
		Clock.DAYS_PER_SEASON,
		clock.hour(),
		clock.minute(),
		"daytime" if clock.is_daytime() else "night",
	]
	_elapsed_line.text = "%d in-game seconds   day %d since the world began" % [
		int(clock.seconds),
		clock.day() + 1,
	]
	_speed_line.text = "Speed: %s" % _speed_text(clock.speed)


func _speed_text(speed: float) -> String:
	if is_zero_approx(speed):
		return "paused"
	if is_equal_approx(speed, 1.0):
		return "normal (1x)"
	return "%.1fx" % speed


func _rebuild_records() -> void:
	_records.clear()
	var root: TreeItem = _records.create_item()
	for record: Record in world.records():
		var row: TreeItem = _records.create_item(root)
		row.set_text(0, "#%d" % record.id)
		row.set_text(1, _type_name(record))
		row.collapsed = true
		for field: String in _fields(record):
			var child: TreeItem = _records.create_item(row)
			child.set_text(0, field)
			child.set_text(1, str(record.get(field)))
	_shown_count = world.count()
	_records_line.text = "Records: %d" % _shown_count


## Every variable the record's own script declares.
func _fields(record: Record) -> Array[String]:
	var out: Array[String] = []
	for property: Dictionary in record.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(property["name"]))
	return out


func _type_name(record: Record) -> String:
	var script: Script = record.get_script() as Script
	if script == null:
		return record.get_class()
	var global_name: String = str(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file().get_basename()
	return global_name
