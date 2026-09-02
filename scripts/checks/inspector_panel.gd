class_name InspectorPanel
extends PanelContainer
## Reads the world and shows it while the game runs. Reads only, never
## writes, and works for records whether or not anything is spawned.

## A row was picked, or asked to be flown to. What that means is decided
## by whoever owns the world.
signal record_selected(id: int)
signal record_focused(id: int)

@onready var _clock_line: Label = $Margin/Rows/ClockLine
@onready var _season_line: Label = $Margin/Rows/SeasonLine
@onready var _speed_line: Label = $Margin/Rows/SpeedLine
@onready var _scope: CheckButton = $Margin/Rows/Scope
@onready var _count_line: Label = $Margin/Rows/CountLine
@onready var _records: Tree = $Margin/Rows/Records
@onready var _detail: Tree = $Margin/Rows/Detail

## Set by whoever owns the world. Nothing is shown until it is.
var world: World = null

## Asked what is on screen while the scope is narrowed to it.
var spawner: ViewSpawner = null

var _listed: Array[int] = []
var _selected_id: int = 0
var _detail_rows: Dictionary = {}
var _dirty: bool = true
var _collapsed: Dictionary = {}


func _ready() -> void:
	_prepare(_records, "Name", "Kind")
	_prepare(_detail, "Field", "Value")
	_scope.toggled.connect(_on_scope_toggled)
	_records.item_selected.connect(_on_record_selected)
	_records.item_activated.connect(_on_record_activated)
	_records.item_collapsed.connect(_on_item_collapsed)


func _prepare(tree: Tree, first: String, second: String) -> void:
	tree.columns = 2
	tree.hide_root = true
	tree.set_column_title(0, first)
	tree.set_column_title(1, second)
	tree.set_column_titles_visible(true)
	tree.set_column_expand_ratio(0, 1)
	tree.set_column_expand_ratio(1, 1)
	tree.set_column_clip_content(0, true)
	tree.set_column_clip_content(1, true)


func _process(_delta: float) -> void:
	if world == null or not visible:
		return
	_refresh_time()
	var ids: Array[int] = _ids_in_scope()
	if _dirty or ids != _listed:
		_rebuild_records(ids)
	_refresh_detail()


func _refresh_time() -> void:
	var clock: Clock = world.clock
	_clock_line.text = "%d:%02d    day %d    year %d" % [
		clock.hour(),
		clock.minute(),
		clock.day_of_year() + 1,
		clock.year() + 1,
	]
	_season_line.text = clock.season_name()
	_speed_line.text = "Speed: %s" % _speed_text(clock.speed)


func _speed_text(speed: float) -> String:
	if is_zero_approx(speed):
		return "paused"
	if is_equal_approx(speed, 1.0):
		return "normal (1x)"
	return "%.1fx" % speed


## Everything, or only what the spawner currently draws.
func _ids_in_scope() -> Array[int]:
	var ids: Array[int] = []
	if _scope.button_pressed and spawner != null:
		ids = spawner.on_screen_ids()
	else:
		for record: Record in world.records():
			if record is Entity:
				ids.append(record.id)
	ids.sort()
	return ids


func _rebuild_records(ids: Array[int]) -> void:
	_records.clear()
	var root: TreeItem = _records.create_item()
	var groups: Dictionary = {}
	for id: int in ids:
		var entity: Entity = world.get_record(id) as Entity
		if entity == null:
			continue
		var group: TreeItem = _group_for(root, groups, entity.home_id)
		var row: TreeItem = _records.create_item(group)
		row.set_text(0, _entity_name(entity))
		row.set_text(1, _species_name(entity))
		row.set_metadata(0, entity.id)
	for home_id: int in groups:
		var group: TreeItem = groups[home_id]
		group.set_text(1, "%d here" % group.get_child_count())
	_listed = ids
	_dirty = false
	_count_line.text = "%d of %d entities" % [ids.size(), _entity_total()]
	_restore_selection()


