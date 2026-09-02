class_name FlatTerrain
extends Terrain
## Ground at y = 0, walkable everywhere. Stands in until there is real
## terrain to answer for.


func height_at(_x: float, _z: float) -> float:
	return 0.0


func is_walkable(_x: float, _z: float) -> bool:
	return true
