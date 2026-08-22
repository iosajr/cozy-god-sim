class_name GroundScatter
extends RefCounted
## Shared placeholder helper for scattering things across a flat ground
## plane. Lives in scripts/, not systems/ — a placement/art utility, not
## simulation logic.


## Random point within `ground_size` (a square), inset 10% from the
## edges, at y = 0.
static func random_ground_position(ground_size: float, rng: RandomNumberGenerator) -> Vector3:
	var half := ground_size * 0.5 * 0.9
	return Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))


## Resolves the real ground size from `world_gen` (a sibling node owning
## the ground plane), falling back to `fallback` if unset/unavailable.
static func resolve_ground_size(world_gen: Node, fallback: float) -> float:
	if world_gen != null and "ground_size" in world_gen:
		return world_gen.ground_size
	return fallback
