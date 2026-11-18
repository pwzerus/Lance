# Godot QA/Release Prompt Templates

Reusable prompt templates packaged with this skill. Use only templates relevant to the current request, and adapt placeholders to the game/project context.

---

# Release Pass Prompt

Use `godot-qa-release` to prepare this Godot game for release.

Release target:
- desktop (Windows/macOS/Linux), Web/HTML5 host, itch.io, Steam, mobile (Android/iOS), or other:

Requirements:
- Run an export-release build with the intended export preset.
- Verify `res://` asset loading and Web base/host assumptions for the exported package.
- Check export size and large assets.
- Run desktop and mobile visual QA.
- Confirm no debug-only overlay (F3 / `-- --debug`) leaks unless intentionally enabled via release feature tags.
- Produce final report with commands, artifacts, screenshots, and residual risks.
