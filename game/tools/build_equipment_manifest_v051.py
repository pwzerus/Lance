"""Validate generated equipment metadata and build the runtime lookup (no image edits)."""
import argparse
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--complete", action="store_true")
args = parser.parse_args()
manifest = {}
for path in sorted((root / "game/assets/art/pixel_v051").glob("*.json")):
    item = json.loads(path.read_text(encoding="utf-8-sig"))
    item_id = item["id"]
    assert item_id == path.stem
    png = root / "game" / item["image_path"].removeprefix("res://")
    assert png.is_file(), png
    assert hashlib.sha256(png.read_bytes()).hexdigest() == item["source_sha256"], png
    x, y, w, h = item["source_region"]
    sw, sh = item["source_size"]
    assert x >= 0 and y >= 0 and w > 0 and h > 0 and x+w <= sw and y+h <= sh, path
    assert item["historical_reference"]["image_observed"] is True
    assert item_id not in manifest
    manifest[item_id] = {key: item[key] for key in ["image_path", "source_region", "draw_size", "source_sha256"]}
    if item["slot"] == "helmet":
        manifest[item_id].update(open_face=item["open_face"], face_rect=item["face_rect"])
if args.complete:
    expected = {f"{country}_{slot}_{tier}" for country in ["eng", "fr", "de", "it"] for slot in ["helmet", "armor"] for tier in range(6)}
    assert manifest.keys() == expected, ("missing", sorted(expected-manifest.keys()))
target = root / "game/data/equipment_art_v051.json"
target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(f"{len(manifest)} equipment assets validated; wrote {target}")
