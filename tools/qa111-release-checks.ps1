param([string]$Bundle='E:/GALUMU/builds/LanceAndLaurel-v0.4.59-c1')
$ErrorActionPreference='Stop'
# Run only after the earned campaign's protected process has fully exited.
# Each helper refuses an existing evidence directory and checks process cleanup.
$runner=Join-Path $PSScriptRoot 'qa111-run.ps1'
& $runner -Name qa111-parse02 -Script test_parse065.gd -Budget parse -Target source
& $runner -Name qa111-performance01 -Script profile_result099.gd -Bundle $Bundle -Extra '--seconds=240 --mode=war --kit=heavy --difficulty=2 --capture-render --trace099'
& $runner -Name qa111-transitions01 -Script test_result099.gd -Bundle $Bundle -Extra '--fixture=E:/GALUMU/docs/development/logs/qa111-performance01/screens/report.json'
& $runner -Name qa111-motion01 -Script test_motion105.gd -Bundle $Bundle -Extra '--coats=bay,black,flaxen,grey --kinds=ride,lean,fatigue --expect-animated-grip'
& $runner -Name qa111-mounted-contact01 -Script test_mounted_contact105.gd -Bundle $Bundle
& $runner -Name qa111-fall-eng01 -Script test_art_fall108.gd -Bundle $Bundle -Extra '--region=eng --tier=0 --raw-frames'
& $runner -Name qa111-fall-fr01 -Script test_art_fall108.gd -Bundle $Bundle -Extra '--region=fr --tier=1'
& $runner -Name qa111-fall-de01 -Script test_art_fall108.gd -Bundle $Bundle -Extra '--region=de --tier=3'
& $runner -Name qa111-fall-it01 -Script test_art_fall108.gd -Bundle $Bundle -Extra '--region=it --tier=5 --raw-frames'
& $runner -Name qa111-ko-camera01 -Script test_scene104.gd -Bundle $Bundle -Extra '--part=battle --report=E:/GALUMU/docs/development/logs/qa111-ko-camera01/screens/report.json --captures=E:/GALUMU/docs/development/logs/qa111-ko-camera01/screens'
& $runner -Name qa111-filters01 -Script test_filters110.gd -Bundle $Bundle
& $runner -Name qa111-gallery01 -Script test_result_gallery110.gd -Bundle $Bundle -Extra '--compact'
& $runner -Name qa111-save-ui01 -Script test_save_ui087.gd -Bundle $Bundle -Extra '--compact'
& $runner -Name qa111-guide01 -Script test_guide087.gd -Bundle $Bundle -Extra '--compact --resume-test'
& $runner -Name qa111-guide-mouse01 -Script test_guide087.gd -Bundle $Bundle -Extra '--mouse-only --compact'
& $runner -Name qa111-interruption01 -Script test_interruption105.gd -Bundle $Bundle
& $runner -Name qa111-window01 -Script test_window087.gd -Bundle $Bundle
& $runner -Name qa111-audio01 -Script test_movement_audio106.gd -Budget parse -Bundle $Bundle -Extra '--report-path=E:/GALUMU/docs/development/logs/qa111-audio01/evidence/report.json'
Write-Output 'QA111 sequential release checks completed; inspect images and scope before acceptance.'
