class_name Folk
extends RefCounted
## Shared base for every Folk entity (human, animal, or plant the Player
## can perceive): id, Faith, Favored, Renown, and ageing.

const DEFAULT_FAITH_THRESHOLD: float = 30.0
const DEFAULT_RENOWN_THRESHOLD: float = 100.0

## Placeholder real-seconds-per-in-game-year conversion.
const DEFAULT_SECONDS_PER_YEAR: float = 300.0

var id: String
var has_faith: bool
var favored: float = 0.0
## Requires Faith. Permanent once true — no decay, no un-Renowning.
var is_renowned: bool = false

var age_years: int = 0
var _age_progress: float = 0.0


func _init(p_id: String, p_has_faith: bool) -> void:
	id = p_id
	has_faith = p_has_faith


## Adds `amount` to favored (already scaled by the caller, e.g. by
## delta). Grants Faith on crossing faith_threshold, then Renown (once
## Faith is held) on crossing renown_threshold — both can happen in the
## same call.
func gain_favored(amount: float, faith_threshold: float = DEFAULT_FAITH_THRESHOLD, renown_threshold: float = DEFAULT_RENOWN_THRESHOLD) -> void:
	favored += amount
	if not has_faith and favored >= faith_threshold:
		has_faith = true
	if has_faith and favored >= renown_threshold:
		is_renowned = true


## Delta-driven per-Folk tick (ageing bookkeeping only). Single-crossing
## per call, mirroring Village's own advance_*() timers.
func advance(delta: float, seconds_per_year: float = DEFAULT_SECONDS_PER_YEAR) -> void:
	_age_progress += delta
	if _age_progress >= seconds_per_year:
		age_years += 1
		_age_progress -= seconds_per_year
