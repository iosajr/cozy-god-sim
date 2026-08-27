# Implementing a published ticket

For an agent (interactive, background `Agent`-tool, or cloud routine)
picking up an already-published GitHub issue (`ready-for-agent`) and
building it for real.

## What to read first

Do **not** read `CONTEXT.md` and `docs/systems-overview.md` in full
before starting — that's redundant with a well-written ticket and burns
real budget for no benefit (confirmed cost: a 2026-08-23 overnight batch
where every stage independently read all three docs, ~1,237 lines, from
scratch — one stage's own ticket body was 21 lines and fully
self-contained). Instead:

1. `CLAUDE.md` in full — short, stable repo conventions, always worth it.
2. The GitHub issue in full (`gh issue view <n>`) — that's the real spec.
3. A targeted grep of `docs/systems-overview.md` for the issue's own
   number or feature name (most tickets already have a matching section
   from when they were spec'd) — read just that section, for doc-update
   placement, not the whole file.
4. Skip `CONTEXT.md` entirely unless the ticket touches genuinely new
   domain terminology it doesn't already define inline.
5. Real code exploration (grep/read the actual files being touched)
   stays as normal — that's real integration work, not avoidable context
   bloat.

This applies to implementation work specifically. Domain-modeling/spec-
writing (`/to-spec`, `/domain-modeling` sessions) still genuinely needs
the full docs — don't trim those.

## Direct work vs. background agents

Default to implementing a ticket batch directly, in the live session,
when the user is present and asks to begin now — not by spawning
background `Agent`-tool subagents. Reserve background/cloud agents for
batches the user explicitly wants running unattended or overnight. Each
backgrounded agent carries real fixed overhead (its own environment
bootstrap, its own self-verification, plus the orchestrating session's
mandatory independent re-verification on top) that isn't worth paying
when the user is right there and the work could just be done directly.
If unsure which the user wants, ask rather than default to spawning
agents.

## Don't try to run Godot yourself

If you're a background `Agent`-tool worktree or a cloud routine: write
real GUT tests for whatever you build (`extends GutTest`, `test_*.gd`,
mirroring `tests/`'s existing layout) — but **do not try to bootstrap or
run Godot/GUT yourself**. Implement, write the tests, commit, and stop
there. Leave actually running the suite to the user or the live
interactive session.

**Why**: this project already has a standing rule that nothing merges
without the human/interactive session independently re-running the full
suite from a clean checkout regardless — an agent-side attempt at the
same setup is redundant, not extra safety, and bootstrapping a working
headless Godot environment from scratch is genuinely fiddly (a bad
bootstrap has silently hung for over an hour before — see below). Cloud
sandboxes in particular have also repeatedly failed to find a working
Godot at all, or found a stray old one and used it instead of what the
repo actually targets — don't hunt for or install a Godot binary; if one
isn't already set up in your environment, that's expected, not a problem
to solve.

## Verifying the work (user or interactive session only)

Run the real test suite before calling anything actually done —
`godot --headless -s addons/gut/gut_cmdln.gd` (config in
`.gutconfig.json`). On a **freshly-created worktree** with no `.godot/`
cache yet, bootstrap it first:

```
godot --headless --editor --quit-after 60
```

**Not** bare `--editor --quit` — that aborts the async import/class-scan
thread before it finishes and silently leaves the cache incomplete,
which then causes either immediate parse errors on the next GUT run, or
(observed for real, cost over an hour before being caught) a hang with
zero output. Run the bootstrap twice if GUT reports new unimported
images after the first pass.

Before committing, run `git status`/`git diff --stat` and review the
file list — commit only what your change actually touches. **Never
`git add -A` blindly**: an editor bootstrap run can rewrite unrelated
`.import` files (font/image import configs) as version-format drift if
the locally-used Godot binary differs from whichever version last
touched those files in the repo — that's not a real change and must not
be committed.

Two more real footguns, both of which caused an actual broken/stale push
to `main` here: (1) `git add <path1> <path2> ...` silently aborts the
**entire** command with no partial staging if any one listed path was
already staged for deletion via `git rm` — stage `git rm` and `git add`
paths in separate commands, never mixed in one multi-path `git add`.
(2) `git mv` only stages the rename — if you edit that file's content
afterward, `git add` it again before committing, or the commit ships the
pre-edit content under the new name. After staging, sanity-check with
`git status --short`/`git diff HEAD --stat` rather than trusting a zero
exit code alone.

## What "done" means here

For a background/cloud agent: implementation + real tests written +
committed, nothing more — you are not expected to have run them (see
above), and this project never merges on a self-report anyway. For the
user or interactive session merging the branch: independently re-run the
full suite from a clean checkout and read the real diff before it lands
anywhere shared. That's the standing verification step for every merge in
this repo — it's not optional just because an agent says its own tests
pass, and for a background/cloud agent it hasn't actually run them at
all.
