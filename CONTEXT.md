# Cozy God Sim

A cozy, slow-paced idle game about a World where humans, animals, plants,
and mythological beings all live and matter. Despite the genre label, the
player is not a god: the Gods act on the World for their own reasons; the
player merely has a seat at their table, watching both their game and the
individual lives caught up in it.

## Language

### The Pantheon

**The Gods**:
Act on the World, each pursuing their own interests and staying out of
each other's business (Death doesn't interfere elsewhere, etc.) —
Discworld-style, not a single unified will. They range enormously in scale
and dignity, from cosmic figures like Death down to small, petty gods
absorbed in mundane obsessions (a Rat God who loves cheese). A God
associated with an act — lightning, death — isn't required to personally
cause every instance of it (nature is nature); they can perform the act
deliberately, at will, since it's what they're known for. They're
discreet about it: showing their hand too openly would spoil the game
they're all playing with each other. What the world does on its own is
what draws the Gods' interest — they react to it, they don't author its
events. The Gods themselves are meant to be created from the perceived
world, not pre-authored as fixed content — the roster isn't just static
lore the Player is handed; it comes from what the World does and what
Folk perceive. The actual mechanism for that isn't decided yet.
_Avoid_: authoring events, orchestrating plots — that direction of
causality is backwards; see Player.

**Domain**:
A particular God's sphere of concern — the kind of thing, or place, a God
is tied to (the harvest god's Domain is agriculture; Death's Domain is
dying). Not the whole World, and not necessarily a place at all — just
whatever belongs to that God.
_Avoid_: Realm — reads too geographic; a Domain can be a place, a concept,
or an act. World — the whole game world is a separate, larger concept.

**Player**:
Not one of the Gods, and without a god's power to act directly on the
World — but a guest at the Gods' table, respected and consulted. Watches
at two scales: the Gods themselves — their interests, rivalries, and
reactions to what's happening in the World — and individual Folk up
close.
_Avoid_: God — the player is explicitly not one, despite the genre label.

### The World

**World**:
The whole of what the Player can watch — many Villages, across
landmasses, and everything between. The Player moves across it freely,
and near-instantly.
_Avoid_: Domain — that word now means something more specific (a God's
sphere), not the whole game world.

**Village**:
A human settlement. Many Villages exist across the World's landmasses.
Other species have their own settlement types (animal burrows/dens, plant
groves, etc.) as those are designed — not yet named.
_Avoid_: Colony, Settlement, Town, City — City was just casual phrasing
for a built-up Village, not a distinct tier; out of scope for now.

**Villager**:
A human inhabitant of a Village.
_Avoid_: Colonist, Sim, Citizen

**Known Territory** _(proposed)_:
The portion of the World a Village's Folk collectively know about —
shared across the whole community, not tracked per individual. Grows
two ways: an expedition's outcome (a Folk member explores and returns
with what they found; one who explores and never returns is also
information, exact mechanism TBD), or a local event a Village
experiences directly (no expedition needed — see ADR-0004). Folk only
forage within it. Can hold plain points of interest as well as
perishable resource opportunities (a spotted herd, a dropped cache) —
see ADR-0004, reversing the earlier "not tied to resources" stance.
Explicitly not a Player mechanic — the Player always sees the whole
World regardless of what any Village has discovered.
_Avoid_: Fog of war — that term usually implies gating the Player's own
view, which this explicitly does not do.

**Interest** _(proposed)_:
A Villager's inclination toward a kind of work — for now, a single bare
flag (farming), not a general profession system. A farming Family raises
the odds a member starts with it, but doesn't guarantee it. The intended
long-term mechanism — a Villager who spends time near someone practicing
an Interest picks it up by proximity, the same "how close, how long"
shape Favored already uses — is real direction, not yet built: it needs
Reproducing's children to exist first.
_Avoid_: Profession, Role, Job — implies a general system with slots and
progression; this is one bare flag until a second Interest exists.

**Family** _(proposed)_:
A group of Villagers. Seeded directly into the starting population at
Village creation — no Reproducing-driven creation yet. Can carry a
shared business bias (e.g. leaning toward farming Interest) that nudges
members' odds, not a guarantee.
_Avoid_: Household — could later mean something tied to Housing instead;
keep them distinct until Housing assignment is actually designed.

