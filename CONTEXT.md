# Cozy God Sim — Glossary

Pure vocabulary reference: what each domain term means, nothing else. See
`VISION.md` for the game's actual pitch/feel, `docs/rebuild-plan.md` for
the architecture, and `docs/adr/` for why a term settled the way it did.

Terms marked *(provisional)* are in active use but the name is not
settled. Terms marked *(designed, not built)* have a definition and no
code. Terms marked **OPEN** are genuinely undecided — do not fill these
in without asking.

## The Gods

**God**: A deity acting on the World for its own reasons —
self-interested, reactive to what the World already does rather than
authoring events. How openly a God acts depends on its Personality;
some are boisterous. Ranges from cosmic figures to small, petty gods.
A God can cause direct physical and environmental effects but can never
compel a Folk member's will or action. *The collective term is just
"the Gods" — "Pantheon" is dropped.*

**Domain**: A God's sphere of concern — a kind of thing, act, or place a
particular God is tied to. Not the whole World, and not necessarily a
place.

**Player**: Not a God. A guest at the Gods' table — watches the Gods'
own interests/rivalries, and individual Folk up close. Currently limited
to advancing the simulation and to dialogue. Any effect on the World is
intended to route through a God, never directly. **OPEN**: the
borrow/invoke-a-God's-power system.

## The World

**World**: The whole of what the Player can watch — many Villages across
landmasses, moved across freely and near-instantly.

**Folk** *(provisional)*: Umbrella term for any ordinary human, animal,
or plant in the World. The general case; Villager is a specialization of
it, and new systems should be written against Folk rather than Villager
where there's a choice.

**Village** *(provisional)*: A settlement of Folk, and the unit of
simulation detail — Folk inherit their Village's activity tier rather
than being tiered individually (see `docs/rebuild-plan.md`).

**Villager** *(provisional)*: A human Folk member inhabiting a Village.

**Family**: A lineage/relations group. Folk take more interest in closer
relatives — biasing task choice, memory sharing, and who they
communicate with.

**Known Territory**: What a Village's Folk collectively know about the
World — an array of `{resource, location, timestamp}` entries, shared
community-wide, grown by expeditions and local events. Not a Player
mechanic; the Player always sees the whole World regardless. Supersedes
ADR-0004's perishable-resource shape.

**Interest**: A weighted bias on which Task a Folk member picks —
driven by traits and needs (laziness, playfulness, hunger, need for
housing), not restricted to kinds of work.

**Disaster** *(designed, not built)*: A storm, plague, or other calamity
striking a Village. Caused by weather, Gods, or circumstance. Mostly
narrative in intent.

## Being and remembering

**Personality**: A small fixed numeric trait vector (kindness,
aggression, greed, boldness, ~0–1 each) carried by every acting being —
Gods and Folk alike. Has real mechanical effect on behaviour: a bold
Folk member fights, a fearful one flees. Not tags. Stored as an
immutable base; current Personality is derived as base plus the
influence of currently-live Memories, never ticked.

**Memory**: A per-Folk record of something that happened, stored as
`{significance_at_creation, created_at, …}`. Its current weight is
computed from age on read, never decayed by a tick. Impactful memories
linger or become permanent; the rest fall below a floor and are dropped.
Memories spread person-to-person through actual interaction, not
omnisciently. A memory's live weight is what feeds Personality — that's
the link between the two systems. Replaces `divine_exposure.gd`.
**OPEN**: the propagation mechanism itself (see `docs/rebuild-plan.md`
for the hard constraints it has to satisfy).

**Thought**: An ambient, occasional interior line from a Folk member —
an insight into what they've been doing and what's happened to them.
Event- and memory-driven, not on a timer. LLM-generated and saved.
Retained as a concept; the implementation is later work, and ADR-0005's
Renowned-only restriction is superseded by that.

**Rebirth**: On the death of a Renowned Folk member, their Personality
is pooled. A new Folk of the same creature type can later be generated
from a pooled Personality, appearing instantly Renowned. Eligibility is
having actually affected them, or notable position — not proximity or
attention. No memories or name carry over: same personality plus same
art is the identity, and the "familiar" beat is thematic only.

## Attention and standing

**Favored**: A Folk member a God is deliberately paying attention to,
for good or ill. Points toward active world tension — kings waging wars,
unlikely events — rather than lingering attention. *Name still open.*

**Renown**: A Folk member who has visibly risen through a God's hand.
Its main mechanical role is unlocking Player interaction (dialogue).
For animal or plant Folk the mark is transformation toward something
more humanoid (a horse toward centaur, a tree toward dryad) — the origin
of the World's mythical beings. *Name still open.*

## Removed

- **Faith** — cut entirely as a system. Gods existing is common
  knowledge, not a per-Folk belief. Supersedes ADR-0001. Removes the
  Faith prerequisite from Renown.
- **Presence** — retired as a mechanic. `PresenceLight` remains as a
  purely thematic visual with no gameplay effect.
- **Wish** — removed. Name disliked; it was a gameplay device rather
  than vocabulary, and may return in some form later.
- **Nudge** — removed.
- **Petition** — removed as vocabulary. The underlying idea (asking a
  God for something, at a cost, possibly owing something in return) is
  a gameplay concept, and may be where the borrow/invoke-power system
  lands. **OPEN** — not asserted as the same thing.

## Not yet glossary'd

Task/Task Priority, Housing/House, Farm, Weather, Reproducing/Pairing —
real, built systems that predate this pass. Add entries here as each
gets redesigned in the rebuild, rather than writing definitions for
shapes that are about to change.
