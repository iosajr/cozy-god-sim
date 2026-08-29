# View, Camera & Terrain

Turning records into something on screen. This layer reads the world and
never writes to it.

## Decided

- One spawner for everything. It asks what is near the camera and creates
  or destroys visuals for those records. Every species becomes visible the
  same way, because its species says what it looks like.
- The spawner is capped by count, not by distance: nearest first, and only
  a few built in any one frame so a jump cannot hitch. The radius is a
  first cut, not the limit.
- Camera is drag-the-world, zoom toward a point, rotate around focus.
- Terrain sits behind one interface: height at a point, and whether it can
  be walked. Flat is an implementation of that interface.
- **Nothing may assume flat.** Movement and placement ask the terrain for
  a height from the start, while the answer is always zero, so a real
  terrain can be swapped in without touching anything else.
- Placeholder art is disposable. No behaviour should depend on the exact
  primitive shapes standing in for it.

## Nameplates and thoughts

- A floating nameplate reworked as a thought bubble, in the style of
  Black & White. Toggleable rather than permanently on screen.
- Proximity-triggered audio for thoughts is wanted eventually.

## Dialogue

- A character model alongside a text box, in the style of Hades. One
  reusable component for both gods and renowned entities.
- Gods are imagined as more grandiose than renowned entities, though that
  distinction is not settled.

## Presence

A cosmetic light tracking where the cursor meets the ground. Purely
thematic, no mechanic. Some entities may notice it and briefly look before
returning to what they were doing.

## Terrain, later

Pokémon-styled terrain at large scale, swapped in behind the interface
above once approved.

## Open

- Whether gods and renowned entities need visually distinct treatments.
