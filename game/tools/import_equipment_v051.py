"""Inspect a generated original and record measured crop/alpha metadata.
Copy original bytes to production/source paths with native file tools first.
Pillow only inspects images; Python binary writes trigger the local DLP wrapper.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument("id")
p.add_argument("source", type=Path)
p.add_argument("--face", nargs=4, type=float, default=None, metavar=("X", "Y", "W", "H"))
p.add_argument("--note", default="")
a = p.parse_args()
out = root / "game/assets/art/pixel_v051"
sources = root / "game/art_sources/v051"
out.mkdir(parents=True, exist_ok=True)
sources.mkdir(parents=True, exist_ok=True)
image = Image.open(a.source).convert("RGBA")
alpha = image.getchannel("A")
bbox = alpha.point(lambda v: 255 if v >= 128 else 0).getbbox()
assert bbox
x, y, right, bottom = bbox
w, h = right-x, bottom-y
histogram = alpha.histogram()
records = []
for filename in ["history_v051_en_fr.json", "history_v051_de_it.json"]:
    records.extend(json.loads((root/"game/data"/filename).read_text(encoding="utf-8-sig")))
record = next(r for r in records if r["id"] == a.id)
slot = "helmet" if "_helmet_" in a.id else "armor"
target = out / (a.id+".png")
assert target.exists(), f"Native-copy the original to {target} first"
assert target.read_bytes() == a.source.read_bytes(), "Production bytes must match the selected original"
assert (sources/(a.id+"_source01.png")).read_bytes() == a.source.read_bytes()
face = [0,0,0,0] if a.face is None else [(a.face[0]-x)/w,(a.face[1]-y)/h,a.face[2]/w,a.face[3]/h]
metadata = {
    "id": a.id, "slot": slot, "image_path": "res://assets/art/pixel_v051/"+target.name,
    "source_region": [x,y,w,h], "source_size": list(image.size),
    "open_face": a.face is not None, "face_rect": face,
    "draw_size": [70,80] if slot=="helmet" else [94,104],
    "source_alpha_threshold": 128, "source_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    "historical_reference": {"title": record["name"], "object_number": record["source"], "date": record["historical_window"], "manufacture": record["manufacture"], "url": record["source_url"], "image_observed": True},
    "generation": {"tool": "built-in imagegen", "source_file": a.id+"_source01.png", "prompt_file": a.id+"_source01.md", "museum_image_supplied_to_tool": False, "reference_roles": ["Existing generated item as pixel style reference", "Museum original actually observed; structural text brief supplied"]},
    "inspection": {"status": "source visually inspected; runtime pending", "alpha0": histogram[0], "alpha1to254": sum(histogram[1:255]), "alpha255": histogram[255], "notes": a.note}
}
(out / (a.id+".json")).write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"id": a.id, "size": image.size, "bbox": metadata["source_region"], "face_rect": face}, ensure_ascii=False))
