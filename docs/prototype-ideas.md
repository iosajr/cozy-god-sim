# Prototype ideas

Write-up of throwaway prototypes, per `.claude/skills/engineering/prototype/SKILL.md`'s
"capture it when done" step — the verdict and the question each one
settled, kept here since the code itself lives on a throwaway branch and
won't survive on `main`.

## Terrain generation: Pokémon Black/White overworld look (issue #25)

**Branch**: `terrain-pokemon-bw-prototype` (off `main`, unmerged, no PR).
**Code**: `prototypes/terrain_pokemon_bw/` — `terrain_generator.gd` (the
reusable mechanism), `demo.gd`/`demo.tscn` (one parametrized configuration
exercising it), `take_screenshots.gd` (the verification runner).
**Question**: can a general, parametrized terrain-generation mechanism
produce Pokémon Black/White-style plateau+cliff-skirt/path-strip/pond/
tree-cluster terrain, cheaply and without the gap/hole bugs both earlier
terrain rounds (`terrain-layers-prototype`, `terrain_plateaus`, both fully
reverted, lessons only in project memory) hit once each?

### Verdict: yes, for the core plateau/cliff-skirt mechanism — verified with real screenshots

The plateau+cliff-skirt approach (hand-authored footprint polygon + a
skirt whose base flares outward past the top edge, guaranteeing overlap
by construction rather than exact shared-edge topology) reproduced
cleanly, with **zero visible gaps or holes** in either an angled or a
top-down real render, at 1 and 2 plateaus, and even where two plateaus'
skirts overlap each other (tested via a second parametrized run — see
Verification below). Terrain-only geometry (ground + plateau(s) + path
strip + pond) came in at **282 verts / 94 tris** for the default 1-plateau
demo config — cheaper than *both* earlier rounds
(`terrain_plateaus`: 396/132; the noise-band approach: ~4,614/~1,538).

Checklist self-assessment (against issue #25's extracted checklist —
**the reference image itself, `REFERENCES/Imagers/terain/Pokemon black and
white.jpg`, does not exist in this repo/sandbox** — see Limitations below;
this assessment is against the issue's written checklist, not a
side-by-side with the actual image):

1. **Plateau + cliff-skirt** — solid. One clean elevation tier, orange/
   dirt cliff face, no gaps. Confirmed at 1 and 2 plateaus.
2. **Winding, bordered path strips** — solid after two iterations. First
   pass routed the path straight through the plateau's footprint (it
   visually fused with the cliff-skirt); fixed by routing the path
   through the ground corner diagonally opposite the plateau center
   instead of trying to push individual zigzag points clear after the
   fact (that approach made the path hug the plateau's boundary, which
   looked worse). Final render shows a clearly separate, low
   (0.12 units tall vs. the cliff's 3), zigzagging orange border.
3. **Pond** — solid after one fix. First pass placed the pond mesh
   *below* the ground plane's own Y (a "gently-recessed" reading of the
   spec), which made it invisible — this project's ground is a single
   flat, undented `PlaneMesh`, so anything below it is fully occluded.
   Switched to sitting the pond just above the ground plane instead (the
   "flat" option the issue's Implementation Decisions also explicitly
   allowed) — now clearly visible as a distinct blue shape.
4. **Dense tree clusters** — solid after one fix. First pass picked
   cluster centers anywhere in the ground area, including *inside* a
   plateau's footprint — since trees are placed at y=0, a cluster
   centered under a plateau rendered as small clumps seemingly sitting on
   the plateau's top surface. Fixed with a simple reject-and-resample
   against each plateau's bounding circle. Final renders show clearly
   separated clumps with visible gaps between them, matching the
   reference's clustering (vs. `world_gen.gd`'s fully-independent
   scatter).
5. **Flat/toon-leaning shading** — partial/approximate, an explicit
   simplification. Every triangle gets its own hard-edged normal (no
   shared vertices between faces), which reads as a faceted, low-poly
   look under ordinary `StandardMaterial3D` PBR lighting — visible in the
   screenshots as distinct shading per cliff-skirt face. This is **not**
   a real cel-shader with hard light bands; a custom toon shader would
   sharpen the effect further. Colors are bright/saturated per the
   reference's color-blocking. Judged good enough for this prototype's
   time budget, flagged rather than silently claimed as "done."

**Known, unfixed overlap**: in the 2-plateau/denser-cluster variant config
(not the default demo config), the pond and a tree cluster ended up
placed close enough to visibly touch, and the path's endpoint landed near
the pond. Placement so far only coordinates trees-vs-plateaus and
path-vs-plateaus, not pond-vs-trees or pond-vs-path — a real gap in the
"general mechanism," not something worth guessing a fix for given the
time budget. Flagged here for whoever picks this up next, not fixed.