**Folk** _(name questioned — open to renaming)_:
Umbrella term for an ordinary human, animal, or plant the Player can
perceive Thoughts from. The World's mythological beings (nymphs, centaurs,
tree spirits, etc.) aren't a starting category under Folk — they're what a
Renowned animal or plant Folk member becomes; see Renown.
_Avoid_: Creature, Denizen, NPC

**Disaster** _(proposed)_:
A storm, plague, or other calamity striking a Village or the land around
it. Usually just nature being nature; occasionally a deliberate act by the
God it's associated with — the Folk can't tell which, an "act of god"
reads the same either way. Never a fail state: the Village rebuilds; one
dying out entirely is rare.
_Avoid_: Punishment, Curse — implies deliberate targeting, which is the
exception here, not the rule.

### Listening and Acting

No menus: the Player has no dialogue box or command interface. Everything
below is overheard, or done by direct presence in the world — Black & White
hand-style, but as light rather than a body.

**Thought**:
Ambient, overheard interior monologue from a member of the Folk. Not
inherently actionable — most Thoughts are flavor, not requests.

**Wish**:
A Thought that specifically expresses a want. A subtype of Thought, not a
separate channel — not every Thought is a Wish, and not every Wish is a
demand. The Player can never guarantee a Wish comes true — there's no
button that makes it certainly happen. Acting on one means a Petition
(asking a God, who might refuse) or a Nudge (a push the Player causes
directly, but whose effect on the Wish plays out through the world, not
on command) — directness of cause is not the same as certainty of
outcome. Wishes cut both ways — wanting help is one kind, but so is
wanting someone gone. Open question, not yet decided: whether a Wish
should always resolve to exactly one Domain/God, or whether some
Wishes have multiple resolving outcomes/paths instead of a single
lookup.
_Avoid_: Prayer, Demand, Objective — these imply either a worship/exchange
relationship or an obligation that hasn't been designed yet.

**Petition** _(proposed)_:
The Player drawing a relevant God's attention to a Wish, in hope the God
acts on it — e.g. raising a starving child's plight with the harvest god,
or asking Death whether it's really this man's time. The Player has no
power to grant the Wish, only to make it known to whoever's Domain it
falls under.
_Avoid_: Prayer — this is closer to raising a concern with someone who
happens to listen because they respect you, not worship.

**Nudge** _(proposed)_:
A small, physical intervention the Player causes directly — not a
god-tier miracle, more a subtle push (spooking cattle toward a starving
Village, say). Performed through the Player's Presence.
_Avoid_: Miracle, Ability — too overt for what this is.

**Presence** _(proposed)_:
How the Player manifests within the World in order to perform a Nudge —
not a hand or a body, but light. Only Folk with Faith can ever sense it,
and even then only when the Player is actually attending to them — not an
ambient, always-on awareness.
_Avoid_: Hand, Avatar, Cursor

**Faith** _(proposed)_:
Whether a Folk member believes gods exist at all. Gates whether they can
ever sense the Player's Presence — the faithless never do, however close
the Player gets.
_Avoid_: Awareness, Devotion — Faith is specifically the belief-in-gods
trait, not a general alertness stat.

### Growth

**Favored** _(concept confirmed — name still open)_:
A Folk member that a God — or the Player — is deliberately exerting
attention on, for good or ill; not the Player's doing alone. Doesn't
require Faith to begin — the attention itself can be what earns a skeptic
their Faith, on the way toward Renown. Mechanism for the Player's side of
it: a growing per-Folk stat that rises the longer the Player lingers near
them — how a God's attention registers isn't decided.
_Avoid_: Chosen One, Champion — too grandiose; a Favored might become a
wise elder as easily as a hero.

**Renown** _(concept confirmed — name still open)_:
Requires Faith — a powerful or notable Folk member without Faith is never
Renown, however much status they hold; being a chief doesn't make someone
Renown on its own. A Renowned Folk member comes to believe, and say, that
a god shaped their rise — intended or not, whether or not one actually
did. Visibly marked as more "holy," for good or ill. For animal or plant
Folk, the mark is transformation itself, toward something more humanoid
and elegant (a horse toward centaur, a goat toward faun, a tree toward
dryad) — the origin of the World's mythical beings, and the fairy tales
mortals tell about them.
_Avoid_: Fame, Legend — read as too narrowly public/heroic for what this
covers.
