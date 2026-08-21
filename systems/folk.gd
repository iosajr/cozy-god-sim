class_name Folk
extends RefCounted
## Folk
## Shared base for every Folk entity (CONTEXT.md's Folk entry — human,
## animal, or plant the Player can perceive). Holds exactly the parts
## that are genuinely common across all Folk types: a stable id, Faith,
## Favored, and Renown, plus the gain_favored() progression that grows
## Favored and promotes a Folk member to Faith/Renown. Extracted out of
## Villager (issues #2/#6/#7), which used to hold all of this directly,
## so Sheep (issue #11) — and future Folk types — reuse the exact same
## mechanism instead of reimplementing or duplicating it. Plain data, no
## scene tree and no _ready() lifecycle — fully testable in isolation
## (Seam 1, see issue #2 / docs/systems-overview.md).
##
## `id` is a stable internal identifier for tests/debugging only — it is
## not necessarily anything shown to the Player. `Villager.current_thought`
## is what its nameplate seam shows; `Sheep` has no such text at all (issue
## #11's User Story 3) — which is worth flagging against CONTEXT.md's Folk
## entry, currently phrased partly in terms of "the Player can perceive
## Thoughts from": that's no longer true of every Folk type now that Sheep
## exists. Flagged here per issue #11's Implementation Decisions, not
## rewritten — the right fix isn't obvious enough to prescribe (issue #11's
## Out of Scope).
##
## `favored` (CONTEXT.md's Favored entry) is a growing per-Folk stat that
## rises the longer the Player lingers near a Folk member — see
## gain_favored() and whichever spawner's proximity-detection loop calls
## it (scripts/village_spawner.gd for Villager, scripts/sheep_spawner.gd
## for Sheep, issue #11's User Story 10). Doesn't require Faith to start
## (CONTEXT.md: "doesn't require Faith to begin"); no cap, no decay this
## slice (issue #6).

## Fallback default thresholds gain_favored() uses when a caller doesn't
## supply its own — the same values Villager originally hardcoded (issues
## #6/#7). Villager relies on these directly rather than redeclaring
## same-named constants of its own (see systems/villager.gd's doc
## comment for why: GDScript can't disambiguate a subclass constant that
## shadows a parent one). Sheep does the same for its Faith threshold,
## but needs a genuinely different Renown threshold, so it names that one
## constant distinctly instead (`Sheep.RENOWN_THRESHOLD` — see
## systems/sheep.gd) rather than redeclaring DEFAULT_RENOWN_THRESHOLD.
## Both spawners (village_spawner.gd, sheep_spawner.gd) pass thresholds
## explicitly at the gain_favored() call site either way, so these
## defaults mostly just matter for callers (like the tests) that don't.
const DEFAULT_FAITH_THRESHOLD: float = 30.0
const DEFAULT_RENOWN_THRESHOLD: float = 100.0

var id: String
var has_faith: bool
var favored: float = 0.0
## Requires Faith (CONTEXT.md's Renown entry) — set only by
## gain_favored() once `favored` crosses a renown_threshold while this
## Folk member has Faith. Permanent once true this slice: no decay, no
## un-Renowning (issue #7's User Story 10, same "no cap, no decay"
## precedent as Favored itself). No God-attribution/dialogue logic lives
## here — that's a later slice.
var is_renowned: bool = false


func _init(p_id: String, p_has_faith: bool) -> void:
	id = p_id
	has_faith = p_has_faith


## Adds `amount` to `favored` (expected to already be scaled by the
## caller, e.g. by delta and a gain-per-second rate — see
## village_spawner.gd/sheep_spawner.gd). If this Folk member is still a
## skeptic (`has_faith == false`) and the new total meets or crosses
## `faith_threshold`, grants them Faith right here — encapsulating the
## Faith-unlock rule on Folk (not the caller) keeps it testable without
## the scene tree (issue #6's Implementation Decisions). A Folk member who
## already has Faith just keeps accumulating `favored` past the threshold
## with no further effect on Faith itself. After that check, also
## evaluates Renown (CONTEXT.md's Renown entry, issue #7): if this Folk
## member now has Faith — the just-updated value above, not whatever was
## true when this call started — and `favored` has crossed
## `renown_threshold`, marks them Renowned. Checking the post-update
## `has_faith` here (rather than a value captured before the Faith check
## above) is what lets one large call cross both thresholds at once and
## correctly land a skeptic as both faithful and Renowned in a single
## step (issue #7's User Story 4).
func gain_favored(amount: float, faith_threshold: float = DEFAULT_FAITH_THRESHOLD, renown_threshold: float = DEFAULT_RENOWN_THRESHOLD) -> void:
	favored += amount
	if not has_faith and favored >= faith_threshold:
		has_faith = true
	if has_faith and favored >= renown_threshold:
		is_renowned = true
