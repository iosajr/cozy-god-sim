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

## No test framework currently vendored

GUT was removed 2026-08-28 — it never caught the runtime/visual bugs
that actually came up in practice, and added its own version friction
(only one specific Godot install on the maintainer's machine could run
it at all). **Don't reach for GUT, and don't vendor a replacement test
framework on your own initiative** — the verification approach for the
rebuild is an open decision, not something to default back to silently.
If a ticket needs tests and none of this guidance covers how, ask rather
than assume.

If a headless Godot bootstrap is ever needed again for some other reason
(a freshly-created worktree with no `.godot/` cache yet), use
`godot --headless --editor --quit-after 60`, not bare `--editor --quit`
— the bare form aborts the async import/class-scan thread before it
finishes and silently leaves the cache incomplete, which then causes
parse errors or (observed for real, cost over an hour before being
caught) a hang with zero output. Run it twice if new unimported assets
get reported after the first pass.

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

## Visual work is signed off by the user, not self-certified

Automated tests, if this project has any at a given point, prove logic.
They never prove feel, and feel is what has actually gone wrong here
repeatedly — including runtime/visual bugs that passed every test anyway.
**Do not render, screenshot, or re-run the game yourself to grade your
own work or to re-check something the user already reported.** When a
change touches anything visible — terrain, weather, nameplates, spawning,
UI, camera — stop at the point where it can be looked at, say plainly
what to look for and how to get there, and hand it to the user. When the
user reports a bug, ask what they saw rather than trying to reproduce it
yourself first.

They will look at it. That catches bad feel in one glance, far earlier
and for a tiny fraction of the tokens a self-run screenshot loop costs.

## What "done" means here

For a background/cloud agent: implementation committed, nothing more —
this project never merges on a self-report. For the user or interactive
session merging the branch: independently re-verify (whatever that means
at the time — a test suite if one exists, a real diff read regardless)
before it lands anywhere shared. That's the standing verification step
for every merge in this repo, not optional just because an agent reports
success.
