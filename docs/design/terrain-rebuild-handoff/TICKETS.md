# Ticket bodies

Nine issues, in dependency order. Create with a heredoc:

```sh
gh issue create --title "Terrain 1: PlateauField — mask, terrace, smooth, label, chamfer" --body "$(cat <<'EOF'
...body...
EOF
)"
```

Design authority for all nine: `design_handoff_terrain_rebuild/Terrain Bible v2.dc.html`.

---

## 1. PlateauField — mask, terrace, smooth, label, absorb, chamfer

**Why.** The current probe quantises noise to a tier per cell and stops. Nothing knows
a plateau exists, so nothing can cull a small one, guarantee it access or give it a
biome — and every tier edge is a ragged one-cell fringe. This ticket is the fix, and
every other ticket depends on it.

**Scope.** New `systems/world/plateau_field.gd`, a `RefCounted` data class. No 3D, no
scene coupling. Stages, in order:

1. Land mask: radial falloff from centre, minus low-frequency ridged noise (this cuts
   the bays), plus 3–4 hand-placed peninsula blobs from an exported array. Threshold,
   majority-smooth twice, discard islands under 400 cells.
2. Distance-to-coast field by BFS from the sea.
3. Terrace: low-frequency noise scaled by coast distance, quantised to tiers.
   Unlimited stacking inland. Keep `cell_size = 4.0`, `terrace_step = 1.5`.
4. Majority smooth ×3 over the 8-neighbourhood. This is what turns confetti into
   coastline — do not skip it or reduce the passes.
5. Flood-fill region labelling (4-connected, same tier). Store region id, tier and
   cell count per region.
6. Absorb any region under 260 cells into its dominant neighbour by border vote.
7. Chamfer: demote one-cell spikes (≥3 lower 4-neighbours), fill one-cell notches
   (≥3 higher), then break diagonal-only touches by raising the lower pair. Two
   passes. Re-label after.

