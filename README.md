# Cozy God Sim

A starter project for a cozy 3D god-sim / simulation game, built with
[Godot 4](https://godotengine.org/) and GDScript.

## What's here

- A minimal 3D starter scene (`scenes/main.tscn`) with:
  - An RTS-style camera (WASD/arrow pan, scroll to zoom, right-drag to
    rotate, optional edge-of-screen panning) — `scripts/camera_rig.gd`
  - A scattered placeholder world (procedurally placed trees/rocks on a
    ground plane) — `scripts/world_gen.gd`
  - A simple day/night cycle driving the sun light — `scripts/day_night_cycle.gd`
  - A `GameState` autoload singleton for shared simulation state
    (time of day, resources, population) — `autoload/game_state.gd`
- Empty `systems/`, `ui/`, and `assets/{models,textures,audio}/` folders
  ready to fill in as the game grows.
- [Matt Pocock's engineering & productivity skills](https://github.com/mattpocock/skills)
  vendored under `.claude/skills/` for use with Claude Code.

## Getting started

1. Open this folder in [Godot 4.3+](https://godotengine.org/download).
   It should import automatically and `scenes/main.tscn` is set as the
   main scene.
2. Press F5 (or the Play button) to run. You should see a grassy field
   with scattered trees/rocks, an RTS-style camera, and a moving sun.
3. Working with Claude Code in this repo? Run the `setup-matt-pocock-skills`
   skill once to configure it for this project (issue tracker, triage
   labels, doc preferences). See `.claude/skills/SOURCE.md` for details on
   the vendored skills and how to update them.

## Next steps

Some natural next things to build, roughly in order:

- Replace the placeholder tree/rock primitives in `world_gen.gd` with real
  assets (or a proper terrain/biome system) once you have art direction.
- Click-to-place buildings on the ground (the `GroundBody` StaticBody3D is
  already there to raycast against).
- A first real simulation system under `systems/` (e.g. villager needs, or
  a simple economy) driven by `GameState`.
- Basic UI (`ui/`) for resources and time of day.

## License

No license chosen yet for the game code — add one when you're ready to
share it publicly. The vendored skills under `.claude/skills/` are MIT
licensed by Matt Pocock (see `.claude/skills/LICENSE-mattpocock-skills`).
