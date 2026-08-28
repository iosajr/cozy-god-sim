# Black & White villager AI

What the 2001 game did, as far as it is documented. The reference for how
Folk decide what to do.

## The structure

Belief, desire, opinion — combined into an intention.

- **Beliefs** — the list of world objects an agent knows about, and what
  it knows about each. An agent acts on what it has actually encountered,
  not on a query against the world.
- **Desires** — goals wanting satisfaction, each carrying a strength.
- **Opinions** — how a desire could be satisfied, choosing between the
  beliefs the agent holds.

For each desire, take the belief with the best opinion. The strongest
result becomes the intention, and the agent acts on it.

The Creature used perceptrons for desires and decision trees for
opinions, and learned both. Villagers ran the same shape without the
learning.

## The village centre coordinates

Villager numbers had no fixed cap, so anything cooperative was moved off
the individuals and onto the Village Centre. In Molyneux's words: "We
couldn't have them interrogating each other, so this central control means
that they do work as a unit but can retain their individual
characteristics."

Personality and individual choice stayed on the villager. Anything needing
two villagers to agree went through the centre.

## What villagers wanted

Food, rest, offspring, housing, and wood. They collected into and drew
from a village store, built whatever the village was short of, and went
home to recover.

Villagers given everything stopped working. Over-provision produced
laziness and scarcity restarted them.

## Confidence

The belief/desire/opinion structure and the village-centre quote come from
the developers. The desire list and the laziness behaviour come from
player documentation, not from the team.

## Sources

- [Postmortem: Lionhead Studios' Black & White](https://www.gamedeveloper.com/design/postmortem-lionhead-studios-i-black-white-i-)
- [Black & White — Wikipedia](https://en.wikipedia.org/wiki/Black_%26_White_(video_game))
- [The Creature A.I. of Black and White](https://somegamez.com/wit/creature-ai-black-and-white)
- [Black and White: management hints and tips](https://www.wischik.com/lu/senses/bwhints.html)
