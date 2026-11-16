"""Recover the immutable comparison fixture; never replace production source."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess

BASELINE = "c27ce93668802be46f548e719f5c73ed9142657c"
SHA256 = "316eb4ca4941a9b3666793a2e641b3a2531573a131af35847ba1c096cfc1c52f"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(repo / "docs" / "development" / "logs")
    git = shutil.which("git") or str(Path.home() / ".cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/mingw64/bin/git.exe")
    data = subprocess.run([git, "-c", "core.commitGraph=false", "show", BASELINE + ":game/scripts/visual/fallen_rider.gd"], cwd=repo, capture_output=True, check=True).stdout
    assert hashlib.sha256(data).hexdigest() == SHA256, "Baseline source hash mismatch"
    fixture = data.decode("utf-8").replace("class_name FallenRider\n", "", 1)
    if output.exists():
        assert output.read_text(encoding="utf-8") == fixture, "Preserve the existing evidence file"
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(fixture, encoding="utf-8")
    print(SHA256, output)

if __name__ == "__main__":
    main()
