$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'dev113-run.ps1'
$repo113=Split-Path -Parent $PSScriptRoot
$bundle113='E:/GALUMU/builds/LanceAndLaurel-v0.4.60-c4'
$relocated113='E:/GALUMU/builds/DEV113 0.4.60-c4 中文 空格验包/LanceAndLaurel-v0.4.60-c4'
# Preserve normal-life consciousness-loss coverage in the real package.
& $runner -Name dev113-c4-incapacity01 -Script test_incapacity113.gd -Target bundle -Bundle $bundle113 -Extra '--part=battle --report=E:/GALUMU/docs/development/logs/dev113-c4-incapacity01/report.json --captures=E:/GALUMU/docs/development/logs/dev113-c4-incapacity01/captures'
& $runner -Name dev113-c4-incapacity02 -Script test_incapacity113.gd -Target bundle -Bundle $bundle113 -Extra '--part=battle --report=E:/GALUMU/docs/development/logs/dev113-c4-incapacity02/report.json --captures=none'
& "$PSScriptRoot/dev113-c4-checks.ps1" -Bundle $bundle113
& $runner -Name dev113-c4-result01 -Script test_result099.gd -Target bundle -Bundle $bundle113 -Extra '--fixture=E:/GALUMU/docs/development/logs/dev113-soak03/screens/report.json'
& $runner -Name dev113-c4-window01 -Script test_window087.gd -Target bundle -Bundle $bundle113
& $runner -Name dev113-c4-journey01 -Script test_journey113.gd -Target bundle -Bundle $bundle113 -Extra '--profile=E:/GALUMU/docs/development/logs/dev113-c4-campaign/qa_journey --first=1 --last=5 --attempts=3'
# These launcher probes use the same compiled guard and private desktop.
& "$repo113/launcher/Test-Portable.ps1" -Bundle $relocated113 -EvidenceDirectory "$repo113/docs/development/logs/dev113-portable01"
& "$repo113/launcher/Invoke-Perf088.ps1" -Bundle $relocated113 -Name dev113-outer-c4 -Script test_play087.gd -Seconds 120 -Extra @('--seconds=60','--mode=arena','--kit=starter','--capture-render')
# Keep all eight sustained configurations on the final candidate. The c3
# heavy baseline remains separately preserved and is not double-counted.
& "$PSScriptRoot/dev113-soak.ps1" -First 1 -Last 8 -Bundle $bundle113 -Prefix dev113-c4-soak
