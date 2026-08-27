# Cozy God Sim — Vision

*The pitch, the feel, and the core idea. Everything here reflects a
decision actually made; anything genuinely undecided is marked **OPEN**
rather than filled in with something plausible-sounding.*

A cozy, slow-paced idle game about a World where humans, animals, plants,
and mythological beings all live and matter — every one of them, not
just the Player's own household.

## The Gods act on the World

The Gods act for their own reasons — self-interested, petty as often as
cosmic. How openly they act depends on personality: some are boisterous,
some prefer not to show their hand. They are reactive to what the World
already does more than they are authors of it.

Gods existing is common knowledge in the World, not something each Folk
member has to believe in.

**The one hard boundary: a God can never force a mortal's will.** Gods
cause direct physical and environmental effects — burn a city, wreck a
harvest, seed circumstantial chaos — but cannot compel a Folk member to
act on their behalf. That rules out "make two countries go to war" and
"mind-control one person" alike: the same violation at different scales.

## The Player is a guest at the Gods' table

**The Player is not a God.** They watch, and they have a quiet effect at
the margins. They never command.

Interaction is deliberately limited, and small on purpose:

- **Move the simulation forward and watch.** The default verb, and most
  of the game.
- **Dialogue.** With Gods, and with Renowned Folk. The only interactive
  verb for now.
- **Planned, undesigned (OPEN):** a system for interacting with Gods to
  borrow or invoke their power. This is the intended route by which the
  Player ever affects the World — through a God, never directly.

**Two scales, both matter.** The Player watches the Gods' own politics —
their rivalries, their interests, who's paying attention to what — and
zooms into individual Folk living ordinary lives up close. Neither scale
is the "real" game; the point is that both are happening at once, and
the Player is the only one who sees both.

**No menus.** Nothing is commanded. What the Player hears from ordinary
Folk is overheard — an ambient Thought, loose and occasional, an insight
into what that Folk member has been doing and what has happened to them.
Not a request typed into a box, and not a demand on the Player.

The "Presence" mechanic is retired. `PresenceLight` survives as a
leftover name for a purely thematic visual so the Player can see where
they're attending; it carries no mechanics. Some Folk may notice it and
briefly turn to look before going back to what they were doing.

## Slow and cozy, not urgent

This isn't a crisis-management game. Folk live, work, pair off, age, and
occasionally get noticed by something bigger than themselves — on their
own time, not on a clock the Player is racing against.

A full day is **8 real minutes: 6 of day, 2 of night.** Seasons may vary
that split later; fixed for now.

## Scale

The eventual goal is a continent of several cities, each with a real
population — thousands of Folk, not dozens. The Player moves across it
freely and near-instantly, and is only ever looking at one place.

That last fact is what makes it affordable, and the current decision
leans on it deliberately: **only the Villages near the Player are ever
really simulated**; the rest of the continent is a name, a position, and
a population that moves by a simple rule. See `docs/rebuild-plan.md` for
the architecture, and for the disciplines that keep the deeper version
buildable later without committing to it now.
