# Playtest QA Checklist

- Start from a clean load (main scene).
- Play through the main loop for at least 2 minutes.
- Verify controls (InputMap actions), camera (`Camera3D` rig), objective feedback, failure/retry, and progression.
- Try rapid input changes and edge movement against arena boundaries.
- Trigger collisions from multiple angles.
- Pause, restart, resize, and refocus the window if supported.
- Check audio unlock and bus volume behavior after the first gesture (Web export requires a gesture).
- Watch for unreadable moments, camera occlusion, jitter, and missed feedback.
- Capture screenshots for desktop and mobile.
- Record bugs as reproduction steps with expected and actual behavior.
