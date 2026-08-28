class_name RenownedThoughtMemoryBook
extends Resource
## Serializable wrapper for a full RenownedThoughtMemory entry list -- a
## real, `class_name`-registered file (not an inner class) so its script
## reference round-trips through ResourceSaver/ResourceLoader correctly;
## an inner class here would save as an anonymous, sourceless GDScript
## sub-resource that reloads as a bare Resource with no `entries`.

@export var entries: Array[RenownedThoughtMemoryEntry] = []
