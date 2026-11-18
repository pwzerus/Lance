# Visual Verification Checklist

- Run the project with `godot --path .` (or drive the packaged harness via `scripts/inspect_godot_viewport.py`).
- Check engine output for `SCRIPT ERROR` / `ERROR:` lines.
- Confirm the window/viewport has nonzero display size and renders (not the dummy renderer).
- Capture a screenshot (viewport image via `tools/qa_capture.gd`).
- Sample viewport pixels for nonblank output and color variance.
- Test at desktop, laptop, and mobile viewport sizes (`--mobile`).
- Confirm `Camera3D` framing and content scale/stretch update after resize.
- Confirm UI/HUD text (Control nodes under a `CanvasLayer`) does not overlap or clip.
- Interact for at least one core action and observe visible state change.
- If using snapshots, make dynamic effects deterministic or mask them.
- If HUD/menu layout changed, also use `godot-game-ui-designer/references/checklists/game-ui-quality.md`, `godot-game-ui-designer/references/checklists/hud-readability.md`, and `godot-game-ui-designer/references/checklists/responsive-ui-fit.md`.
- If procedural models/materials changed, also use `godot-aaa-graphics-builder/references/checklists/procedural-model-quality.md`, `godot-aaa-graphics-builder/references/checklists/material-lighting-quality.md`, and `godot-aaa-graphics-builder/references/checklists/performance-safe-visual-detail.md`.
- If the target is premium, AAA, complete, release-ready, or showcase quality, also use `godot-aaa-graphics-builder/references/checklists/aaa-game-quality-gate.md`.
- If screenshots still look basic, also use `godot-aaa-graphics-builder/references/checklists/aaa-visual-scorecard.md`.
- If the game is an endless runner, also use `godot-gameplay-systems/references/checklists/endless-runner-premium-quality.md`.
