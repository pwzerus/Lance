# INC-059: memory exhaustion containment and resource budget

Date: 2026-11-03. Owner: Codex. Baseline: 4b5a3f9, codex/v0.4.

## Incident and diagnosis boundary
Windows Resource-Exhaustion-Detector event 2004 recorded LanceAndLaurel.exe using 40,761,319,424 and 40,331,833,344 bytes on November 3, followed by abnormal reboots. This is abnormal process commitment, not the intended game budget. Exact allocation source is NOT identified. Dynamic horse mesh upload remains an unproven lead; it was not rewritten without evidence.

Short actual OpenGL runs did not reproduce runaway growth. The original v0.4.18 menu and source idle mesh sweep completed 635 rendered poses. A menu/armory/four arena-war scene cycle returned to 27 nodes and 86 resources. Do not describe this as proof that an hours-long or driver-dependent leak is fixed.

## Implemented protections
- Start-MemoryBound.ps1: creates child suspended, assigns Windows Job Object before resuming; aggregate job commitment cap 1 GiB, KILL_ON_JOB_CLOSE. Setup failure terminates the suspended process instead of falling back to unbounded execution.
- Sampling once per second; private commitment above 900 MiB ends the job (exit 125), timeout ends it (124). Timeout zero is for interactive play only. Not a working-set trim and not a global cap on Windows, GPU kernel allocations, Codex or unrelated apps.
- One named mutex prevents concurrent protected game/test instances. Below-normal process priority, 25% total CPU cap, and refusal to launch if less than 4 GiB physical RAM is available.
- Release main scene refuses startup without the protected launcher's environment marker. This is an accidental-launch interlock, not an adversarial security mechanism. Old archived EXEs cannot acquire this protection retroactively.
- Render budget 60 fps, minimized 10 fps. Shared UI Theme/font variation rather than rebuilding it on every page. Fixed font oversampling avoids extra scale-dependent cache variants.

## Resource optimization
- 48 helmet/chest imports capped at 512 pixels. Original PNGs unchanged. Original aggregate RGBA footprint 287.97 MiB -> 45.54 MiB. Texture cache now LRU, maximum 12 entries (live UI references may keep additional visible textures alive).
- Manifest records source dimensions; texture atlas crop is rescaled with the imported dimensions. Initial candidate memory1 revealed that imported logical dimensions change; fixed in memory2. Never distribute memory1.
- Excluded six unused old art plates and pixel_v049 from export; retained source files and old releases.
- PCK 73,656,200 -> 34,280,456 bytes (53.5% smaller). EXE unchanged 96,725,504 bytes; total EXE+PCK 170,381,704 -> 131,005,960 bytes (23.1% smaller).

## Evidence
All tests serial and protected; QA save only, --test-profile. Logs: docs/development/logs/inc059/.
- limit-probe.ps1 / limit-result.txt: VirtualAlloc commitment denied after 896 MiB of chunks plus process overhead, below job cap. No deliberate 40 GB reproduction.
- Single-instance refusal tested during package run: second launcher refused before creating a child.
- draw-baseline.json: 635 actual rendered idle poses; not manual play.
- soak.json: four menu/armory/arena-war cycles before texture reduction, peak about 828 MiB private, final ~680 MiB.
- optimized-soak.json / optimized-memory.txt: ~83 seconds, four cycles, peak 753.2 MiB, final 639.3 MiB. Return node counts all 27; resource counts all 86 after warmup. Small retained report rows account for some script memory growth.
- textures-verified.log / textures.json: all 48 imported textures <=512; scaled regions in bounds; cache <=12 (debug assertions, not release assertions).
- preview.png: actual left/right mounted English tier-six equipment render inspected; crop and fitted coverage preserved. Not exhaustive aesthetic approval of every equipment combination.
- export2.log: independent memory2 export; engine logs include existing root certificate warning and editor-settings save denied by sandbox, neither is a gameplay memory diagnosis.
- package-soak.json / package-memory.txt: final EXE/PCK verification, report completion checked separately.

No OS mouse/keyboard gameplay or human satisfaction claims. Release OS.get_static_memory_usage() is zero; use launcher private-memory samples, not that release counter.

## Remaining work
Root cause of historical 40 GB event remains unresolved. Continue longer bounded soak with resize/minimize/resume and font/mesh/driver A/B profiling; never raise the memory cap merely to pass. Preserve timestamps, job logs and any future failures. Do not claim unlimited-session stability or zero system-freeze risk from these checks. Upstream font-cache issue https://github.com/godotengine/godot/issues/95427 describes a possible class of problems, not a confirmed match; fullscreen issue #114903 likewise is not established here.

Final follow-up: original packaged desktop-observer path ran 90 seconds under the cap, ~592 MiB steady, then timeout killed the Job. Final package soak completed ~82 seconds at 625.9 MiB (package-memory.txt). Final system reserve check refused further startup because available RAM was below 4 GiB; no Godot/Lance process remained. Windows PowerShell 5.1 script execution was denied by its policy, so launchers use this machine's existing Codex PowerShell 7 runtime; no execution policy was changed. Final -File invocation confirmed the reserve refusal before child creation. Portable use requires a compatible PowerShell 7 installation/path. Final 2 GiB runtime reserve branch is implemented but was not deliberately exercised by exhausting system RAM.
