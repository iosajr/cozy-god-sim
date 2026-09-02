class_name Record
extends RefCounted
## Base for everything the world stores. Anything referring to a record
## holds its id, never the record itself.

## Given by the world when the record is added. 0 means not stored yet.
var id: int = 0
