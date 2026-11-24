$ErrorActionPreference='Stop'
$repo113=Split-Path -Parent $PSScriptRoot
$runner=Join-Path $PSScriptRoot 'dev113-run.ps1'
$bundle113='E:/GALUMU/builds/LanceAndLaurel-v0.4.60-c4'
$relocated113='E:/GALUMU/builds/DEV113 0.4.60-c4 中文 空格验包/LanceAndLaurel-v0.4.60-c4'
# Continue after the explicitly preserved old paired-camera fixture failure.
$fixed113=Get-Content "$repo113/docs/development/logs/dev113-c4-cinema02/report.json" -Raw -Encoding utf8 | ConvertFrom-Json
$memory113=Get-Content "$repo113/docs/development/logs/dev113-c4-cinema02/memory.log" -Raw
if(!$fixed113.passed -or $memory113 -notmatch 'EXIT code=0 ' -or $memory113 -notmatch 'QA_DESKTOP_CLOSED=True'){throw 'Camera repair has not passed protected verification.'}
& $runner -Name dev113-c4-motion01 -Script test_motion105.gd -Target bundle -Bundle $bundle113 -Extra '--coats=bay,black,flaxen,grey --kinds=ride,lean,fatigue --expect-animated-grip'
& $runner -Name dev113-c4-gallery01 -Script test_result_gallery110.gd -Target bundle -Bundle $bundle113 -Extra '--compact'
& $runner -Name dev113-c4-save01 -Script test_save_ui087.gd -Target bundle -Bundle $bundle113 -Extra '--compact'
& $runner -Name dev113-c4-guide01 -Script test_guide087.gd -Target bundle -Bundle $bundle113 -Extra '--compact --mouse-only --resume-test'
& $runner -Name dev113-c4-interruption01 -Script test_interruption105.gd -Target bundle -Bundle $bundle113
& $runner -Name dev113-c4-result01 -Script test_result099.gd -Target bundle -Bundle $bundle113 -Extra '--fixture=E:/GALUMU/docs/development/logs/dev113-soak03/screens/report.json'
& $runner -Name dev113-c4-window01 -Script test_window087.gd -Target bundle -Bundle $bundle113
& $runner -Name dev113-c4-journey01 -Script test_journey113.gd -Target bundle -Bundle $bundle113 -Extra '--profile=E:/GALUMU/docs/development/logs/dev113-c4-campaign/qa_journey --first=1 --last=5 --attempts=3'
& "$repo113/launcher/Test-Portable.ps1" -Bundle $relocated113 -EvidenceDirectory "$repo113/docs/development/logs/dev113-portable01"
& "$repo113/launcher/Invoke-Perf088.ps1" -Bundle $relocated113 -Name dev113-outer-c4 -Script test_play087.gd -Seconds 120 -Extra @('--seconds=60','--mode=arena','--kit=starter','--capture-render')
& "$PSScriptRoot/dev113-soak.ps1" -First 1 -Last 8 -Bundle $bundle113 -Prefix dev113-c4-soak
