# Prompt: Pokémon Black/White-style terrain probe (Godot 4.7, GDScript)

> Paste everything below the line into the target model. It is written to be
> self-contained: no repo exploration required beyond the files it names.

---

You are working in a Godot 4.7 project (Forward+ renderer, GDScript) at
`C:\Users\richa\repos\cozy-god-sim` — a cozy 3D god-sim. Your job is a
**visual styling task only**: build a standalone terrain look-dev scene that
recreates the terrain styling of Pokémon Black & White (Nintendo DS, Gen 5)
overworld routes.

## Reference

If `REFERENCES/Imagers/terain/Pokemon black and white.jpg` is present, open and
look at it before writing any code — that image is the target.

**It will probably not be present.** That directory is untracked, so it does
not exist in a clone. This is expected and is not a problem: the written spec
below is complete and self-sufficient, with exact colours and exact geometry
parameters. If the image is missing, say so once and build to the spec. Do not
go looking for it, do not try to obtain it, and do not stop.

If you do find `REFERENCES/Imagers/terain/Black and white.png`, ignore it —
that is a different game (Lionhead's *Black & White*) and is not the reference
for this task.

## Hard scope boundaries

DO create these files and only these files:

- `scripts/terrain_style_probe.gd` — the script that builds it
- `scenes/terrain_style_probe.tscn` — the look-dev scene. Write it exactly as
  below and nothing more; do not invent a `uid`, and do not add nodes the
  script builds at runtime:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/terrain_style_probe.gd" id="1"]

[node name="TerrainStyleProbe" type="Node3D"]
script = ExtResource("1")
```

This is a throwaway probe the user will look at and sign off on before
anything gets wired into the game. It stands alone: it is not the terrain the
game will eventually use, and it implements no interface. Nothing reads from
it, and it reads from nothing.

DO NOT touch anything under `legacy/` — that is the previous codebase, kept
for salvage only. Do not wire the probe into any other scene, and do not
delete or "clean up" existing files.

There is no test framework in this project. Do not add one.

## What the target look actually is

The Pokémon B/W overworld is **not** a smooth heightmap landscape. Match these
traits exactly:

1. **Terraced terrain.** The ground is flat plateaus at a small number of
   discrete height steps, joined by near-vertical cliff walls. There are no
   smooth rolling slopes anywhere. Height is quantized, never interpolated.
2. **Two hard-separated materials.** Plateau tops are grass. Cliff sides are
   ochre dirt. They meet at a hard 90-degree edge — no blending, no vertex
   colour transition, no triplanar smear across the lip.
3. **Flat, ambient-dominant lighting.** Almost no specular, no visible PBR
   response, shadows short and soft or absent. Surfaces read as painted tiles,
   not lit geometry.
4. **Low texel density, nearest-neighbour filtering.** Everything reads chunky
   and pixel-tiled, never smoothly shaded.
5. **Saturated, high-key palette.** Mint and spring greens, warm tan cliffs,
   strong blue sky, slate-blue flat water.
6. **Repetitive, uniform props.** Trees are near-identical chunky blobs placed
   in loose clumps — same scale, same rotation, no random jitter or tilt.
   Repetition is part of the style, not a flaw to hide.
7. **Aerial haze at distance.** Distant terrain fades toward the sky horizon
   colour. Light and pale, never a dark or grey fog.

## Concrete build spec

Write `scripts/terrain_style_probe.gd` as `extends Node3D`, typed GDScript
(`var x: int`, `-> void` on every function). It builds everything in code in
`_ready()`. Exported knobs with these defaults:

```gdscript
@export var grid_cells: int = 128        # 128 x 128 cells
@export var cell_size: float = 4.0       # -> 512 x 512 world units
@export var terrace_step: float = 1.5    # vertical distance between levels
@export var terrace_levels: int = 5      # levels 0..4, tops at y = 0.0 .. 6.0
@export var water_level_y: float = 0.35  # flat water plane height
@export var tree_count: int = 1200
@export var seed_value: int = 1
```

### Terrain geometry — use this exact recipe

Do **not** use `SurfaceTool`, `ArrayMesh`, or `HeightMapShape3D`. Build the
terrain from box columns via `MultiMeshInstance3D` nodes, which is both simpler
and fast enough to scale up later:

1. For each of the `grid_cells * grid_cells` cells, sample a `FastNoiseLite`
   (`noise_type = FastNoiseLite.TYPE_SIMPLEX`, `frequency = 0.008`, seeded from
   `seed_value`) at the cell centre. Map the result from `[-1, 1]` to `[0, 1]`,
   then **quantize** to an integer level:
   `level = clampi(int(n01 * terrace_levels), 0, terrace_levels - 1)`.
   Put this mapping in a `static func` — it is pure, and keeping it separate is
   what makes the terracing easy to reason about.
2. **Cliff MultiMesh** — a `BoxMesh` of size `Vector3(cell_size, 1.0,
   cell_size)`, one instance per cell, scaled on Y to
   `(level * terrace_step) + 4.0` (the extra 4.0 is a skirt below y=0 so no
   gaps show), positioned so its **top face sits exactly at**
   `level * terrace_step`. Uses the cliff material below.
3. **Grass-cap MultiMesh** — a `BoxMesh` of size `Vector3(cell_size, 0.2,
   cell_size)`, one instance per cell, centred so its top face is at
   `level * terrace_step + 0.01`. Uses the grass material below. This cap is
   what produces the hard grass/cliff edge from the reference.
4. Set `multimesh.transform_format = MultiMesh.TRANSFORM_3D` and
   `multimesh.instance_count` before writing any instance transforms.

### Materials

All materials are `StandardMaterial3D` created in code, each with:

```gdscript
metallic = 0.0
roughness = 1.0
specular_mode = BaseMaterial3D.SPECULAR_DISABLED
texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
```

Colours — this is the starting palette, read off the reference image:

- Grass base: `Color(0.44, 0.82, 0.51)`
- Grass variation: roughly 1 cell in 4 gets a lighter `Color(0.62, 0.89, 0.60)`.
  Do this with **two** grass-cap MultiMeshes (one per colour) rather than
  per-instance colour, to keep it simple.
- Cliff: `Color(0.72, 0.55, 0.25)`
- Water: `Color(0.26, 0.40, 0.53)` with `albedo_color.a = 0.85` and
  `transparency = BaseMaterial3D.TRANSPARENCY_ALPHA`
- Tree trunk: `Color(0.36, 0.24, 0.16)`
- Tree canopy: `Color(0.20, 0.52, 0.31)`

No textures, no normal maps, no image assets — flat colours only for this pass.
Texture work is a later pass.

### Water

One `MeshInstance3D` with a `PlaneMesh` sized
`Vector2(grid_cells * cell_size, grid_cells * cell_size)` at `y = water_level_y`,
using the water material. Level-0 cells sit below it and read as flat lakes,
exactly like the reference. No wave geometry, no reflections, no custom shader.

### Trees

Two more `MultiMeshInstance3D` nodes sharing one array of transforms:

- Trunk: `CylinderMesh`, `top_radius = 0.22`, `bottom_radius = 0.28`,
  `height = 1.8`, `radial_segments = 6`.
- Canopy: `SphereMesh`, `radius = 1.6`, `height = 2.8`, `radial_segments = 8`,
  `rings = 4`, centred `2.4` above the ground point.

Placement: random cells, rejected if that cell's terrace top is below
`water_level_y`. Snap each tree to its cell's terrace top height.
**Uniform scale, zero rotation** on every tree — do not randomize either.

### Lighting and environment

Add a `DirectionalLight3D` and a `WorldEnvironment` to the scene:

- Sun: `light_energy = 0.8`, `shadow_enabled = true`,
  `directional_shadow_max_distance = 120.0`, angled roughly
  `rotation_degrees = Vector3(-50, -35, 0)`.
- Environment: `ambient_light_source = Environment.AMBIENT_SOURCE_SKY`,
  `ambient_light_energy = 1.1` — ambient does most of the work.
- Sky: `ProceduralSkyMaterial` with `sky_top_color = Color(0.18, 0.50, 0.83)`,
  `sky_horizon_color = Color(0.75, 0.88, 0.96)`,
  `ground_horizon_color = Color(0.75, 0.88, 0.96)`.
- Fog: `fog_enabled = true`, `fog_light_color = Color(0.75, 0.88, 0.96)`,
  `fog_density = 0.0018`. Pale haze, not grey murk.
- `tonemap_mode = Environment.TONE_MAPPER_LINEAR`, glow disabled — keep it flat.

### Camera

One `Camera3D` in the scene, positioned to reproduce the reference framing: a
vista looking out across the terraces toward the horizon. Pitch about `-32`
degrees, `fov = 50`, high enough to see several terrace levels and the horizon
line. Do not add camera controls — this is a static look-dev shot.

## Anti-goals (do not do these)

- No smooth or interpolated heightmap terrain; no `HeightMapShape3D`.
- No PBR-looking materials: no metallic, no roughness/normal maps, no specular
  highlights.
- No glow/bloom, SSAO, SSR, or volumetric fog.
- No randomized tree rotation, scale, or per-instance colour jitter.
- No collision shapes, physics bodies, gameplay logic, `class_name`
  registration, or autoload changes.
- No new dependencies or addons.

## Repo conventions you must follow

- Typed GDScript everywhere; `-> void` return annotations.
- Comments are one-liners stating current behaviour or an invariant. Do NOT
  write comments narrating why a choice was made, what you rejected, or which
  request asked for it. No issue numbers, and no pointers to other files or
  documents.
- A `##` doc comment at the top of the script saying what it is (a disposable
  visual probe) is expected and wanted.
