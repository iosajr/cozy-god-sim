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
    (time of day, resources, the one `Village`) — `autoload/game_state.gd`
  - A `Village` of placeholder `Villager`s (Faith flag + a cycling Thought
    each), spawned with a floating thought-bubble nameplate over each one —
    `systems/village.gd`, `systems/villager.gd`, `scripts/village_spawner.gd`,
    `scripts/villager_nameplate.gd`
- [GUT](https://github.com/bitwes/Gut) (Godot Unit Test), vendored under
  `addons/gut/`, as the project's test framework — see `tests/`.
- `ui/` and `assets/{models,textures,audio}/` folders ready to fill in as
  the game grows.
- [Matt Pocock's engineering & productivity skills](https://github.com/mattpocock/skills)
  vendored under `.claude/skills/` for use with Claude Code.

## Getting started

1. Open this folder in [Godot 4.7+](https://godotengine.org/download).
   It should import automatically and `scenes/main.tscn` is set as the
   main scene.
2. Press F5 (or the Play button) to run. You should see a grassy field
   with scattered trees/rocks, an RTS-style camera, a moving sun, and a
   handful of Villagers with floating Thought nameplates.
3. Working with Claude Code in this repo? Run the `setup-matt-pocock-skills`
   skill once to configure it for this project (issue tracker, triage
   labels, doc preferences). See `.claude/skills/SOURCE.md` for details on
   the vendored skills and how to update them.

## Running tests

Tests use [GUT](https://github.com/bitwes/Gut), vendored under
`addons/gut/`. With the Godot editor binary on your `PATH`:

```sh
godot --headless -s addons/gut/gut_cmdln.gd
```

`.gutconfig.json` points GUT at `res://tests` (including subdirectories)
and exits with a non-zero code on failure, so this is CI-friendly as-is.

## Next steps

Some natural next things to build, roughly in order:

- Replace the placeholder tree/rock primitives in `world_gen.gd`, and the
  placeholder Villager capsule/nameplate, with real assets once you have
  art direction.
- Click-to-place buildings on the ground (the `GroundBody` StaticBody3D is
  already there to raycast against).
- Wish/Petition/Nudge and Faith actually gating Presence-sensing — see
  `CONTEXT.md` and `docs/systems-overview.md`.
- Basic UI (`ui/`) for resources and time of day.

## License

No license chosen yet for the game code — add one when you're ready to
share it publicly. The vendored skills under `.claude/skills/` are MIT
licensed by Matt Pocock (see `.claude/skills/LICENSE-mattpocock-skills`).
