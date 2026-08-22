class_name House
extends RefCounted
## Provisional Housing data shape — not final architecture. No
## assignment logic, no construction trigger, no occupancy enforcement.

const MIN_CAPACITY: int = 2
const MAX_CAPACITY: int = 8
const DEFAULT_CAPACITY: int = 4

var capacity: int
var position: Vector3


func _init(p_capacity: int = DEFAULT_CAPACITY, p_position: Vector3 = Vector3.ZERO) -> void:
	capacity = p_capacity
	position = p_position
