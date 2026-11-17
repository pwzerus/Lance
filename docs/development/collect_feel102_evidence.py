"""Summarise protected FEEL-102 reports without treating simulation as play."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "docs/development/logs"
REPORTS = {
    "pressure": "feel102-pressure04.json",
    "contact_mirror": "feel102-contact04.json",
    "controls": "feel102-test_controls098-02.json",
    "reaction": "feel102-test_reaction075-02.json",
    "audio": "feel102-audio04.json",
    "timing": "feel102-timing04.json",
    "lessons": "feel102-balance02.json",
    "beginner": "feel102-beginner01.json",
    "tactics": "feel102-tactics01.json",
    "tactics_old_ai": "feel102-tactics-old.json",
    "source_render": "feel102-after03/report.json",
    "source_lessons": "feel102-lessonscene01/report.json",
    "package_pressure": "feel102-package-pressure.json",
    "package_render": "feel102-package-render/report.json",
    "package_beginner": "feel102-package-beginner/report.json",
    "package_lessons": "feel102-package-lessons/report.json",
    "package_play": "feel102-package-play/report.json",
}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

result = {"base": "8f0e9a0f1077bd248f380e3613d56f109c196229", "version": "0.4.54-c1",
          "verification": "Protected isolated QA; GPU where explicitly named, no OS input or human-play acceptance.",
          "reports": {}, "memory": {}}
for label, name in REPORTS.items():
    path = LOG / name
    if not path.exists():
        result["reports"][label] = {"not_run": True}
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    entry = {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
             "sha256": digest(path), "passed": data.get("passed"),
             "failures": data.get("failures", []), "scope": data.get("scope", "See review")}
    if "levels" in data:
        entry["levels"] = {n: v["summary"] for n, v in data["levels"].items()}
    if "tactics" in label:
        entry["matches"] = [{k: r[k] for k in ["level", "strategy", "side", "ended", "winner"]} for r in data["rows"]]
    if "render" in label:
        entry["cases"] = [{k: r[k] for k in ["attacker", "feedback_kind", "contact_max_head_response_px", "max_shield_compression"]} for r in data["cases"]]
    if label.endswith("lessons"):
        entry["rows"] = data.get("rows")
    if label == "pressure":
        entry["rows"] = data["rows"]
    if label == "package_play":
        entry["metrics"] = {k: v for k, v in data.items() if k not in ["rows", "matches", "samples", "failures"]}
        entry["completed_matches"] = len(data.get("matches", []))
        entry["resource_endpoints"] = [data.get("samples", [])[i] for i in [0, -1]] if data.get("samples") else []
    if label == "package_beginner":
        entry["results"] = [{k: row[k] for k in ["level", "winner", "reward"]} for row in data["rows"]]
    result["reports"][label] = entry
for path in sorted(LOG.glob("feel102-*-memory.log")):
    text = path.read_text(encoding="utf-8-sig")
    samples = [float(n) for n in re.findall(r"privateMiB=([\d.]+)", text)]
    result["memory"][path.name] = {"sampled_peak_mib": max(samples, default=0),
                                   "exit": re.findall(r"(?:EXIT|STOP|GUARD|TIMEOUT).*", text)[-1:]}
package = ROOT / "builds/LanceAndLaurel-v0.4.54-c1"
if (package / "build-manifest.json").exists():
    result["package"] = json.loads((package / "build-manifest.json").read_text(encoding="utf-8-sig"))
    pck = package / "runtime/LanceAndLaurel.pck"
    result["pck"] = {"bytes": pck.stat().st_size, "sha256": digest(pck)}
(ROOT / "docs/development/FEEL102_EVIDENCE.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print("Summarised", len(result["reports"]), "reports; missing:", [n for n,v in result["reports"].items() if v.get("not_run")])
