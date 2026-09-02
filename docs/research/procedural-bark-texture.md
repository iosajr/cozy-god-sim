# Procedural bark texture, ported to a shader

Design handed over a JS/Canvas2D script that bakes a tileable "Black Bark"
texture: seeded value noise warps a sine-based ridge pattern, a second finer
noise field adds pale highlight blotches. The original also drew ink-line
fibres and dark speckle on top with Canvas2D path strokes; both are dropped
per design, which removes the only part of the script that couldn't stay
headless (Canvas2D stroke drawing has no equivalent on a raw pixel buffer —
it would have needed a `SubViewport` draw pass). What's left is pure
per-pixel colour math, which fits a Godot shader directly.

## What carries over as-is, and what Godot already has a name for

- `noise()` + `fbm()` — a periodic grid of random values, bilinear-sampled
  with smoothstep interpolation, stacked in octaves. This is exactly what
  `FastNoiseLite` does with `noise_type = TYPE_VALUE` and
  `fractal_type = FBM`. No hand-rolled grid needed.
- The seamless wraparound (`wrap()`'s 3×3 tiling, here only relevant to the
  noise itself since strokes are gone) — `NoiseTexture2D.seamless = true`.
- `mix()` — `Color.lerp` / GLSL `mix`, unchanged.
- `rng(seed)` — not ported bit-for-bit. Godot's own RNG bakes the noise
  textures instead. This reproduces the *technique*, not the exact pixels —
  a different PRNG gives a different but same-looking result, same as it
  would porting to a CPU bake instead of a shader.

## The two noise fields, as baked textures

Two small greyscale `NoiseTexture2D` resources, both seamless, both
`TYPE_VALUE`/`FBM`, at whatever bake resolution matches the rest of the
terrain texture set (512² per the terrain rebuild's texture budget):

| | base period | octaves | frequency @ 512px (`period / 512`) |
| --- | --- | --- | --- |
| `warp_noise` | 3 | 4 | 0.00586 |
| `fine_noise` | 14 | 3 | 0.02734 |

`fractal_gain = 0.5`, `fractal_lacunarity = 2.0` on both — this is what
turns "base period, octave count" into the same amplitude/frequency
doubling the JS `fbm()` does by hand. Frequencies are a starting point to
retune by eye, not an exact target; nothing here is pixel-locked to the
original.

## The shader

`shader_type spatial`, live at `docs/research/bark-texure.gdshader` and
wired into a `ShaderMaterial` on the plane swatch in `scenes/main.tscn` —
code lives in the one file now, not duplicated here.

The first cut shaded the whole surface into ridge bands with a sine wave —
readable as fluting, not cracks, and since it was one clean periodic sine,
every band looked the same. The current version replaces that with a
threshold: crack colour appears only where a noise field crosses near its
own midline, as a thin softened line, everywhere else stays base colour.
Three things make that read as bark cracks rather than a hatch pattern:

- **Vertical bias.** V is compressed before the noise lookup
  (`UV.y * vertical_stretch`), which stretches the noise field's blobs out
  along V — so the boundaries between them, where the crack sits, run
  lengthwise instead of banding across.
- **Wobble.** A second, independent read of the same noise texture — one
  column, varying only with V — nudges U by a small amount before the
  crack lookup. That's the side-to-side meander, and it's a named amount
  (`wobble_amount`) rather than a fixed sine wave.
- **No tiling.** Both samplers are `repeat_disable`, not `repeat_enable`.
  The swatch samples each noise texture once, 0–1, no wraparound — nothing
  to repeat. That stops mattering once this goes on a mesh whose UV
  actually tiles (a tall trunk, say), at which point revisit it.

`vertical_stretch`, `wobble_amount`, `crack_width`, `crack_softness` are
exposed as `hint_range` uniforms specifically so they can be dragged in
the material inspector rather than round-tripped through me — that's the
fastest way to retune the crack look by eye.

The three colours (`ridge_light`/`ridge_dark`/`fine_highlight`) are
unchanged from the first pass and still uniforms rather than baked into a
texture, so a retint stays free — same reasoning as the terrain shader
plan (§07 of the terrain bible).

## Unverified

Not run or previewed — per house rule, visual work is signed off by
looking at it, not by me grading my own shader.

## Worth a look before this goes further

`bark-texure.gdshader` (note the existing typo in the filename) sits under
`docs/research/`, but it's now a live game resource — `scenes/main.tscn`
references it directly. `docs/` is meant for documentation, not assets the
scene loads. Worth moving to wherever shader assets belong (`assets/`?
nothing established yet) once the look is settled — not done here since it
means touching `scenes/main.tscn`'s resource path, outside what was asked.

## Open questions

- **Where does this attach?** Nothing in the repo currently loads a trunk
  texture — `terrain_noise_probe.gd`'s `_trunk_material` is a flat colour.
  Swapping that for this `ShaderMaterial` would be a one-line change, not
  done here since it wasn't asked for.
- **The seed formula** (`7 * 7919 + 6 * 104729 + 13`, with a comment
  "bark is index 6") implies a family — one seed per (species or material)
  index, decorrelated by two large primes. Only this one texture was
  handed over. If more are coming, the two noise textures above should
  probably be shared across the whole family (same warp/fine fields,
  different `ridge_light`/`ridge_dark`/`fine_highlight` uniforms per
  material) rather than re-baked per variant — but that's a guess at
  intent, not a decision.
