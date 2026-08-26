class_name VillageStateExport
extends RefCounted
## Turns a Village's live state into a plain, JSON-safe Dictionary snapshot
## for the local-LLM idea pipeline (VillagerIdeasPrompt).
##
## Deliberately exposes only fields that are real per
## docs/systems-overview.md -- no invented "mood"/"relationships"/
## "recent_memory" the game doesn't actually track. Prompt-building works
## off of what's here plus flavor text (current_thought/current_wish),
## not made-up state.


static func export_villager(villager: Villager) -> Dictionary:
	return {
		"id": villager.id,
		"name": villager.villager_name,
		"age_years": villager.age_years,
		"sex": "female" if villager.sex == Villager.Sex.FEMALE else "male",
		"is_farmer": villager.is_farmer,
		"has_faith": villager.has_faith,
		"favored": villager.favored,
		"is_renowned": villager.is_renowned,
		"current_thought": villager.current_thought,
		"current_wish": villager.current_wish,
		"current_task": villager.current_task.kind if villager.current_task != null else null,
		"hunger_state": villager.hunger_state,
		"tiredness_state": villager.tiredness_state,
		"paired": villager.paired_with != null,
		"family_has_farming_bias": (
			villager.family.has_farming_bias if villager.family != null else false
		),
		"house_assigned": villager.house != null,
	}


static func export_village(village: Village) -> Dictionary:
	var villagers_data: Array = []
	for villager: Villager in village.villagers:
		villagers_data.append(export_villager(villager))
	return {
		"population": village.villagers.size(),
		"houses": village.houses.size(),
		"farms": village.farms.size(),
		"known_resources": village.known_resources.size(),
		"villagers": villagers_data,
	}
