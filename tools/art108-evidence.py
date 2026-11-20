"""Compact evidence index. Raw logs/images remain local; never invent passes."""
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path("E:/GALUMU")
LOGS = ROOT / "docs/development/logs"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


result = {
    "task": "ART-108",
    "baseline": "0ad4f2f4ba3f3c07ce795768ce83c5815cd27365",
    "scope": "Protected source Godot 4.5.1, isolated QA GPU and headless rules. No OS input, human acceptance, hardware audio or new Windows package at this stage.",
    "production_files": {},
    "runs": [],
    "campaign_cases": [],
    "limits": [
        "Distinct cosmetic configurations are not 80 newly painted heads; closed helmets hide faces.",
        "Campaign visual fixture sets preceding progress and a legal shadow-budget loadout. It does not earn 80 sequential clears or perform purchases.",
        "Numerical fit/continuity checks complement, not replace, visual inspection.",
        "Source PNG uniqueness does not prove historical accuracy. History review records 42 readable references and 6 unread source cases.",
        "Perceived motion, readability and sound still need human play feedback; these are not commercial certification.",
    ],
}
for relative in ["game/scripts/core/campaign.gd", "game/scripts/battle.gd", "game/data/history_v051_en_fr.json", "game/tools/battle_sprites_v090.gd"]:
    result["production_files"][relative] = digest(ROOT / relative)

for directory in sorted(LOGS.glob("art108-*")):
    if not directory.is_dir():
        continue
    memory = directory / "memory.log"
    if not memory.exists():
        continue
    content = memory.read_text(encoding="utf-8-sig", errors="replace")
    exits = [line for line in content.splitlines() if line.startswith(("EXIT ", "TIMEOUT", "QA_DESKTOP_CLOSED", "ABORT", "STOP"))]
    row = {"run": directory.name, "memory_sha256": digest(memory), "exit_lines": exits, "finished": any(line.startswith(("EXIT ", "TIMEOUT", "ABORT", "STOP")) for line in exits)}
    peaks = [float(value) for value in re.findall(r"privateMiB=([0-9.]+)", content)]
    if peaks:
        row["private_peak_mib"] = max(peaks)
    engine = directory / "engine.log"
    if engine.exists():
        lines = engine.read_text(encoding="utf-8-sig", errors="replace").splitlines()
        row["engine_issues"] = [line for line in lines if any(key in line for key in ["ERROR:", "WARNING:", "SCRIPT ERROR"])]
        row["parse_results"] = [line for line in lines if "PARSE065_RESULT" in line]
    reports = list(directory.glob("report.json")) + list(directory.glob("screens/report.json"))
    for path in reports:
        data = read(path)
        row.update({"report": path.relative_to(ROOT).as_posix(), "report_sha256": digest(path), "passed": data.get("passed"), "failures": data.get("failures", [])})
        for key in ["unique_faces", "fit_pairs", "combinations", "shields", "families"]:
            if key in data:
                row[key] = data[key]
        for key in ["rows", "records", "trace"]:
            if key in data:
                row[key + "_count"] = len(data[key])
        if directory.name.startswith("art108-campaign"):
            for case in data.get("rows", []):
                result["campaign_cases"].append({"run": directory.name, "level": case["level"], "winner": case["result"]["winner"], "fall_identities_checked": case["fallen_identities_checked"], "fall_frames": case.get("fall_frames", []), "hits": len(case["hits"]), "player_appearance": case["player_appearance"], "opponent_appearance": case["opponent_appearance"]})
    result["runs"].append(row)

formal_after = LOGS / "art108-formal-after01.json"
if formal_after.exists():
    before = read(LOGS / "level107-formal-before02.json")
    after = {item["name"]: item["sha256"] if item["exists"] else "absent" for item in read(formal_after)}
    result["formal_profile_files_unchanged"] = before == after
    result["formal_profile_evidence_sha256"] = digest(formal_after)
    if before != after:
        raise SystemExit("Formal profile mismatch: inspect, do not overwrite")
result["campaign_levels_verified"] = sorted({case["level"] for case in result["campaign_cases"]})
result["campaign_fall_identities_checked"] = sum(case["fall_identities_checked"] for case in result["campaign_cases"])
result["campaign_fall_frames"] = sum(len(case["fall_frames"]) for case in result["campaign_cases"])
result["history_review_sha256"] = digest(ROOT / "docs/development/ART108_HISTORY_REVIEW.md")
output = ROOT / "docs/development/ART108_EVIDENCE.json"
output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("ART108 index:", len(result["runs"]), "runs,", len(result["campaign_levels_verified"]), "campaign levels; unfinished runs explicitly marked")
