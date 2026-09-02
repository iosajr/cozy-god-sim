# Handoff: terrain rebuild (terraced continent)

## Overview

Replace the disposable look-dev probe (`scripts/terrain_style_probe.gd`) with a real
terraced-terrain generator sitting behind the existing `Terrain` interface. Pokémon
BW-style tiering with softened corners, Don't Starve slab access, muted Ghibli
palette, alpine peaks reached through gullies and passes.

The design authority is `Terrain Bible v2.dc.html` in this folder. Open it in a
browser. It carries the palette hexes, cliff anatomy, access rules, biome sheets,
pipeline stages, asset plan and the reasoning behind each.

## About the design files

`Terrain Bible v2.dc.html` is a **design reference**, not code to port. It is an HTML
document describing intended terrain look and generation behaviour. The GDScript
excerpts inside it are illustrative sketches of the intended shape of each class —
correct in structure and in their constants, but not tested, and not written against
the repo's full conventions. Treat them as a spec to implement in idiomatic GDScript
for this project, following `CLAUDE.md`.

`Mountain A/B/C - *.dc.html` are exploration diagrams kept for provenance. Profile B's
mountain *form* was selected; its switchback *access* was rejected. Don't implement
switchbacks — see ticket 4.

`refs/` holds the terrain references copied out of `REFERENCES/Imagers/`, which the
palette in §02b and §07 was reconciled against. These are the colour authority, not
the chat screenshots.

## Fidelity

**Spec-level, not pixel-level.** This is a procedural 3D system, so there is no mock
to match pixel-for-pixel. What *is* exact and must be honoured:

- Every hex value in §03, §05 and §07 of the bible.
- The constants: 4 m cell, 1.5 m riser (both already in the probe — keep them),
  0.18-cell lip overhang, 1.1 m top chamfer, min region area 260 cells (60 above
  tier 4), double riser above tier 4, snow ramp tier 5→8, foliage exclusion 2 cells
  from any cliff edge.
- The staging order in §09. Each stage is independently inspectable, and that is the
  point — it is what lets you judge the look before the expensive stages exist.

Everything else — node naming, chunking strategy, file layout — follows repo
convention and your judgement.

## How to work in this repo

Read `docs/agents/implementing-tickets.md` before starting; the short version:

- Read `CLAUDE.md` in full. Do **not** bulk-read `CONTEXT.md` or all of
  `docs/systems/` — grep for the feature instead.
- **No test framework is vendored.** GUT was removed 2026-08-28. Do not vendor a
  replacement. If a ticket seems to need tests, ask.
- **Do not screenshot or run the game to grade your own work.** Visual work is signed
  off by the user. Stop at the point where it can be looked at, say plainly what to
  look for and how to get there, and hand it over.
- Commit only what the change touches. Never `git add -A` — editor bootstrap runs
  rewrite unrelated `.import` files.
- Tickets live as GitHub issues (`gh issue create`, heredoc bodies). See
  `docs/agents/issue-tracker.md`. `TICKETS.md` in this folder holds nine ready bodies.

## Sequencing

Nine tickets, in dependency order, grouped into the five sittings from §12. Tickets
1–4 produce **no 3D at all** — they are judged on a 2D debug texture. That is
deliberate: the current prototype's problems are all field problems, and they are ten
times cheaper to see and fix flat.

| # | Ticket | Sitting | Blocked by |
| --- | --- | --- | --- |
| 1 | `PlateauField` — mask, terrace, smooth, label, absorb, chamfer | 1 | — |
| 2 | Biome assignment | 1 | 1 |
| 3 | `AccessSolver` — region graph and lowland access | 2 | 1 |
| 4 | Mountain rules — double riser, gullies, saddles, jagged summit | 2 | 1, 3 |
| 5 | `TerracedTerrain` behind the `Terrain` interface | 2 | 1 |
| 6 | `TerrainMesher` — chunked ArrayMesh with chamfer strips | 3 | 1, 4 |
| 7 | Cliff and ground shaders | 3 | 6 |
| 8 | Water — sea, basin fill, spillways, falls | 4 | 1, 6 |
| 9 | Foliage scatter — clumping and edge exclusion | 5 | 1, 6 |

Stop after ticket 3 and after ticket 7 and get the look signed off. Those are the two
points where a wrong call is cheap to reverse and expensive to discover later.

## Existing code this touches

| File | What happens to it |
| --- | --- |
| `systems/world/terrain.gd` | Unchanged. It is the contract. |
| `systems/world/flat_terrain.gd` | Unchanged. Stays as the headless default. |
| `systems/world/terraced_terrain.gd` | **New** (ticket 5). Implements `Terrain`. |
| `systems/world/plateau_field.gd` | **New** (ticket 1). The tier/region/biome field. |
| `systems/world/access_solver.gd` | **New** (tickets 3, 4). |
| `systems/world/terrain_mesher.gd` | **New** (ticket 6). |
| `scripts/terrain_style_probe.gd` | Rewired to the new generator (ticket 6). Keep it — it already builds the real `CameraRig`, sun and environment, so it is the look-dev harness. |
| `scenes/terrain_style_probe.tscn` | Unchanged. |

## The one design constraint that matters most

`docs/systems/view-camera-terrain.md` already decided that nothing may assume flat,
and that terrain answers exactly two questions: height at a point, and walkable or
not. **Do not widen that interface.** The tier field answers both in constant time.
If something above the interface starts wanting to know about tiers, regions or
biomes, that is a design conversation, not a signature change.

## Files in this bundle

- `README.md` — this file
- `TICKETS.md` — nine ticket bodies, ready for `gh issue create`
- `Terrain Bible v2.dc.html` — the design authority
- `Mountain A - Narrow Ledges.dc.html`, `Mountain B - Switchbacks.dc.html`,
  `Mountain C - Spiral Ledge.dc.html` — mountain form explorations (provenance)
- `refs/` — terrain references copied from `REFERENCES/Imagers/`, the colour authority
