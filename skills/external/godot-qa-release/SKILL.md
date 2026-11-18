---
name: godot-qa-release
description: "Verify and release Godot games. Combines playtest QA, mobile/responsive checks, export builds, export verification, export presets and feature tags, debug overlay gating, export size/asset review, screenshots, packaged viewport-pixel inspection, SCRIPT ERROR/ERROR scraping, and release risk reports."
---

# Godot QA Release

## Godot Reference Links

Targets **Godot 4.6.x** (latest stable 4.6.3, June 2026). These links use `/en/stable/`, so they always resolve to the current stable docs — fetch them for up-to-date export and command-line details rather than relying on memory.

- Latest stable docs: https://docs.godotengine.org/en/stable/
- Class reference: https://docs.godotengine.org/en/stable/classes/index.html
- Exporting projects: https://docs.godotengine.org/en/stable/tutorials/export/index.html
- Command line (headless, import, export): https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Exporting for the Web: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- Feature tags (debug vs release gating): https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html

## Purpose

Prove the game works as a player encounters it, then prepare a shippable Godot export with known risks.

## QA Workflow

Load `references/qa-release-checklists.md` as the first action before broad QA, mobile verification, bug reporting, export verification, host base-path checks, or release preparation. Track it in a reference ledger with yes/no, path, and failure reason. Do not mark QA/release complete while this reference is skipped for QA or release work.

Load `references/checklists/visual-verification.md` for screenshot/viewport verification, `references/checklists/playtest-qa.md` for player-loop QA, and `references/checklists/release.md` for export/release checks. Load `references/prompt-templates.md` only when the user asks for reusable QA/release prompts or a task template.

1. Confirm Godot and export templates are installed if needed.
2. Run a script/parse check: `godot --headless --import` then a bounded run (`--quit-after N`) to surface runtime errors.
3. Run the project: `godot --path .`.
4. Capture the rendered window/viewport target (desktop and `--mobile`).
5. Scrape `SCRIPT ERROR` / `ERROR:` lines from stdout/stderr.
6. Verify nonblank viewport pixels via the packaged inspector.
7. Capture desktop and mobile screenshots.
8. Trigger main input, objective progression, fail/retry, and recent risky paths.
9. Check HUD text fit, safe areas, touch targets, content-scale/responsive layout.
10. If audio changed, verify user-gesture unlock (Web), SFX triggers, ambience loop start/stop, pause/restart cleanup, bus mute/volume behavior, and stream load errors.
11. Record artifacts and issues.

## Packaged Viewport Inspector

Use the bundled inspector to drive the scaffold's QA harness when the target project includes `tools/qa_capture.gd` (generated projects do):

```bash
python3 <this-skill-dir>/scripts/inspect_godot_viewport.py --project . --out artifacts/qa
```

For mobile viewport capture, add `--mobile`. The wrapper launches the project with `-- --qa`, drives `tools/qa_capture.gd` (warmup → viewport screenshot → nonblank-pixel analysis → JSON report → exit code), scrapes `SCRIPT ERROR` / `ERROR:` from engine output, and exits non-zero on a blank viewport or any error. PNG capture needs a real GPU/display; a pure `--headless` run uses the dummy renderer and reports a blank viewport.

You can also drive the harness directly without the wrapper:

```bash
godot --path . -- --qa --out "$PWD/artifacts/qa" --warmup 60 [--mobile]
```

Generated games from the packaged scaffold include `tools/qa_capture.gd` and the `QaCapture` autoload that activates on the `--qa` flag.

## Release Workflow

1. Inspect `project.godot`, `export_presets.cfg`, export paths, and `res://` asset references.
2. Gate debug overlays/logging/test helpers (the scaffold's F3 / `-- --debug`).
3. Run an export-release build: `godot --headless --export-release "<Preset>" <output>` (Web/HTML5 preset for browser targets).
4. Verify the exported output desktop/mobile (run the binary, or serve the Web export and open it).
5. Review export size and large assets.
6. Document deploy command, host assumptions, feature-tag/renderer choices, and residual risks.

## Final Response

Lead with pass/fail. Include the reference ledger, QA matrix/checklist result, commands, run target, controls, screenshots/artifacts, issues found/fixed, deployment notes, and risks.
