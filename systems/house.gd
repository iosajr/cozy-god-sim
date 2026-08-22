class_name House
extends RefCounted
## House
## PROVISIONAL, NOT FINAL ARCHITECTURE (issue #17) — a minimal Housing
## data shape shipped anyway because something concrete is more useful
## right now than continued design uncertainty, per direct instruction.
## Design conversation never settled whether Housing should be per-house,
## per-Village, or per-Villager, or who should own occupant-assignment —
## none of that is resolved here. This is one provisional guess, not a
## resolution (see docs/systems-overview.md's Buildings section and
## issue #17's Further Notes — same disposable-placeholder spirit as
## Pantheon's static roster and Wish's single-Domain lookup, both of
## which were revisited once real design existed). Expect this class's
## shape and the Villager→House pointer (systems/villager.gd) to be
## replaced wholesale once Housing is actually designed — don't build
## more on top of it than the paired Sleeping spec needs.
##
## Plain data, no scene tree — same Seam 1 conventions as
## Location/Wish (see issue #2 / docs/systems-overview.md). No
## assignment logic, no construction trigger, no occupancy enforcement:
## just enough data to exist and be referenced (issue #17's User
## Stories 4/5).

## Occupant-capacity range floated in design discussion, however loosely
## (issue #17's User Story 2) — not a settled number, just the shape a
## House's capacity is expected to fall within.
const MIN_CAPACITY: int = 2
const MAX_CAPACITY: int = 8
## Fixed default capacity, chosen as the midpoint of MIN_CAPACITY/
## MAX_CAPACITY — whether a House's capacity should instead be
## randomized per House is explicitly an implementer's call left open by
## issue #17 (User Story 2); this slice picks the simplest option (a
## fixed default), not a considered one.
const DEFAULT_CAPACITY: int = 4

var capacity: int


func _init(p_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = p_capacity
