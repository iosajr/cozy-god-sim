"""
Human review CLI. Run: python review.py
Walks through pending items one at a time; you approve, reject, or skip.
"""
import json
import config


def load_all():
    items = []
    try:
        with open(config.REVIEW_QUEUE_PATH, "r") as f:
            for line in f:
                line = line.strip()
                if line:
                    items.append(json.loads(line))
    except FileNotFoundError:
        pass
    return items


def save_all(items):
    with open(config.REVIEW_QUEUE_PATH, "w") as f:
        for item in items:
            f.write(json.dumps(item) + "\n")


def main():
    items = load_all()
    pending = [i for i in items if i["status"] == "pending"]

    if not pending:
        print("Nothing pending review.")
        return

    print(f"{len(pending)} item(s) pending review.\n")
    for item in pending:
        print("-" * 60)
        print(item["villager_name"])
        print(item["in_character_response"])
        print(f"\nWish: {item['wish'] or '(model did not produce a parseable WISH: line)'}")
        choice = input("\n[a]pprove / [r]eject / [s]kip / [q]uit: ").strip().lower()

        if choice == "a":
            item["status"] = "approved"
        elif choice == "r":
            item["status"] = "rejected"
        elif choice == "q":
            break
        # 's' or anything else: leave as pending

    save_all(items)
    print("\nSaved.")


if __name__ == "__main__":
    main()
