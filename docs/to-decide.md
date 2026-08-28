# To decide

Open questions and queued ideas, raised as work reaches them. Anything
that stops being worth deciding gets deleted rather than left sitting.

## What the settlement type is called

One class covers a human village, an animal warren and a grove of tree
folk. Each species names its own. The umbrella term in code is still
open — "settlement" is the placeholder.

## Trees as a real resource

Wood should come from trees that can run out and come back, rather than a
starting number. That means trees regrow — either seeding themselves or
being planted by beings, and being planted is the more interesting answer
because it is visible work. Tree folk belong to the same thread.

## Herding and ranching

A second passive food source alongside farming. Needs behaviour that does
not exist yet.

## Time passing while the game is closed

Wanted. Game time would advance against real-world time between sessions,
so the world has moved on when you return. Needs save/load and a catch-up
pass. Not being built yet.

## What the first playable slice contains

Flat ground, the camera, an inspector, and enough behaviour to be worth
watching. Open: how many beings, whether a second species is in it, and
how many kinds of work exist.

## References between records: ids or objects

A house knows its occupants and a being knows its home either way. The
question is whether that link is stored as an id with a lookup, which
survives being written to disk, or as a direct object reference, which
reads more naturally in code.

## Laziness

Whether beings given everything stop working, the way they did in Black &
White. It adds character, and it also lets a settlement be broken in a way
that is hard to read from the outside.