### Verification

**Real Vulkan-rendered screenshots, actually looked at** — this session's
first ~15 minutes were spent confirming this cloud sandbox can do it at
all (issue #25's own flagged, prominent risk), since headless Godot
cannot render 3D:

- Installed Godot 4.3-stable (matches this project's declared 4.7
  feature tag closely enough — no version-incompatibility issues hit;
  a locally-pinned 4.7 install would be a nicer match but wasn't
  necessary here), `xvfb`/`xvfb-run` (already present), and
  `mesa-vulkan-drivers` (`apt-get install`, needed a plain `apt-get
  update` first — the default sources had a stale cache) for **lavapipe**,
  Mesa's software Vulkan implementation.
- There is no `/dev/dri` in this sandbox and no real GPU — confirmed via
  `lspci`/`nvidia-smi`/`ls /dev/dri`. Rendering is genuinely software
  (`llvmpipe`/lavapipe, `deviceType = PHYSICAL_DEVICE_TYPE_CPU`), not
  hardware-accelerated. It is still a **real Forward+/Vulkan render
  pipeline producing actual lit, shaded pixels** — confirmed with a
  minimal red-box test scene before touching this issue's actual terrain
  code, and every screenshot below is a genuine rendered frame, not a
  placeholder.
- Command shape (see `take_screenshots.gd`'s own header comment for the
  exact invocation):
  `xvfb-run -a --server-args="-screen 0 1280x720x24" <godot> --rendering-driver vulkan -s prototypes/terrain_pokemon_bw/take_screenshots.gd --path <repo root>`
- One prerequisite that cost real debugging time: this project's
  `class_name` globals (`GroundScatter`, `TerrainGenerator`, ...) don't
  resolve in `-s` script mode until the project's global script class
  cache (`.godot/global_script_class_cache.cfg`) exists — it's normally
  built by opening the project in the editor at least once. A first
  `--headless --editor --quit` warm-up run built the cache (and then
  crashed on an unrelated GUT-addon image-import issue *after* writing
  the cache file — harmless for this purpose, the cache was already on
  disk). Future sessions in a fresh sandbox will need the same warm-up
  step.
- Two camera angles per config (an angled distance shot, a top-down shot
  — the top-down view specifically is what caught both earlier rounds'
  real gap/hole bugs, per issue #25's Testing Decisions) at the default
  1-plateau config, plus a second angled+top-down pair at a
  2-plateau/denser-tree-cluster config to demonstrate genuine
  parametrization (issue #25 user story 7) rather than one fixed scene.
  All four PNGs are committed under
  `prototypes/terrain_pokemon_bw/screenshots/` as the actual visual
  evidence behind this verdict (an exception to prototypes' usual
  "no persistence" rule — these are the artifact the verdict rests on,
  not disposable scratch state); regenerate via `take_screenshots.gd` if
  they ever need refreshing.
- **Headless GUT** (`tests/prototypes/terrain_pokemon_bw/test_terrain_generator.gd`,
  9 tests, all passing): vertex/triangle counts match the expected
  triangulation math, generation completes without error, `RandomNumberGenerator`-seeded
  clustering is reproducible for a given seed. This is exactly the
  numeric/structural half issue #25's Testing Decisions describe GUT as
  suited for — it says nothing about whether the terrain *looks* right,
  which is what the screenshot loop above is for.

### Limitations / what a future session should know

- **The reference image is missing from this sandbox.** Issue #25 points
  at `REFERENCES/Imagers/terain/Pokemon black and white.jpg` directly; it
  does not exist anywhere in this repo (checked working tree and full git
  history) and isn't `.gitignore`d — it appears to live only on the
  user's own machine, never committed. This session's entire visual
  verdict above is against the issue's own *written* checklist
  (extracted from the image by whoever filed the issue), not an actual
  side-by-side comparison with the image. A future session with the image
  available should re-check the screenshots in
  `prototypes/terrain_pokemon_bw/screenshots/` against it directly —
  the checklist is a reasonable proxy but isn't the same thing as looking
  at the real reference.
- Only the plateau/cliff-skirt piece got a second, harder validation pass
  (the 2-plateau overlap case). Path/pond/tree placement only got the
  single default-config pass plus the one variant run above.
- No corner-chamfering, no non-convex plateau footprints beyond the
  jittered-blob shape `demo.gd` generates — `TerrainGenerator.build_plateau()`
  itself accepts any simple polygon (via `Geometry2D.triangulate_polygon()`),
  this just isn't exercised beyond blobs here.
- Pond/path/tree-cluster mutual placement (not just vs. plateaus) is
  unhandled, per the known overlap above.
