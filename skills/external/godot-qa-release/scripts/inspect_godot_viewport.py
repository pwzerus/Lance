#!/usr/bin/env python3
"""Run a Godot project's QA capture harness and report viewport evidence.

Wraps the packaged ``tools/qa_capture.gd`` autoload: launches the project with
``-- --qa``, captures the PNG + nonblank analysis it emits, scrapes engine output
for script/runtime errors, and exits non-zero on a blank viewport or any error.

It is the Godot equivalent of a headless screenshot/console check. PNG capture needs
a real GPU/display; a pure ``--headless`` run uses Godot's dummy renderer and will
report a blank viewport.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


REPORT_RE = re.compile(r"__QA_REPORT__(?P<json>.*?)__END_QA_REPORT__", re.DOTALL)
ERROR_RE = re.compile(r"(SCRIPT ERROR|Parse Error|ERROR:|USER ERROR)")
MACOS_APP = "/Applications/Godot.app/Contents/MacOS/Godot"


def find_godot(explicit: str | None) -> str:
    candidates = [
        explicit,
        os.environ.get("GODOT"),
        shutil.which("godot"),
        shutil.which("godot4"),
        MACOS_APP if Path(MACOS_APP).exists() else None,
    ]
    for candidate in candidates:
        if candidate:
            return candidate
    raise SystemExit("Godot binary not found. Pass --godot PATH or set $GODOT.")


def scrape_errors(output: str) -> list[str]:
    errors: list[str] = []
    for line in output.splitlines():
        if ERROR_RE.search(line) and "WARNING" not in line:
            errors.append(line.strip())
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Capture and verify a Godot project's viewport.")
    parser.add_argument("--project", default=".", help="Path to the Godot project (contains project.godot).")
    parser.add_argument("--out", default="artifacts/godot-qa", help="Output directory for screenshots + report.")
    parser.add_argument("--godot", help="Path to the Godot binary (else $GODOT / PATH / macOS app).")
    parser.add_argument("--mobile", action="store_true", help="Capture at a mobile viewport size.")
    parser.add_argument("--warmup", type=int, default=60, help="Frames to render before capturing.")
    parser.add_argument("--headless", action="store_true", help="Force --headless (dummy renderer; blank capture).")
    parser.add_argument("--timeout", type=int, default=90, help="Seconds before aborting the run.")
    args = parser.parse_args(argv)

    godot = find_godot(args.godot)
    project = Path(args.project).resolve()
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    mode = "mobile" if args.mobile else "desktop"

    command = [godot, "--path", str(project)]
    if args.headless:
        command.append("--headless")
    command += ["--", "--qa", "--out", str(out_dir), "--warmup", str(args.warmup)]
    if args.mobile:
        command.append("--mobile")

    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=args.timeout,
        )
    except subprocess.TimeoutExpired:
        print(f"Godot run timed out after {args.timeout}s", file=sys.stderr)
        return 1

    output = completed.stdout + "\n" + completed.stderr
    errors = scrape_errors(output)

    match = REPORT_RE.search(output)
    capture = None
    if match:
        try:
            capture = json.loads(match.group("json"))
        except json.JSONDecodeError:
            capture = None

    report = {
        "mode": mode,
        "command": command,
        "exit_code": completed.returncode,
        "capture": capture,
        "errors": errors,
    }
    (out_dir / f"{mode}.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))

    ok = bool(capture) and capture.get("ok") and not errors and completed.returncode == 0
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
