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

A continent of five or six cities, each with many sub-populations.
Procedural infinite generation has been floated as a possible end goal
and is not wanted for certain.

## Open

- Nothing currently blocking.
