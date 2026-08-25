"""
Reads the "Where the code actually is right now" section of
docs/systems-overview.md -- the part of that doc written specifically to
answer what's real vs. not-yet-built (see that doc's own intro). That's
exactly the "current systems" context villager-ideas's system prompt
asks for, so the model doesn't suggest something that already exists.
Feeding the whole doc would burn most of the model's small context
window (num_ctx 4096) on Pantheon/language lore it doesn't need for this.
"""
import config

SECTION_HEADER = "## Where the code actually is right now"


def load_systems_summary():
    try:
        with open(config.SYSTEMS_OVERVIEW_PATH, "r", encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return "(systems-overview.md not found -- no current-systems context available)"

    start = text.find(SECTION_HEADER)
    if start == -1:
        return text.strip()  # fall back to the whole doc rather than nothing
    start += len(SECTION_HEADER)
    end = text.find("\n## ", start)
    section = text[start:end] if end != -1 else text[start:]
    return section.strip()
