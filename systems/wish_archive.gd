class_name WishArchive
extends RefCounted
## Local, durable, inspectable record of Wishes approved via the Folk
## Console -- replaces publishing a real GitHub issue via `gh`. No
## network/git dependency; approving is a purely local action.
##
## Distinct from RenownedThoughtMemory (issue #50): that's a curated
## situation-to-response cache used to skip live model calls during
## gameplay, this is a flat, append-only developer log of every approved
## Wish. Persisted under DEFAULT_PATH under res://, a deliberate dev-time
## choice for easy hand-inspection/editing, same reasoning as
## RenownedThoughtMemory.

const DEFAULT_PATH := "res://data/approved_wishes.tres"

var _path: String
var _entries: Array[WishArchiveEntry] = []


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_load()


## Appends and persists immediately. Returns the saved entry.
func append(villager_name: String, in_character: String, wish: String) -> WishArchiveEntry:
	var entry := WishArchiveEntry.new()
	entry.villager_name = villager_name
	entry.in_character = in_character
	entry.wish = wish
	entry.saved_at_unix_time = int(Time.get_unix_time_from_system())
	_entries.append(entry)
	_save()
	return entry


func all_entries() -> Array[WishArchiveEntry]:
	return _entries.duplicate()


func _load() -> void:
	_entries.clear()
	if not FileAccess.file_exists(_path):
		return
	var book := ResourceLoader.load(_path) as WishArchiveBook
	if book == null:
		return
	for entry in book.entries:
		_entries.append(entry)


func _save() -> void:
	var dir := _path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var book := WishArchiveBook.new()
	book.entries = _entries
	ResourceSaver.save(book, _path)
