param([string]$Bundle='E:/GALUMU/builds/LanceAndLaurel-v0.4.60-c3')
$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'dev113-run.ps1'
# Every invocation is serialized and bounded. Tests load the exported res://,
# not the source tree; input stays on the private desktop and QA save paths.
& $runner -Name dev113-c3-condition01 -Script test_condition113.gd -Budget rules -Target bundle -Bundle $Bundle
& $runner -Name dev113-c3-head01 -Script test_head098.gd -Budget rules -Target bundle -Bundle $Bundle -Extra '--report=E:/GALUMU/docs/development/logs/dev113-c3-head01/report.json'
& $runner -Name dev113-c3-shield01 -Script test_shield113.gd -Budget rules -Target bundle -Bundle $Bundle
& $runner -Name dev113-c3-hud01 -Script test_hud113.gd -Target bundle -Bundle $Bundle
& $runner -Name dev113-c3-terminal01 -Script test_terminal113.gd -Target bundle -Bundle $Bundle -Extra '--part=battle --report=E:/GALUMU/docs/development/logs/dev113-c3-terminal01/report.json --captures=E:/GALUMU/docs/development/logs/dev113-c3-terminal01/captures'
& $runner -Name dev113-c3-articulation01 -Script test_articulation113.gd -Target bundle -Bundle $Bundle
& $runner -Name dev113-c3-boot01 -Script test_boot113.gd -Target bundle -Bundle $Bundle
& $runner -Name dev113-c3-shield-visual01 -Script test_shield_visual113.gd -Target bundle -Bundle $Bundle -Extra '--part=battle --report=E:/GALUMU/docs/development/logs/dev113-c3-shield-visual01/report.json --captures=E:/GALUMU/docs/development/logs/dev113-c3-shield-visual01/captures'
& $runner -Name dev113-c3-cinema01 -Script test_cinema099.gd -Target bundle -Bundle $Bundle -Extra '--part=battle --report=E:/GALUMU/docs/development/logs/dev113-c3-cinema01/report.json --captures=E:/GALUMU/docs/development/logs/dev113-c3-cinema01/captures'
& $runner -Name dev113-c3-motion01 -Script test_motion105.gd -Target bundle -Bundle $Bundle -Extra '--coats=bay,black,flaxen,grey --kinds=ride,lean,fatigue --expect-animated-grip'
& $runner -Name dev113-c3-gallery01 -Script test_result_gallery110.gd -Target bundle -Bundle $Bundle -Extra '--compact'
& $runner -Name dev113-c3-save01 -Script test_save_ui087.gd -Target bundle -Bundle $Bundle -Extra '--compact'
& $runner -Name dev113-c3-guide01 -Script test_guide087.gd -Target bundle -Bundle $Bundle -Extra '--compact --mouse-only --resume-test'
& $runner -Name dev113-c3-interruption01 -Script test_interruption105.gd -Target bundle -Bundle $Bundle
Write-Output 'Candidate regression finished. Inspect captured pixels and reports before acceptance.'
