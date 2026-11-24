$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'dev113-run.ps1'
# Distinct package gates after the c3 boot-contact correction. Normal long
# matches supply contacts; this transition fixture only shortens the waits.
& $runner -Name dev113-c3-result01 -Script test_result099.gd -Target bundle -Extra '--fixture=E:/GALUMU/docs/development/logs/dev113-soak03/screens/report.json'
& $runner -Name dev113-c3-window01 -Script test_window087.gd -Target bundle
& $runner -Name dev113-c3-audio01 -Script test_movement_audio106.gd -Target bundle -Budget parse -Extra '--report-path=E:/GALUMU/docs/development/logs/dev113-c3-audio01/evidence/report.json'
& $runner -Name dev113-c3-mounted01 -Script test_mounted_contact105.gd -Target bundle
& $runner -Name dev113-c3-outfit-eng01 -Script test_art_fall108.gd -Target bundle -Extra '--region=eng --tier=0 --raw-frames'
& $runner -Name dev113-c3-outfit-it01 -Script test_art_fall108.gd -Target bundle -Extra '--region=it --tier=5 --raw-frames'
