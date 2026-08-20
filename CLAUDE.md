# Cozy God Sim

A cozy 3D god-sim / simulation game built in Godot 4 (GDScript).

## Stack

- Godot 4.3+, Forward+ renderer
- GDScript (typed where practical)
- Keep dependencies minimal until there's a real need. One exception so
  far: [GUT](https://github.com/bitwes/Gut) (Godot Unit Test), vendored
  under `addons/gut/` — the project's test framework, added because
  `systems/village.gd`/`systems/villager.gd` and
  `scripts/villager_nameplate.gd` aren't testable without one (issue #2).
  Run it with `godot --headless -s addons/gut/gut_cmdln.gd`
  (`.gutconfig.json` points it at `res://tests`).

## Layout

- `scenes/` — `.tscn` scene files. `main.tscn` is the entry point.
- `scripts/` — GDScript attached to scene nodes.
- `autoload/` — singletons registered in `project.godot` under `[autoload]`.
  `GameState` is the only one so far; keep autoloads few and boring.
- `systems/` — home for standalone simulation systems as they're extracted
  out of scene scripts (economy, needs, weather, etc.). Empty for now.
- `assets/{models,textures,audio}/` — real art/audio assets go here as they
  replace the placeholder primitives in `scripts/world_gen.gd`.
- `ui/` — UI scenes/scripts, currently empty.
- `tests/` — GUT tests (`extends GutTest`, `test_*.gd`), mirroring the
  layout of what they test (e.g. `tests/systems/test_village.gd`).
- `addons/gut/` — vendored GUT addon; see the Stack exception above.

## Conventions

- Prefer typed GDScript (`var x: int`, `-> void`) for anything non-trivial.
- Keep scene scripts thin; push reusable logic into `systems/` as it grows.
- `GameState` is a bulletin board (shared data + signals), not a place for
  gameplay logic — see the doc comment at the top of `game_state.gd`.
- Placeholder art in `world_gen.gd` is intentionally disposable — don't
  build real gameplay logic on top of the exact primitive shapes.

## Skills

This repo has Matt Pocock's engineering/productivity skills vendored under
`.claude/skills/` (see `.claude/skills/SOURCE.md` for provenance and how to
update them). Notable ones for this project:

- `tdd`, `code-review`, `diagnosing-bugs` — day-to-day engineering loop
- `domain-modeling`, `codebase-design` — useful as the simulation systems
  in `systems/` take shape
- `to-spec`, `to-tickets`, `implement` — turning ideas into tracked work

Run the `setup-matt-pocock-skills` skill once to configure this repo
(issue tracker, triage labels, doc preferences).

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`iosajr/cozy-god-sim`), via the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: root `CONTEXT.md` + `docs/adr/`. See
`docs/agents/domain.md`.
