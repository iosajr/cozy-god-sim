class_name WorldSystem
extends RefCounted
## One step of the simulation. The world decides when each of these runs
## and in what order; none of them advance themselves.


## Advances by the in-game seconds that just passed.
func advance(_elapsed: float) -> void:
	pass
