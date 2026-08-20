class_name GroundRay
extends RefCounted
## GroundRay
## Pure ray/ground-plane (y = 0) intersection helper — the shared seam
## behind camera_rig.gd's drag-pan and the Presence-light demo (issue #5).
## Same "small static-style helper" shape as ground_scatter.gd: no scene
## tree, no physics query, just vector math, so it's fully unit testable
## in isolation.
##
## The ground is assumed flat at y = 0, matching the current placeholder
## world (see CLAUDE.md) — not a physics raycast against GroundBody. Real
## (non-flat) terrain is future work, not this helper's concern.


## Intersects a ray (given by `ray_origin` and `ray_direction`) with the
## y = 0 ground plane. Returns a Dictionary with:
##   "hit": bool — true if the ray meets the plane in front of its origin
##   "point": Vector3 — the intersection point when "hit" is true,
##            otherwise Vector3.ZERO (a defined not-a-hit result, never
##            NaN and never a crash).
## A ray parallel to the plane (`ray_direction.y == 0`), or one that only
## meets the plane behind its origin (facing away), is not a hit.
static func intersect_ground_plane(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	if is_zero_approx(ray_direction.y):
		return {"hit": false, "point": Vector3.ZERO}

	var t := -ray_origin.y / ray_direction.y
	if t < 0.0:
		return {"hit": false, "point": Vector3.ZERO}

	return {"hit": true, "point": ray_origin + ray_direction * t}
