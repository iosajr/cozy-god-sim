# To decide

Open questions, raised as work reaches them. Anything that stops being
worth deciding gets deleted rather than left sitting here.

## Time passing while the game is closed

Wanted. Game time would advance against real-world time between sessions,
so the world has moved on when you come back. Needs save/load and a
catch-up pass on load. Not being built yet.

## What the first playable slice contains

Flat ground, the camera, an inspector, and enough behaviour to be worth
watching. Open: how many Folk, whether a second species is in it, and how
many kinds of work exist.

## References between records: ids or objects

A house knows its occupants and a villager knows its home either way. The
only question is whether that link is stored as an id with a lookup, which
survives being written to disk, or as a direct object reference, which
reads more naturally in code.

## Laziness

Whether Folk given everything stop working, the way they did in Black &
White. It adds character, and it also lets a village be broken in a way
that is hard to read from the outside.
