"""Archive an already verified PHYS-115 bundle; preserve every older candidate.

No engine launch, no deletion. Streaming copies/hashes keep memory bounded.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest().upper()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--evidence", required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    builds = (repo / "builds").resolve()
    bundle = Path(args.bundle).resolve()
    assert bundle.parent == builds
    assert re.fullmatch(r"LanceAndLaurel-v0\.5\.0-c[1-9][0-9]*", bundle.name)
    evidence = Path(args.evidence).resolve()
    assert evidence.is_relative_to(repo / "docs" / "development" / "logs")
    assert not evidence.exists()
    manifest = json.loads((bundle / "build-manifest.json").read_text(encoding="utf-8-sig"))
    for item in manifest["files"]:
        path = (bundle / item["path"]).resolve()
        assert path.is_relative_to(bundle) and path.is_file()
        assert path.stat().st_size == item["bytes"] and digest(path) == item["sha256"].upper()
    expected = {item["path"] for item in manifest["files"]} | {"build-manifest.json"}
    actual = {p.relative_to(bundle).as_posix() for p in bundle.rglob("*") if p.is_file()}
    assert actual == expected
    archive = builds / (bundle.name + ".zip")
    relocation = builds / ("PHYS115 便携验证 " + manifest["version"]) / bundle.name
    assert not archive.exists() and not relocation.exists()
    evidence.mkdir(parents=True)
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for name in sorted(actual):
            output.write(bundle / name, bundle.name + "/" + name)
    relocation.mkdir(parents=True)
    with zipfile.ZipFile(archive) as source:
        assert source.testzip() is None
        for name in source.namelist():
            relative = Path(name).relative_to(bundle.name)
            target = (relocation / relative).resolve()
            assert target.is_relative_to(relocation)
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.open(name) as src, target.open("xb") as dst:
                shutil.copyfileobj(src, dst, length=1024 * 1024)
    for name in actual:
        assert digest(bundle / name) == digest(relocation / name)
    report = {"passed": True, "archive": str(archive), "archive_bytes": archive.stat().st_size,
              "archive_sha256": digest(archive), "relocated": str(relocation),
              "file_count": len(actual), "source_revision": manifest["source_revision"],
              "scope": "File hashes, ZIP CRC and Unicode/space-path extraction only. Runtime launch is verified separately."}
    (evidence / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
