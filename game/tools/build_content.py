"""Validate the authored catalogue without touching game sources or images.

Run with Python 3: python game/tools/build_content.py
The checked-in equipment.json is the authoritative authored catalogue.
Runtime audio is synthesized by scripts/visual/sound_bank.gd.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    items = json.loads((ROOT / "data/equipment.json").read_text(encoding="utf-8"))
    identifiers = set()
    slots = {"armor", "helmet", "lance", "horse", "crest"}
    for item in items:
        assert item["id"] not in identifiers, f"Duplicate item: {item['id']}"
        identifiers.add(item["id"])
        assert item["slot"] in slots, item["id"]
        assert 0 <= item["era"] <= 4, item["id"]
        assert item["price"] >= 0, item["id"]
        assert item["source"] and item["historical_note"], item["id"]
        assert isinstance(item["stats"], dict), item["id"]
    print(f"Validated {len(items)} equipment items across five unlock eras.")


if __name__ == "__main__":
    main()
