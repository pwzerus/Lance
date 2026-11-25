"""Collect bounded PHYS-115 release evidence without launching the game.

No cleanup, save writes, automatic passing of known failures, or user data.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
from datetime import datetime, timezone


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest().upper()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--runs", nargs="+", required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    bundle = Path(args.bundle).resolve()
    output = Path(args.output).resolve()
    assert bundle.parent == (repo / "builds").resolve()
    assert output.is_relative_to(repo / "docs/development") and not output.exists()
    manifest = read(bundle / "build-manifest.json")
    files = []
    for item in manifest["files"]:
        path = (bundle / item["path"]).resolve()
        assert path.is_relative_to(bundle) and path.is_file()
        files.append({"path": item["path"], "bytes": path.stat().st_size,
                      "sha256": sha(path),
                      "matches_manifest": sha(path) == item["sha256"].upper()
                      and path.stat().st_size == item["bytes"]})
    runs = []
    for name in args.runs:
        assert re.fullmatch(r"phys115-[a-z0-9-]+", name)
        folder = repo / "docs/development/logs" / name
        receipt = folder / "receipt.json"
        entry = {"name": name, "receipt": read(receipt),
                 "receipt_sha256": sha(receipt), "target": read(folder / "target.json")}
        # Source fingerprints and driver chain remain in their original file;
        # the committed compact audit seals that file rather than duplicating it.
        entry["target_sha256"] = sha(folder / "target.json")
        entry["target"].pop("source_fingerprints", None)
        memory = (folder / "memory.log").read_text(encoding="utf-8-sig")
        samples = [float(v) for v in re.findall(r"privateMiB=([0-9.]+)", memory)]
        entry["private_mib_sample_peak"] = max(samples, default=0)
        entry["reports"] = []
        for path in [folder / "report.json", folder / "results/report.json"]:
            if not path.exists():
                continue
            data = read(path)
            row = {"path": path.relative_to(repo).as_posix(), "sha256": sha(path)}
            for key in ["passed", "failures", "releases", "all_frames", "wall_seconds",
                        "completed_requested_segment", "version", "scope"]:
                if key in data:
                    row[key] = data[key]
            for key in ["cases", "rows", "games", "matches", "captures"]:
                if isinstance(data.get(key), list):
                    row[key + "_count"] = len(data[key])
            entry["reports"].append(row)
        runs.append(entry)
    baseline = read(repo / "docs/development/PHYS115_SAVE_BASELINE.json")
    saves = []
    for item in baseline["files"]:
        path = Path(item["path"])
        saves.append({"name": path.name, "bytes": path.stat().st_size,
                      "unchanged": sha(path) == item["sha256"].upper()
                      and path.stat().st_size == item["bytes"]})
    report = {"utc": datetime.now(timezone.utc).isoformat(),
              "status": "development_candidate_with_recorded_remaining_issues",
              "scope": "Protected background rules/rendering/injected input only; no human or desktop input acceptance.",
              "version": manifest["version"], "source_revision": manifest["source_revision"],
              "bundle": str(bundle), "manifest_sha256": sha(bundle / "build-manifest.json"),
              "files": files, "runs": runs, "formal_save_baseline_utc": baseline["utc"],
              "formal_saves": saves,
              "commercial_or_human_acceptance": False}
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    assert all(row["matches_manifest"] for row in files)
    assert all(row["unchanged"] for row in saves)
    print("Recorded", len(runs), "runs,", len(files), "package files and", len(saves), "unchanged formal saves.")


if __name__ == "__main__":
    main()
