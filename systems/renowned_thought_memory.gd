class_name RenownedThoughtMemory
extends RefCounted
## Curated store of past {situation signature -> response} pairs for
## Renowned Folk interactions (issue #46/#50) -- lets a close-enough
## repeat situation (see systems/renowned_situation_signature.gd) reuse a
## previously-approved response instead of always asking the model again.
##
## Nothing here calls the model itself -- find()/remember() are plain,
## directly-testable operations; a later ticket (#52) is what actually
## wires a live click-to-interact flow through this.
##
## remember() is an explicit curation step, never automatic -- callers
## decide when a response is worth keeping. Saved entries persist to
## DEFAULT_PATH under res://, a deliberate dev-time choice (not user://)
## so they're easy to hand-inspect/edit; see issue #46's Implementation
## Decisions.

const DEFAULT_PATH := "res://data/renowned_thought_memory.tres"

var _path: String
var _entries: Array[RenownedThoughtMemoryEntry] = []


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_load()


## Returns the saved entry for this exact signature, or null if none.
func find(signature: String) -> RenownedThoughtMemoryEntry:
	for entry in _entries:
		if entry.signature == signature:
			return entry
	return null


## Saves (or replaces, if this signature was already remembered) a
## response for future reuse, then persists immediately. Returns the
## saved entry.
func remember(
	signature: String, villager_name: String, in_character: String, wish: String
) -> RenownedThoughtMemoryEntry:
	var entry := find(signature)
	if entry == null:
		entry = RenownedThoughtMemoryEntry.new()
		entry.signature = signature
		_entries.append(entry)
	entry.villager_name = villager_name
	entry.in_character = in_character
	entry.wish = wish
	entry.saved_at_unix_time = int(Time.get_unix_time_from_system())
	_save()
	return entry


func all_entries() -> Array[RenownedThoughtMemoryEntry]:
	return _entries.duplicate()


func _load() -> void:
	_entries.clear()
	if not FileAccess.file_exists(_path):
		return
	var book := ResourceLoader.load(_path) as RenownedThoughtMemoryBook
	if book == null:
		return
	for entry in book.entries:
		_entries.append(entry)


func _save() -> void:
	var dir := _path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var book := RenownedThoughtMemoryBook.new()
	book.entries = _entries
	ResourceSaver.save(book, _path)
