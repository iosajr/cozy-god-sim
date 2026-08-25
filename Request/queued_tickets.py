"""
Reads currently-open GitHub issue titles via the `gh` CLI, so persona.py
can tell villager-ideas what's "already queued" -- exactly the input its
system prompt asks for to avoid suggesting a duplicate. Requires `gh`
installed and authenticated (`gh auth login`); falls back to an empty
list (with a printed warning) if that fails, since this is a dedup aid,
not a hard requirement to run the pipeline at all.
"""
import json
import subprocess
import config


def load_queued_titles():
    cmd = [
        "gh", "issue", "list",
        "--state", "open",
        "--limit", str(config.MAX_QUEUED_TICKETS),
        "--json", "title",
    ]
    if config.GITHUB_REPO:
        cmd += ["--repo", config.GITHUB_REPO]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    except Exception as e:
        print(f"Could not list open issues (continuing without dedup context): {e}")
        return []

    if result.returncode != 0:
        print(f"Could not list open issues (continuing without dedup context): {result.stderr.strip()}")
        return []

    return [item["title"] for item in json.loads(result.stdout)]
