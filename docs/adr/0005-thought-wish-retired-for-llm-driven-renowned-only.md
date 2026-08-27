# Thought/Wish is retired as a timer-driven, Pantheon-linked mechanic

> **Superseded (2026-08-28).** Wish is removed entirely. Thought is kept as a loose, event- and memory-driven line available to Folk generally, not restricted to Renowned. The villager-ideas pipeline this ADR described is discarded. See `CONTEXT.md` and `docs/rebuild-plan.md`.

Supersedes ADR-0003's mechanic (not merely extends it): the canned,
timer-driven Thought/Wish reroll and its Domain-linked-to-a-God
resolution are removed outright, not gated to Renowned Folk. Thought/Wish
becomes exclusively a Renowned trait, populated by the villager-ideas
LLM pipeline instead.

## Context

Since issue #4, every Villager rerolled a Thought on a timer; a minority
of rerolls drew a `Wish` instead, carrying a free-form Domain `String`
that `Village.resolve_wish()` looked up against `Pantheon.get_by_domain()`
for a placeholder resolved/ignored outcome (ADR-0003).

The villager-ideas pipeline now generates a real in-character reaction
and a ticket-style Wish suggestion via a local LLM. That output has no
Domain — it's not shaped to feed the same resolution mechanic, and
retrofitting a Domain onto it would mean inventing a field the actual
content doesn't have anything to say about. Keeping the canned mechanic
running alongside the LLM one (even gated to non-Renowned Folk) would
mean two entirely different Wish shapes coexisting under one field.

## Decision

Remove the canned mechanic entirely: `systems/village_thoughts.gd` (the
reroll timer, `THOUGHT_POOL`/`WISH_POOL`, `resolve_wish()`) and
`systems/wish.gd` (the Domain/`linked_god`/`outcome` shape) are both
deleted, along with their tests. `Villager.current_thought` and
`current_wish` survive as plain `String` fields, empty by default —
Thought/Wish is now exclusively something a Renowned Folk member's LLM
interaction populates, not something every Villager gets on a timer.

`Pantheon` itself is untouched; only its Wish-domain-linking caller is
gone. It's still used directly for God dialogue/flavor.

## Consequences

- Non-Renowned Folk show no Thought/Wish at all — the nameplate's
  existing fallback to the Name/Age baseline already covers this.
- A fresh `Village.populate()` no longer draws from any flavor pool;
  `current_thought`/`current_wish` start empty for everyone.
- The single-Domain-lookup question ADR-0003 left open is now moot for
  Thought/Wish — there's no Domain-linking mechanic left to resolve it
  for. If a future mechanic wants Gods reacting to Wishes again, it
  would need its own design, not a revival of this one.