## One row per settlement, made the first time one of its people appears.
func _group_for(root: TreeItem, groups: Dictionary, home_id: int) -> TreeItem:
	if groups.has(home_id):
		var found: TreeItem = groups[home_id]
		return found
	var group: TreeItem = _records.create_item(root)
	var home: Settlement = world.get_record(home_id) as Settlement
	group.set_text(0, home.display_name if home != null else "No settlement")
	group.set_metadata(0, home_id)
	group.collapsed = _collapsed.get(home_id, false)
	groups[home_id] = group
	return group


## Remembers a settlement row left collapsed, so a rebuild does not
## spring it open again.
func _on_item_collapsed(item: TreeItem) -> void:
	_collapsed[int(item.get_metadata(0))] = item.collapsed


func _entity_name(entity: Entity) -> String:
	if entity.display_name.is_empty():
		return "#%d" % entity.id
	return entity.display_name


func _species_name(entity: Entity) -> String:
	if entity.species == null:
		return _type_name(entity)
	return entity.species.display_name


func _entity_total() -> int:
	var total: int = 0
	for record: Record in world.records():
		if record is Entity:
			total += 1
	return total


func _restore_selection() -> void:
	if _selected_id == 0:
		return
	var row: TreeItem = _find_row(_selected_id)
	if row != null:
		row.select(0)


func _find_row(id: int) -> TreeItem:
	var root: TreeItem = _records.get_root()
	if root == null:
		return null
	for group: TreeItem in root.get_children():
		if int(group.get_metadata(0)) == id:
			return group
		for row: TreeItem in group.get_children():
			if int(row.get_metadata(0)) == id:
				return row
	return null


func _on_scope_toggled(_pressed: bool) -> void:
	_dirty = true


func _on_record_selected() -> void:
	var item: TreeItem = _records.get_selected()
	if item == null:
		return
	_selected_id = int(item.get_metadata(0))
	_rebuild_detail()
	record_selected.emit(_selected_id)


func _on_record_activated() -> void:
	if _selected_id != 0:
		record_focused.emit(_selected_id)


func _rebuild_detail() -> void:
	_detail.clear()
	_detail_rows = {}
	var record: Record = world.get_record(_selected_id)
	if record == null:
		return
	var root: TreeItem = _detail.create_item()
	var header: TreeItem = _detail.create_item(root)
	header.set_text(0, "#%d" % record.id)
	header.set_text(1, _type_name(record))
	for field: String in _fields(record):
		var row: TreeItem = _detail.create_item(root)
		row.set_text(0, field)
		_detail_rows[field] = row
	_refresh_detail()


func _refresh_detail() -> void:
	var record: Record = world.get_record(_selected_id)
	if record == null:
		return
	for field: String in _detail_rows:
		var row: TreeItem = _detail_rows[field]
		row.set_text(1, _value_text(record.get(field)))


## Every variable the object's own script declares.
func _fields(object: Object) -> Array[String]:
	var out: Array[String] = []
	for property: Dictionary in object.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(property["name"]))
	return out


func _type_name(object: Object) -> String:
	var script: Script = object.get_script() as Script
	if script == null:
		return object.get_class()
	var global_name: String = str(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file().get_basename()
	return global_name


## Objects read as what they are called, not as a pointer. A list reads as
## its count and each member in turn, so it never prints as a pointer dump.
func _value_text(value: Variant) -> String:
	if typeof(value) == TYPE_ARRAY:
		var array: Array = value
		if array.is_empty():
			return "none"
		var parts: Array[String] = []
		for item: Variant in array:
			parts.append(_value_text(item))
		return "%d — %s" % [array.size(), ", ".join(parts)]
	if typeof(value) != TYPE_OBJECT:
		return str(value)
	var object: Object = value
	if _fields(object).has("display_name"):
		return str(object.get("display_name"))
	if _fields(object).has("what"):
		return str(object.get("what"))
	return _type_name(object)
