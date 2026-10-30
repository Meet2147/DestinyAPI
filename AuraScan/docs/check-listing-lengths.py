#!/usr/bin/env python3
"""Verify every field in app-store-listing.md fits App Store Connect's limits.

Run after editing the copy: python3 docs/check-listing-lengths.py
Apple truncates silently in some fields and rejects in others, so checking
beats discovering it in the web form.
"""
import re
import sys
from pathlib import Path

LIMITS = {
    "App name": 30,
    "Subtitle": 30,
    "Promotional text": 170,
    "Keywords": 100,
    "Description": 4000,
    "What's New": 4000,
}

doc = Path(__file__).with_name("app-store-listing.md").read_text()

def first_block_after(heading: str) -> str | None:
    """The first fenced code block following a heading."""
    at = doc.find(f"## {heading}")
    if at == -1:
        return None
    m = re.search(r"```\n(.*?)\n```", doc[at:], re.S)
    return m.group(1) if m else None

failed = False
for field, limit in LIMITS.items():
    # Headings carry the limit, e.g. "## Subtitle (30 max)".
    key = next((h for h in (field,) if f"## {h}" in doc), None)
    text = first_block_after(key) if key else None
    if text is None:
        print(f"  ?  {field:<18} not found")
        continue
    n = len(text)
    ok = n <= limit
    failed |= not ok
    print(f"  {'OK' if ok else '!!':<2} {field:<18} {n:>5} / {limit}")

# IAP display names and descriptions live in a table.
for row in re.findall(r"^\| `(ai\.aurascan[^`]+)` \| `([^`]+)` \| `([^`]+)` \|$",
                      doc, re.M):
    pid, name, desc = row
    for label, value, limit in (("name", name, 30), ("desc", desc, 45)):
        ok = len(value) <= limit
        failed |= not ok
        print(f"  {'OK' if ok else '!!':<2} {pid.split('.')[-1]+' '+label:<18} "
              f"{len(value):>5} / {limit}")

sys.exit(1 if failed else 0)
