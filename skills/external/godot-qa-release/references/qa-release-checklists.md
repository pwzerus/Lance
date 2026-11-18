# QA And Release Checklists

Use this before calling a Godot game complete, premium, release-ready, or fixed.

## Run QA Matrix

Minimum meaningful QA:

- Godot and export templates installed or known.
- Script/parse check passes (`godot --headless --import`, then a bounded run surfaces no runtime errors).
- Project runs with `godot --path .` and the window/viewport opens.
- `SCRIPT ERROR` / `ERROR:` lines from stdout/stderr captured.
- Viewport nonblank and visually varied through pixel sampling.
- Desktop active-play screenshot.
- Mobile active-play screenshot when mobile is in scope (`--mobile`).
- Main input path changes game state.
- Objective/progress path works.
- Fail/retry or pause/resume path works when relevant.
- Recent or risky code paths triggered.
- Physics-heavy games: physics engine choice (Godot Physics vs Jolt), fixed timestep (`Engine.physics_ticks_per_second`), body/collider count, collision/`Area3D` trigger path, high-speed tunneling (`continuous_cd`/CCD) check, and restart body cleanup verified.
- HUD text fit, overlap, safe areas, and touch targets checked when UI changed.
- Renderer diagnostics captured when graphics complexity changed (Performance singleton).
- Imported/generated asset paths (`res://...`), file sizes, and runtime load behavior checked when external assets changed.
- Audio unlock (Web gesture), stream load, loop cleanup, bus mute/volume, and main SFX triggers checked when audio changed.

## Interaction QA

Test what a player actually does:

- Start or resume.
- Move/aim/steer/jump/attack/boost as appropriate (InputMap actions).
- Collect or score.
- Avoid or hit a hazard.
- Trigger a state change: combo, wave, checkpoint, damage, shield, fail, win.
- Pause and resume.
- Restart after fail.
- For physics games, verify bodies reset cleanly after restart and no stale bodies (`RigidBody3D`/`CharacterBody3D`/`Area3D`) keep simulating.
- For audio, verify user-gesture unlock (Web export), main SFX triggers, ambience loop start/stop, pause/resume, restart cleanup, and bus mute/volume controls.
- Resize or rotate when responsive/mobile is in scope (content scale / stretch).

Do not rely only on screenshots for gameplay changes.

## Visual QA

For premium/AAA/showcase or "less basic" requests:

- Capture active-play screenshot before and after when possible.
- Use the visual scorecard.
- Check for automatic failures:
  - primitive-dominant active screenshot (raw `BoxMesh`/`PlaneMesh`/CSG blockout)
  - flat plane/box skyline world
  - generic stat-card HUD
  - one repeated obstacle/reward silhouette
  - fog/glow/darkness (Environment) hiding missing geometry
  - no renderer diagnostics
- Confirm UI and VFX (`GPUParticles3D`) do not obscure threats, rewards, player, or next decision.
- Confirm desktop and mobile framing both show the playable path.
- For generated 3D assets, confirm imported GLTF/GLB models have correct scale, orientation, material readability, collision proxies (`CollisionShape3D`), and animation clips (`AnimationPlayer`/`AnimationTree`) in active gameplay.

## Mobile QA

- Touch controls (`TouchScreenButton` / virtual `Control` stick) emit game intents.
- Touch release/cancel/focus-loss cannot leave controls stuck.
- Safe areas respected (`DisplayServer.get_display_safe_area()`).
- Touch targets reachable and separated.
- Background gestures do not steal gameplay input.
- Orientation/resize preserves viewport and HUD (content scale / stretch).
- DPR/performance acceptable; Mobile rendering method considered for the target.
- Desktop input still works unless intentionally removed.
- UI remains readable on narrow screens.

## Performance QA

When draw calls, asset counts, shaders, shadows, or post-processing changed:

- Record Performance singleton metrics: `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_VIDEO_MEM_USED`, and related counters.
- Record FPS/frame time (`Engine.get_frames_per_second()`) if available.
- Record physics engine, timestep, body count, collider count, active `Area3D` sensors, CCD bodies, and known expensive colliders when physics changed.
- Note rendering method (Forward+ / Mobile / Compatibility), shadow, and Environment glow/SSAO/SDFGI settings.
- Check active gameplay, not only idle view.
- Compare before/after if performance work was requested.
- Report any unmeasured risk honestly.

## Release Checks

Before release-ready:

- Export-release build passes (`godot --headless --export-release "<Preset>" <output>`).
- Exported output tested (run the binary, or serve the Web export and open it).
- `export_presets.cfg` export path, resource patterns, and Web base/host assumptions match the target host.
- Debug overlays (the scaffold's F3 / `-- --debug`), diagnostics, verbose logs, and test shortcuts are gated behind release feature tags or removed from player-facing release.
- Export size and large assets reviewed.
- API keys are not present in shipped scripts, checked-in files, exported `.pck`/assets, or any client-visible config.
- `res://` assets load correctly from the exported package under host assumptions.
- Target/feature-tag assumptions documented (debug vs release, renderer, platform).
- Deployment command or exported artifact location reported.
- Residual risks listed.

## Evidence Format

```text
QA result: pass/fail
Commands:
Run target:
Controls tested:
Screenshots/artifacts:
SCRIPT ERROR/ERROR lines:
Viewport pixel check:
Desktop/mobile viewports:
Renderer/performance diagnostics:
Physics diagnostics:
External asset evidence:
Audio evidence:
Issues found/fixed:
Residual risks:
```

## Bug Report Format

```text
Title:
Severity:
Reproduction steps:
Expected:
Actual:
Platform/viewport/device:
SCRIPT ERROR/ERROR lines:
Screenshot/artifact:
Likely owner:
Suggested fix:
```

## Common Release Failures

- Testing an editor/`godot --path .` run but shipping an untested export-release build.
- Export preset resource patterns or Web host assumptions break asset loading.
- Debug overlay (F3 / `-- --debug`) visible to players in release.
- Mobile UI passes screenshot but touch controls do not work.
- Viewport is nonblank but the wrong scene/main scene is running.
- Physics gameplay looks right visually but collision proxies, `Area3D` sensors, or restart cleanup were not tested.
- Screenshots are title/idle views instead of active play.
- Premium claim has no visual scorecard or Performance-singleton diagnostics.
- 3D/image/audio generation API key or generated temporary URLs accidentally exposed in shipped scripts or assets.
