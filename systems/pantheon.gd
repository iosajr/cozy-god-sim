class_name Pantheon
extends RefCounted
## Holds the full roster of Gods, queryable by Domain.
##
## PLACEHOLDER SCAFFOLDING: the roster is a fixed, hand-written array, not
## the intended architecture — Gods are meant to emerge from the world,
## not be pre-authored. Keep `gods`/`get_by_domain()` stable once that
## replaces this.

var gods: Array[God] = []


func _init() -> void:
	gods = [
		God.new(
			"Mordane",
			"dying",
			"Cosmic and unhurried; walks beside the dying without menace, keeping perfect ledgers of who is due and when."
		),
		God.new(
			"Corwen",
			"agriculture",
			"Watches over the harvest with quiet pride; sulks for a week if a field goes to rot from neglect."
		),
		God.new(
			"Skitter",
			"vermin",
			"A rat god who loves cheese above all things; will nudge a wheel of it toward a hungry child out of pure fellow-feeling, not virtue."
		),
		God.new(
			"Hesk",
			"storms",
			"Short-tempered and easily bored; brews squalls for entertainment more often than out of anger."
		),
		God.new(
			"Pellin",
			"lost things",
			"A minor, endearing god of misplaced objects — single socks, dropped coins, keys down the well; delights in eventual, improbable returns."
		),
	]


func get_by_domain(domain: String) -> God:
	for god: God in gods:
		if god.domain == domain:
			return god
	return null
