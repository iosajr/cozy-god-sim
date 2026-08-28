class_name RenownedSituationSignature
extends RefCounted
## Derives a compact, matchable key from a Folk member's current tracked
## state (task, hunger/tiredness, paired, farming bias, Faith/Renown), for
## RenownedThoughtMemory's find/remember lookup.
##
## Reuses systems/villager_ideas_prompt.gd's own field reads and derived
## helpers (mood_from_state/standing_from_state) rather than a parallel
## shape -- the same villager snapshot Dictionary (see
## systems/village_state_export.gd) feeds both. "Close enough" comes from
## those helpers already bucketing continuous state (hunger/tiredness
## states, Faith vs. Renown) into a handful of discrete values, not from
## fuzzy matching on top of the signature itself.


static func derive(villager: Dictionary) -> String:
	var parts: Array[String] = [
		"task=%s" % str(villager.get("current_task", "")),
		"mood=%s" % VillagerIdeasPrompt.mood_from_state(villager),
		"paired=%s" % str(bool(villager.get("paired", false))),
		"farming_bias=%s" % str(bool(villager.get("family_has_farming_bias", false))),
		"standing=%s" % VillagerIdeasPrompt.standing_from_state(villager),
	]
	return "|".join(parts)
