# Cozy God Sim

A cozy 3D god-sim / simulation game built in Godot 4 (GDScript).

## Stack

- Godot 4.7+, Forward+ renderer
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
  out of scene scripts (economy, needs, weather, etc.). Holds `village.gd`/
  `villager.gd` and `god.gd`/`pantheon.gd` so far.
- `assets/{models,textures,audio}/` — real art/audio assets go here as they
  replace the placeholder primitives in `scripts/world_gen.gd`.
- `ui/` — UI scenes/scripts. First resident: `folk_console.tscn`, a
  developer console for the local-LLM idea pipeline (see
  `ui/folk_console.md`) — instanced hidden into `scenes/main.tscn`,
  toggled with F2; not part of the player-facing game.
- `tests/` — GUT tests (`extends GutTest`, `test_*.gd`), mirroring the
  layout of what they test (e.g. `tests/systems/test_village.gd`).
- `addons/gut/` — vendored GUT addon; see the Stack exception above.

## Conventions

- Prefer typed GDScript (`var x: int`, `-> void`) for anything non-trivial.
- Keep scene scripts thin; push reusable logic into `systems/` as it grows.
- **Module hygiene**: don't let a single file become a grab-bag. When a
  change doesn't fit cleanly into an existing file's concern, or that file
  is already carrying too many distinct responsibilities for one person
  to hold in their head, extract a new file under `systems/` (or
  `scripts/` for scene-glue) with a matching test file under `tests/`,
  rather than piling on. Match this repo's existing per-concern split
  (e.g. `farm.gd` vs `village_farms.gd`) instead of reflexively growing
  the biggest/most obvious file. This applies equally to interactive
  work and AFK/cloud agent sessions. Don't go refactor someone else's
  (or another agent's) existing file just to tidy it — extract only what
  your own change needs; leave general untidiness for a deliberate pass.
- **Comment discipline**: code comments should be one-liners (or nothing)
  stating current behavior/invariants — the kind of thing that's true
  regardless of how it got that way. Drop issue-number/decision-history
  narration (why this shape was chosen, what was considered and
  rejected, which ticket asked for it); that belongs in git/PR history
  and `docs/systems-overview.md`, not in the code. If a comment only
  makes sense to someone who's read the GitHub issue, it belongs in the
  issue/docs, not next to the code.
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

### Implementing tickets

What to read before starting (trimmed — not the full docs), and how to
verify your own work before claiming it's done. See
`docs/agents/implementing-tickets.md`.
