class_name GroundRay
extends RefCounted
## Pure ray/ground-plane (y = 0) intersection helper. Ground is assumed
## flat — not a physics raycast; real terrain is future work.


## Returns {"hit": bool, "point": Vector3}. Not a hit if the ray is
## parallel to the plane or meets it behind its own origin.
static func intersect_ground_plane(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	if is_zero_approx(ray_direction.y):
		return {"hit": false, "point": Vector3.ZERO}

	var t := -ray_origin.y / ray_direction.y
	if t < 0.0:
		return {"hit": false, "point": Vector3.ZERO}

	return {"hit": true, "point": ray_origin + ray_direction * t}
