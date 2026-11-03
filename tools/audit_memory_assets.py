"""Metadata-only asset census. Never launches Godot or decodes an image.

RGBA8 estimates are one texture copy, not process memory or GPU measurements.
Runtime reachability, compressed formats, mipmaps and driver copies vary.
"""
import argparse
import json
from pathlib import Path
import re
import struct


def census(project):
    images = []
    for path in sorted((project / "assets").rglob("*.png")):
        with path.open("rb") as source:
            header = source.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
            raise ValueError(f"Invalid PNG header: {path}")
        width, height = struct.unpack(">II", header[16:24])
        if not width or not height:
            raise ValueError(f"Invalid dimensions: {path}")
        settings = Path(str(path) + ".import")
        content = settings.read_text(encoding="utf-8") if settings.exists() else ""
        limit = re.search(r"^process/size_limit=(\d+)$", content, re.M)
        size_limit = int(limit[1]) if limit else 0
        ratio = min(1.0, size_limit / max(width, height)) if size_limit else 1.0
        estimated_width = max(1, round(width * ratio))
        estimated_height = max(1, round(height * ratio))
        images.append({"path": path.relative_to(project).as_posix(),
                       "width": width, "height": height,
                       "file_bytes": path.stat().st_size,
                       "source_rgba8_bytes": width * height * 4,
                       "configured_size_limit": size_limit,
                       "estimated_import_rgba8_bytes": estimated_width * estimated_height * 4,
                       "mipmaps": "mipmaps/generate=true" in content})
    scripts = list((project / "scripts").rglob("*.gd"))
    return {"scope": "All assets PNG headers, including unused/export-excluded assets; no decoding or engine run",
            "estimate_limits": "One RGBA8 base level only. Excludes font caches, audio, meshes, mipmaps, driver allocations and duplicate copies. Import dimensions are estimates, not measured imported resources.",
            "png_count": len(images), "script_count": len(scripts),
            "total_source_rgba8_bytes": sum(i["source_rgba8_bytes"] for i in images),
            "total_estimated_import_rgba8_bytes": sum(i["estimated_import_rgba8_bytes"] for i in images),
            "total_png_file_bytes": sum(i["file_bytes"] for i in images),
            "images": images}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    report = census(Path(__file__).resolve().parents[1] / "game")
    # Preserve prior evidence; each run gets a fresh filename.
    with args.report.open("x", encoding="utf-8") as output:
        json.dump(report, output, ensure_ascii=False, indent=2)
        output.write("\n")
    print(json.dumps({k: v for k, v in report.items() if k != "images"}, ensure_ascii=False))
