# Release Checklist

- `godot --headless --export-release "<Preset>" <output>` passes.
- The exported output runs (run the binary, or serve the Web/HTML5 export and open it).
- `res://` asset loading works under the intended export preset and Web base/host path.
- No local-only files, debug overlays (F3 / `-- --debug`), or test helpers are visible unless intentionally gated behind release feature tags.
- Engine output is clean (no `SCRIPT ERROR` / `ERROR:`) in the release run.
- Desktop and mobile visual checks pass.
- Main interaction works in the exported build.
- Export size and large assets are reviewed.
- License/source notes for third-party assets are present.
- Final report includes commands, screenshots/artifacts, known risks, and deployment notes.
