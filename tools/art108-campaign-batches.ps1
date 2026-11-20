param([ValidateRange(1,10)][int]$First=6,[ValidateRange(1,10)][int]$Last=10)
$ErrorActionPreference='Stop'
if ($Last -lt $First) { throw 'Invalid batch range' }
$project='E:\GALUMU'
$guard=Join-Path $project 'Start-MemoryBound.ps1'
$engine=Join-Path $project 'tools\godot-4.5.1\Godot_v4.5.1-stable_win64.exe'
for ($batch=$First; $batch -le $Last; $batch++) {
    $run=Join-Path $project ('docs\development\logs\art108-campaign{0:D2}' -f $batch)
    if (Test-Path -LiteralPath $run) { throw "Evidence already exists: $run" }
    New-Item -ItemType Directory -Path $run | Out-Null
    $levels=((($batch-1)*8+1)..($batch*8)) -join ','
    $gameArguments="--path E:/GALUMU/game --audio-driver Dummy --script res://tests/test_scene103.gd --log-file $run/engine.log -- --test-profile --appearance-cycle --fall-captures --folder=$run/screens --audit=E:/GALUMU/docs/development/logs/level107-audit05/report.json --kit=early_light --strategy=forward --levels=$levels"
    Write-Output "ART108 starting batch $batch levels $levels"
    # This wrapper only serializes the existing protected GPU fixture.
    # Each engine receives its own finite 600-second job and isolated desktop.
    & $guard -Executable $engine -Arguments $gameArguments -TimeoutSeconds 600 -IsolatedDesktop -MemoryLog "$run/memory.log" | Out-Null
    $memory=Get-Content -LiteralPath "$run/memory.log" -Raw
    if ($memory -notmatch 'EXIT code=0 ' -or $memory -notmatch 'QA_DESKTOP_CLOSED=True') { throw "Guard did not finish cleanly: $run" }
    $report=Get-Content -LiteralPath "$run/screens/report.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$report.passed -or @($report.rows).Count -ne 8) { throw "Fixture failed: $run" }
    $engineLog=Get-Content -LiteralPath "$run/engine.log" -Raw -Encoding UTF8
    if ($engineLog -match 'SCRIPT ERROR|ERROR:|WARNING:') { throw "Engine diagnostic needs review: $run" }
    $wins=@($report.rows | Where-Object { $_.result.winner -eq 0 }).Count
    $falls=($report.rows | Measure-Object -Property fallen_identities_checked -Sum).Sum
    Write-Output "ART108 completed batch $batch, wins=$wins/8, fallen identities=$falls; no engine diagnostics"
}