- Keep the script focused on building this probe. Do not add helpers to other
  files.

## Verification — expect to have none, and that is fine

**Godot is almost certainly not installed where you are running.** Do not try
to install it, do not look for a substitute, and do not treat its absence as a
failure or a blocker.

- If `godot` is not available: say so plainly in your report and hand the work
  over unverified. **This is the expected outcome and is acceptable.** The user
  will open it themselves. Shipping unverified code here is the plan, not a
  compromise you need to apologise for or work around.
- If `godot` *is* available, then and only then: run
  `godot --headless --quit-after 60` **twice** (the first run may not finish
  the async import scan; a bare `--editor --quit` is known to hang in this
  project — do not use it), and confirm the scene opens with no errors.

There is no test suite to run. Do not write one, and do not add a framework.

Re-read your own script before reporting: check the typed annotations are
there, the exported defaults match the spec exactly, and every colour matches
the palette. Careful reading is the only check available to you, so do it
properly.

**Do NOT render, screenshot, or grade the visual result yourself.** Stop once
the files are written and hand it to the user with:

- the list of files you created,
- the exact command to open the probe scene, and
- the list of `@export` knobs they can turn while looking at it.

Say plainly in your report whether anything was verified or nothing was. The
user signs off on how it looks. Your job is done when the files are written,
match the spec, and are ready to be opened.