**Also in scope.** A debug view: a `TextureRect` (or the probe's own overlay) painting
tier as colour, one pixel per cell. This is how the ticket is judged.

**Out of scope.** Biomes, access, meshing, water, the `Terrain` interface.

**Numbers.** 512×512 cells. Min region area 260. Islands under 400 cells discarded.
Smoothing 3 passes, chamfer 2 passes.

**How to look at it.** Run the probe, look at the 2D debug texture. Wanted: a single
readable continent with deep bays, plateaus that are large and few rather than small
and many, tier edges that run in clean straight and diagonal lines, and no one-cell
speckle anywhere. Then hand it over — do not screenshot it to self-grade.

---

## 2. Biome assignment

**Why.** Four biomes for v1: lowland meadow/paddy, deep forest, snowy mountain, coast
& beach. They must be data, not code — a biome should be a row you edit, so retinting
costs nothing.

**Scope.** Biome index per cell on `PlateauField`. Four seed points placed by hand
(exported `Array[Vector2i]`). Each cell takes the nearest seed weighted by a noise
field so borders wander rather than drawing Voronoi lines. Snow additionally requires
tier ≥ 5 so the mountain biome finds the mountains; coast additionally requires
distance-to-coast ≤ 3.

**Hard rule.** Biomes never change the tier field. They change palette, cliff
treatment, foliage and step prop only. If a biome needs to move terrain, that is a
design conversation.

**Out of scope.** Any rendering of the biomes — colours land in ticket 7.

**How to look at it.** Same debug texture, toggled to paint biome instead of tier.
Wanted: four regions with wandering, non-geometric borders; snow only high; coast a
consistent hem.

---

## 3. AccessSolver — region graph and lowland access

**Why.** The design guarantee: every plateau has a route to sea level. Not "usually" —
always, and provably.

**Scope.** New `systems/world/access_solver.gd`.

- Collect border runs: contiguous cell faces where a region at tier *n* touches a
  region at tier *n−1*, grouped by (low region, high region, facing).
- Region graph + union-find. Seed the tier-0 set as mutually connected.
- Sort candidate runs longest first (longest straight runs make the best-looking
  steps). While a region is unreachable, place access on its cheapest run.
- Site record: cell on the lower tier, facing, from-tier, kind.
- Kind: `STAIRS` where the settlement mask is set, `SLAB` otherwise. **No ramps** —
  deliberately dropped; with slab and stair both present a third type muddies the
  language.
- Runs under 3 cells are not eligible.
- Any region still unreachable after the pass is a bug: `push_error` with the region
  id and its tier, do not silently seal it.

**Also in scope.** A reachability check across 200 seeds. **No test framework is
vendored** — make it a debug routine that prints a pass/fail summary, runnable from
the probe. Do not vendor GUT or a replacement.

**Out of scope.** Mountains above tier 4 (ticket 4). Step prop meshes.

**How to look at it.** Debug texture with access sites drawn as dots. Wanted: every
plateau has at least one dot, dots sit on long straight edges rather than in corners,
and the 200-seed check prints zero failures.

---

## 4. Mountain rules — double riser, gullies, saddles, jagged summit

**Why.** Mountains should read alpine and stay accessible. The switchback approach
from exploration B was rejected: a staircase cut across a rock face is a built object
on a wild mountain and it fights the silhouette. Access comes off the face instead.

**Scope.** Parameter set and solver branch that applies above tier 4.

- **Double riser.** Faces drop two terraces at once — 3.0 m of unbroken rock. Too
  tall to step, so a bare face genuinely stops you.
- **Narrow ledges.** Min region area drops from 260 to 60 above tier 4, so ledges 3–5
  cells wide survive the absorb pass. Peaks reach tier 8–12.
- **Gullies.** Where a peak needs a route, *carve* one: a 2-cell channel cut back into
  the massif that steps down through the tiers on the shortest path to the region
  below. Floored with tumbled slabs and scree. The route is terrain, not a prop.
- **Saddles.** Where two peaks sit within ~30 cells, hold the field between them two
  tiers lower — a pass. Passes are the primary way up a range; gullies the secondary
  way up a single peak.
- **Jagged summit.** The top two tiers skip smoothing and chamfer entirely — raw
  quantised noise, which reads as shattered rock. Flag them `unbuildable`.
  `is_walkable` still returns true so the player can stand and look.

**Out of scope.** Snow colour (ticket 7). Scree meshes.

**How to look at it.** Debug texture plus the 200-seed check. Wanted: every peak
reachable; routes visibly running through clefts and between peaks rather than across
faces; summits ragged while everything below tier 5 stays clean.

---

## 5. TerracedTerrain behind the Terrain interface

**Why.** `docs/systems/view-camera-terrain.md` decided terrain answers exactly two
questions and nothing may assume flat. This is the ticket that cashes that decision in.

**Scope.** New `systems/world/terraced_terrain.gd` extending `Terrain`.

- `height_at(x, z)` → `tier_at(cell) * terrace_step`, 0.0 outside the field.
- `is_walkable(x, z)` → false outside the field, false in deep water; true on any
  ledge top and on the footprint of a step or gully.
- Owns a `PlateauField`. Constant time, no mesh dependency.

**Do not widen the interface.** No tier, region or biome accessors on `Terrain`. If
something above it wants those, that is a design conversation.

`FlatTerrain` stays untouched as the headless default.

**Out of scope.** Meshing. Collision shapes.

**How to look at it.** Spawn the existing entities on the terraced field and confirm
they stand on ledges rather than at y=0, and that nothing walks into a cliff face.

---

## 6. TerrainMesher — chunked ArrayMesh with chamfer strips

**Why.** The probe pushes 16,384 scaled `BoxMesh` instances with hard 90° corners.
Soft corners and the grass lip are the highest-value visual change in the whole
rebuild, and neither is expressible as boxes.

**Scope.** New `systems/world/terrain_mesher.gd`. Chunked `ArrayMesh` (64×64 cells per
chunk), two surfaces: ledge tops and cliff walls.

- Per tier discontinuity, emit two strips: a 45° chamfer strip from the grass top down
  to the lip crest, then the main rock face pushed out by the lip so the grass
  overhangs.
- Lip overhang 0.18 cell (0.72 m). Top chamfer 1.1 m. Talus skirt 0.3 m.
- Concave corners get a single fillet triangle.
- Carry shader inputs in `COLOR`: `r` = tier / max_tier, `g` = 0 top / 1 wall,
  `b` = wall v, 0 at the lip crest. `a` free for biome blend.
- Rewire `scripts/terrain_style_probe.gd` to this mesher. Keep its `CameraRig`, sun
  and environment as they are. Raise `min_zoom` — at a 2 km continent the interesting
  read is the middle distance where three tiers stack in frame.

**Out of scope.** Shaders (ticket 7) — use flat placeholder materials so the geometry
is judged on its own.

**How to look at it.** Fly the probe. Wanted: cliff corners visibly softened, the
grass lip overhanging with a shadow line under it, no gaps or z-fighting at chunk
seams. Judge the edge in isolation before any colour exists.

---

## 7. Cliff and ground shaders

**Why.** The most-looked-at surface in a tiered world currently has one flat albedo on
it.

**Scope.** Two `.gdshader` files, `cull_back`, `diffuse_lambert`,
`specular_disabled`.

**Cliff.** One warm grey-brown rock mass with a pale rim on the top 7% of the face and
soft vertical column divisions — **not** three hard strata bands. This is a revision
from `REFERENCES/Imagers/terain/agressive mountains.png`: columnar masses with softly
rounded tops, one hue, almost no strata. Plus moss spill from the lip (smoothstep on
`COLOR.b`, noise-wobbled), the dark ink line the lip casts, AO toward the foot.

**Ground.** Biome tint by `COLOR.r`, plus large soft **unquantised** value blotches at
±8% — per `Grass closeup.png`, ground variation is big soft patches, not a tile grid.
The quantised paddy grid appears only inside settlement radii.

**Palette.** Take the hexes from §07 of the bible verbatim. Muted and warm: lowland
`#93A866 / #A3B673 / #B3C184`, rock `#A68A6E`, lip ink `#4A4A35`, forest
`#6D8355 / #7D9260 / #5B6F4C`, coast sand `#E8C48A / #D3AE76`, snow
`#EEF1EF / #C8CECA / #8F9793`. The probe's current `Color(0.44, 0.82, 0.51)` is far
too saturated and too cool — that is the specific thing being corrected.

**Snow.** A blend, not a threshold: coverage ramps 0 at tier 5 to full at tier 8,
modulated by noise so it pools in hollows and blows off exposed edges.

**Texture budget.** Four greyscale tiling 512² textures for the whole terrain layer:
rock grain, field blotch noise, snow drift noise, foam/spray card. Colour lives in
uniforms so a biome retint is free.

**How to look at it.** Fly the probe at middle distance. Wanted: three tiers legible
by value alone in a still frame; cliff edges reading soft; nothing mint-green.

---

## 8. Water — sea, basin fill, spillways, falls

**Why.** Sea at tier 0 plus perched lakes that spill off cliff edges. The falls should
not be authored — they should fall out of the fill.

**Scope.**

- Sea: one plane at tier 0 (the probe already has this). Everything outside the land
  mask is sea.
- Basin fill: flood-fill each depression upward from its lowest cell. Fills without
  reaching a region border → lake, sitting at its basin's tier. Reaches a border →
  the lowest border cell is the outlet.
- Spillway: water pours over the cliff at the outlet as a fall; the stream continues
  on the tier below.
- Two water materials only, sea and fresh. Fresh is lighter and greener, near-opaque,
  pale rim at the shore — transparent water in a stylised world just shows the mesh
  you were hiding.
- Falls: soft white column on a generated quad strip with scrolling UV, plus one alpha
  spray card at the foot. No simulation.
- Coast: 2-cell sand hem along the mask edge; foam as a shader ring on the sea plane,
  not geometry.

**Out of scope.** Swimming, boats, flow simulation.

**How to look at it.** Wanted: lakes sitting believably on plateaus, falls appearing
at natural low points in cliff edges rather than at random, no water climbing a wall.

---

## 9. Foliage scatter — clumping and edge exclusion

**Why.** 1,200 identical spheres at uniform density average out to texture, and trees
currently land on cliff lips, which is exactly what hides the tiering.

**Scope.** Keep the `MultiMesh` approach and the per-mesh instance split from
`_build_trees` — that part is right. Replace the scatter rule.

- **Density is zero within 2 cells of any cliff edge.** Non-negotiable; clear lips are
  what make the tiering readable.
- Clump field: a second noise, `smoothstep(0.45, 0.85, n)`, so there are real
  clearings rather than even spread.
- Density scaled per biome and per tier (lowland 1.0, forest 1.4, coast 0.6, snow 0.3
  falling to 0 above tier 8).
- Three silhouettes: broad 60%, tall cedar 25%, scrub 15%. Hard two-value split on
  every canopy — sunlit top, shadowed underside, no gradient.
- Random yaw and ±15% scale per instance. Coast instances lean inland.

**Out of scope.** LOD and streaming. Note where the seams would go, don't build them.

**How to look at it.** Wanted: forests reading as clumps with found clearings, cliff
lips clean, no visible repeat stamp at middle distance.
