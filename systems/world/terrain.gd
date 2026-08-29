class_name Terrain
extends RefCounted
## The ground behind one interface: how high it is, and whether it can be
## walked. Whoever asks may not assume the answer.


## Ground height at a world-space point.
func height_at(_x: float, _z: float) -> float:
	push_error("Terrain.height_at is not implemented")
	return 0.0


## Whether an entity can stand at a world-space point.
func is_walkable(_x: float, _z: float) -> bool:
	push_error("Terrain.is_walkable is not implemented")
	return false
