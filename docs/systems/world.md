# World

Owns every simulated record. The one place to look.

## Decided

- Plain data: beings, settlements, buildings, tasks, events. No
  scene-tree types inside it.
- Stable ids. Anything referring to a being holds its id.
- One tick entry point, advancing systems in a known order. Nothing
  advances itself from its own frame callback.
- It runs headless.
- The world is many settlements across more than one landmass, with fast
  travel between them for the player.

## Scale target

A living continent: five or six cities' worth, around a thousand beings,
all of it moving whether or not anyone is watching.

Not everything needs the same depth to make that true. The beings the
world's story runs through carry more detail than the rest, and detail is
generated when it is needed rather than held for everyone.

## Open

- Nothing currently blocking.
