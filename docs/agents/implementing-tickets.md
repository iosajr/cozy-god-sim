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

## Verifying your own work

Run the real test suite before claiming anything is done —
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

## What "done" means here

This project never trusts an agent's self-report, including this one's.
Whoever merges your branch will independently re-run the full suite from
a clean checkout and read the real diff before it lands anywhere shared.
That's not a signal you did something wrong — it's the standing process
for every merge in this repo, so don't skip your own verification step
on the assumption someone downstream will catch it instead.
