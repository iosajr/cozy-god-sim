# Cozy God Sim

A cozy 3D god-sim built in Godot 4 (GDScript). The player is not a god —
they watch a world of gods, folk, animals and plants living their own
lives, and have a quiet effect at the margins.

## Rules

**Anything not covered here, ask. Silence is not permission.**

1. Ask before touching anything outside the files you were asked to
   change — commits, moving or deleting files, publishing, installing.
2. Never verify visual or runtime behaviour yourself. No screenshots, no
   test runs, not even to reproduce a reported bug. Stop at a lookable
   point, say what to look for, hand it over.
3. Say what you think before building it. If the ask looks wrong or
   under-specified, say so and propose something better.
4. Comments are one-liners stating what is true now, or nothing. No
   history, no issue numbers, no pointers to other files.
5. Documents follow the same rule. One document per system, nothing tries
   to describe the whole game, and superseded content is deleted rather
   than marked.
6. Don't invent lore, tone, or intent. Mark it open and ask.

## Stack

- Godot 4.7+, Forward+ renderer. Typed GDScript.
- No test framework, deliberately. Don't add one without being asked.
- Keep dependencies minimal.

## Layout

Every system has exactly one doc, `docs/systems/<name>.md`, and once it
has code, one folder of the same name under `scripts/` holding everything
that system owns. If you can't name which doc a file belongs under,
that's the problem — not where to put it.

```
scripts/
  sim_host.gd             wires every system's scene glue together —
                          the one script allowed to know about all of them
  clock/                  absolute game time, seasons, speed
  world/                  the store that owns every record, and the
                          terrain interface — headless, no scene tree
  entities-and-species/   entity, species resources, behaviours
  memory/                 memories, events and places alike
  settlement-and-jobs/    settlement, job manager
  view-camera-terrain/    camera, view spawner — reads the world,
                          never writes to it
  checks/                 inspector panel, debug views, invariant checks
scenes/         .tscn files
test/           prototype and probe code not decided to keep —
                scenes/ and scripts/, same split as above
assets/         models, textures, audio
docs/           see below
legacy/         the old codebase. Salvage only. Nothing new goes here.
```

A system folder can hold both headless data and scene glue side by side —
the split that matters is by system, not by folder. Within a system,
headless code still never touches the scene tree, and code that reads the
world never writes to it.

## Docs

- `docs/systems-overview.html` — the design. Eight systems, what each
  owns, what it deliberately doesn't. Published as an artifact from this
  file; edit it here and republish.
- `docs/systems/` — one file per system, holding its decided details and
  its open questions.
- `docs/to-decide.md` — open questions waiting on the user. Raise them
  regularly, and delete anything that stops being worth deciding.
- `docs/research/` — findings from outside sources.
- `docs/prompts/` — self-contained prompts for handing a scoped job to a model.
- `VISION.md`, `CONTEXT.md` — the pitch, and the glossary.

## Issue tracker

GitHub Issues (`iosajr/cozy-god-sim`) via the `gh` CLI. Triage labels:
`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`,
`wontfix`.
