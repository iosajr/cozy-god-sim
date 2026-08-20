class_name Pantheon
extends RefCounted
## Pantheon
## Holds the full roster of Gods (CONTEXT.md's "The Gods"), queryable by
## Domain. No scene tree, no _ready() — fully testable in isolation, the
## same Seam-1-style seam as Village/Villager (see issue #2 /
## docs/systems-overview.md, and issue #3's Implementation Decisions).
##
## PLACEHOLDER SCAFFOLDING: the roster below is a fixed, hand-written array
## built at construction time — deliberately not the intended architecture.
## CONTEXT.md is explicit that the Gods are meant to be created from the
## perceived world, not pre-authored as fixed content; this static roster
## stands in for that unbuilt generation mechanism, the same disposable
## spirit as scripts/world_gen.gd's placeholder primitives (see
## docs/systems-overview.md's Pantheon section and
## docs/adr/0002-pantheon-roster-is-placeholder-content.md). Swap it out
## once a real "Gods emerge from the World" mechanism exists — keep this
## class's public interface (`gods`, `get_by_domain`) stable across that
## change even though its internals will be replaced completely.

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


## Returns the God whose Domain matches `domain`, or `null` if no God in
## the roster claims it. Godot has no Option type; `null` is the agreed
## not-found signal for this seam (see issue #3's Implementation Decisions).
func get_by_domain(domain: String) -> God:
	for god: God in gods:
		if god.domain == domain:
			return god
	return null
