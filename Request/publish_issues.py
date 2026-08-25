"""
Turns approved-but-not-yet-published items into GitHub issues.
Requires the `gh` CLI installed and authenticated (`gh auth login`).
Run: python publish_issues.py
"""
import json
import subprocess
import config


def load_all():
    items = []
    with open(config.REVIEW_QUEUE_PATH, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    return items


def save_all(items):
    with open(config.REVIEW_QUEUE_PATH, "w") as f:
        for item in items:
            f.write(json.dumps(item) + "\n")


def publish(item):
    wish = item.get("wish") or "(untitled wish)"
    # A WISH is formatted "<title> - <description>" per villager-ideas's
    # contract -- use just the title half for the issue title, the whole
    # thing in the body.
    title_part = wish.split(" — ", 1)[0].split(" - ", 1)[0]
    title = f"[{item['villager_name']}] {title_part[:70]}"
    body = (
        f"**Proposed by:** {item['villager_name']}\n\n"
        f"**In character:**\n{item['in_character_response']}\n\n"
        f"**Wish:** {wish}\n\n"
        f"_Generated locally by villager-ideas, approved by a human reviewer before publishing._"
    )

    cmd = [
        "gh", "issue", "create",
        "--title", title,
        "--body", body,
        "--label", config.GITHUB_LABEL,
        "--label", config.GITHUB_TRIAGE_LABEL,
    ]
    if config.GITHUB_REPO:
        cmd += ["--repo", config.GITHUB_REPO]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Failed to publish '{title}': {result.stderr.strip()}")
        return False
    print(f"Published: {title}\n  -> {result.stdout.strip()}")
    return True


def main():
    items = load_all()
    to_publish = [i for i in items if i["status"] == "approved" and not i["published"]]

    if not to_publish:
        print("Nothing approved and unpublished.")
        return

    for item in to_publish:
        if publish(item):
            item["published"] = True

    save_all(items)


if __name__ == "__main__":
    main()
