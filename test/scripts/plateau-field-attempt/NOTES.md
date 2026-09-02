# PlateauFieldAttempt & AccessSolver — standalone snapshot

Everything built against `design_handoff_terrain_rebuild`'s tickets 1-3
this session, pulled out of the live probe and archived here as working
code. `PlateauField` was renamed to `PlateauFieldAttempt` so this can sit
in `test/` alongside the live `scripts/world/plateau_field.gd` without
the two colliding as global classes. Not wired into the project — picking
this back up means resolving that collision for real (replacing or
merging with the live `plateau_field.gd`) and retiring
`test/scripts/terrain_style_probe.gd`'s current noise-only view in favour
of this one.

## What's in here

- `plateau_field.gd` — land mask, coast distance, terrace, tier
  smoothing, region labelling, absorb, chamfer, single-tier-step
  enforcement, biome assignment.
- `access_solver.gd` — border-run collection, union-find from tier 0,
  slab/stairs placement, the 200-seed reachability check.
- `terrain_style_probe.gd` — the probe wired to both, plus two debug
  modes added independently of the plateau-field work (`0` plain noise
  levels, `9` raw noise grayscale) that are worth keeping regardless of
  what happens to the rest.

## Bugs found and fixed along the way, in order

1. Terrace noise frequency was sampling at 4x the intended wavelength
   (a cell-size unit conversion applied twice), collapsing most tiers
   into two flat bands after smoothing.
2. `AccessSolver` only recognised a border run between regions exactly
   one tier apart; nothing in the pipeline guaranteed that, so absorb
   and chamfer could leave two adjacent regions 2+ tiers apart with no
   way to ever be reachable. Fixed with `_enforce_single_tier_steps`, a
   worklist relaxation clamping every land cell to at most one tier
   above its lowest neighbour, run once at the end of `generate()`.
3. Island-discard used 8-connected flood fill while everything
   downstream (regions, border-runs, the fix above) used 4-connected —
   a diagonally-pinched blob could pass the mask stage as one landmass
   and still be structurally unreachable. Made island-discard
   4-connected too.

## Why this was shelved

After all three fixes the pipeline still wasn't landing visually and
kept surfacing new `AccessSolver` failures faster than they could be
chased down interactively, on top of a real multi-second bake at
512×512. Reverted the live probe back to the plain original noise
levels view rather than continue debugging blind. This snapshot exists
so that work isn't lost if it's worth another pass later — possibly
with the field size cut down for faster iteration, and the reachability
check run and read *before* trusting a visual look.
