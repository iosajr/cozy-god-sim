class_name Family
extends RefCounted
## A small group of Villagers, per CONTEXT.md's Family entry -- seeded
## directly into the starting population at Village.populate() time
## (issue #40), no Reproducing-driven creation yet. Can carry a farming
## business bias that raises (not guarantees) a member Villager's odds of
## starting with Villager.is_farmer = true, on top of Village.FARMER_CHANCE.

var members: Array[Villager] = []
var has_farming_bias: bool = false


func _init(p_has_farming_bias: bool = false) -> void:
	has_farming_bias = p_has_farming_bias


## Appends villager to members and back-points villager.family here --
## the two are always kept in sync through this one entry point, so no
## caller ever adds a Villager to a Family without the reverse pointer
## following.
func add_member(villager: Villager) -> void:
	members.append(villager)
	villager.family = self
