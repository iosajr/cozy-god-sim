class_name RenownedThoughtMemoryEntry
extends Resource
## One curated {situation signature -> response} pair for a Renowned Folk
## interaction -- see systems/renowned_thought_memory.gd.

@export var signature: String = ""
@export var villager_name: String = ""
@export var in_character: String = ""
@export var wish: String = ""
@export var saved_at_unix_time: int = 0
