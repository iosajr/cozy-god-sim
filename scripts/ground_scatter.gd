class_name GroundScatter
extends RefCounted
## GroundScatter
## Shared placeholder helper for scattering things across a flat ground
## plane — extracted out of world_gen.gd so world_gen.gd (trees/rocks) and
## village_spawner.gd (Villagers) don't duplicate the same random-position
## logic. Disposable, same spirit as world_gen.gd's primitives — nothing
## here is a real terrain/placement system.


## Returns a random point within `ground_size` (a square), inset 10% from
## the edges, at y = 0. `rng` is caller-owned so callers keep control of
## their own seeding/determinism.
static func random_ground_position(ground_size: float, rng: RandomNumberGenerator) -> Vector3:
	var half := ground_size * 0.5 * 0.9
	return Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
