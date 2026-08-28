class_name VillagePairing
extends RefCounted
## Pairing-formation detection for a Village's Villagers (issue #41) --
## Reproducing's "male-female -> time -> baby" groundwork, data/detection
## half only: no Task, no offspring yet (see issue #42). A plain
## collaborator, not itself a TaskProvider -- tested directly, same
## pattern as systems/village_farm_labor.gd.
##
## Two eligible Villagers (opposite Sex, both unpaired, both past
## Villager.MIN_REPRODUCTION_AGE) who stay within proximity_threshold of
## each other for a sustained pairing_duration become mutually
## paired_with each other. Progress resets the moment a pair drifts
## apart -- no partial credit banked across a separation, an
## implementer's call in the absence of a specified decay rule.

## How close (in world units) two Villagers must stay to accumulate
## pairing progress. Tunable, not defended, same spirit as this project's
## other placeholder thresholds (e.g. favored_radius).
var proximity_threshold: float = 3.0

## How long (in seconds) two eligible Villagers must stay within
## proximity_threshold of each other, uninterrupted, before they pair.
## Tunable, not defended.
var pairing_duration: float = 30.0

## pair_key String (see _pair_key()) -> float seconds of sustained
## proximity accumulated so far.
var _progress: Dictionary = {}


## Call once per frame/tick; Village itself has no _process.
func advance_pairing(villagers: Array[Villager], delta: float) -> void:
	for i in villagers.size():
		var a: Villager = villagers[i]
		for j in range(i + 1, villagers.size()):
			if not is_eligible(a):
				break
			var b: Villager = villagers[j]
			if not is_eligible(b) or a.sex == b.sex:
				continue
			_advance_pair(a, b, delta)


## Pure query -- true if `villager` could ever be considered for pairing
## (unpaired, past the maturity gate). Doesn't check Sex compatibility
## against a candidate partner; that's pairwise, checked by the caller.
static func is_eligible(villager: Villager) -> bool:
	return villager.paired_with == null and villager.age_years >= Villager.MIN_REPRODUCTION_AGE


func _advance_pair(a: Villager, b: Villager, delta: float) -> void:
	var key := _pair_key(a, b)
	if a.position.distance_to(b.position) > proximity_threshold:
		_progress.erase(key)
		return
	var progress: float = _progress.get(key, 0.0) + delta
	if progress >= pairing_duration:
		a.paired_with = b
		b.paired_with = a
		_progress.erase(key)
	else:
		_progress[key] = progress


static func _pair_key(a: Villager, b: Villager) -> String:
	return "%s|%s" % [a.id, b.id] if a.id < b.id else "%s|%s" % [b.id, a.id]
