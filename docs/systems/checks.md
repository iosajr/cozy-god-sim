# Checks

Catching the game contradicting itself, and letting you read any of it
while it runs.

## The inspector panel

A panel inside the running game, not Godot's own Inspector. The Inspector
can only show what sits on a node, which is what made state undiscoverable
before: a slice of it on each of thirty spawned bodies, found by digging
through the remote tree.

- **Styled like the Inspector**, so it reads as familiar rather than as a
  second thing to learn.
- Opens on a key. Lists everything currently in view — the same query the
  view spawner already runs to decide what to draw, so it costs nothing
  extra.
- Pick a row, or click a being in the world, to open it.
- Shows the whole record: who it is, age, how hungry and how tired,
  current task and where it is walking, its memories with timestamps, what
  it last finished.
- **Reads the store, so it works for records with no node.** Something
  off-screen can still be inspected. Nothing spawned can ever be a
  prerequisite for seeing state.
- Scrolls vertically. **Never stretches off screen horizontally** — long
  values wrap or scroll inside their own row.
- Interactive throughout: rows expand, references are followable, so
  opening a being and stepping to its home or its settlement is one click.

## Invariant checks

- Named checks over the world: a task claimed by nobody, memories over the
  cap, a being off the map, starving but idle.
- Run on a cadence and report what fires. They run against the live game,
  which is where the real bugs were.
- Every bug found by hand becomes a check, so the same one cannot come
  back quietly.

## Not its job

Checks observe and report. They never repair, and never change what the
game does. The inspector reads and never writes.
