class_name LocationResource
extends RefCounted
## A perishable Known Territory resource entry (ADR-0004, issue #37): a
## spot a Village's Folk know holds a recoverable amount of something --
## position, amount, and a bare last-observed marker. A second, sibling
## shape to systems/location.gd's Location, not a replacement for it --
## Location's plain point-of-interest shape (name + tags, no position, no
## amount) is untouched; Village keeps the two in separate arrays
## (known_locations vs. known_resources).
##
## Currently seeded only by dropped Deliver-Task cargo (see
## VillageTasks.interrupt_task()) -- ADR-0004's other floated source, a
## spotted wild herd, is real future direction, not built here.
##
## last_observed is a bare stored marker only, not yet consumed by
## anything: no decay/removal-while-unobserved runs off it, and nothing
## updates it on repeat sightings -- both explicitly out of scope for
## issue #37, see docs/systems-overview.md's Known Territory "flagged, not
## yet built" note.

var position: Vector3
var amount: int
var last_observed: float


func _init(p_position: Vector3, p_amount: int, p_last_observed: float = 0.0) -> void:
	position = p_position
	amount = p_amount
	last_observed = p_last_observed


## Drains up to `taken` from amount, returning what was actually removed.
## No-op (returns 0) for a non-positive request. Mirrors Farm.harvest()'s
## "take up to what's left" shape, minus the stage machinery a Farm needs
## and a one-shot resource entry doesn't.
func collect(taken: int) -> int:
	if taken <= 0:
		return 0
	var actual: int = min(taken, amount)
	amount -= actual
	return actual
