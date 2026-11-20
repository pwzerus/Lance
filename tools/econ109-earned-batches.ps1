param([ValidateRange(2,16)][int]$First=2,[ValidateRange(2,16)][int]$Last=16)
$ErrorActionPreference='Stop'
if($Last -lt $First){throw 'Invalid segment range'}
$project='E:\GALUMU'
$engine=Join-Path $project 'tools\godot-4.5.1\Godot_v4.5.1-stable_win64.exe'
$guard=Join-Path $project 'Start-MemoryBound.ps1'
for($batch=$First;$batch -le $Last;$batch++){
    $run=Join-Path $project ('docs\development\logs\econ109-earned{0:D2}' -f $batch)
    if(Test-Path -LiteralPath $run){throw "Evidence already exists: $run"}
    New-Item -ItemType Directory -Path $run | Out-Null
    $firstLevel=($batch-1)*5+1
    $lastLevel=$batch*5
    $gameArguments="--path E:/GALUMU/game --audio-driver Dummy --script res://tests/test_earned109.gd --log-file $run/engine.log -- --test-profile --folder=$run/screens --profile=E:/GALUMU/docs/development/logs/econ109-earned/qa_journey --first=$firstLevel --last=$lastLevel"
    Write-Output "ECON109 natural progression $firstLevel to $lastLevel"
    & $guard -Executable $engine -Arguments $gameArguments -TimeoutSeconds 600 -IsolatedDesktop -MemoryLog "$run/memory.log" | Out-Null
    $memory=Get-Content -LiteralPath "$run/memory.log" -Raw
    if($memory -notmatch 'EXIT code=0 ' -or $memory -notmatch 'QA_DESKTOP_CLOSED=True'){throw "Protected run incomplete: $run"}
    $log=Get-Content -LiteralPath "$run/engine.log" -Raw -Encoding utf8
    if($log -match 'SCRIPT ERROR|ERROR:|WARNING:'){throw "Engine diagnostic needs review: $run"}
    $report=Get-Content -LiteralPath "$run/screens/report.json" -Raw -Encoding utf8 | ConvertFrom-Json
    if(!$report.passed -or !$report.completed_requested_segment){throw "Earned segment incomplete; do not grant unlocks: $run"}
    Write-Output "ECON109 saved through level $lastLevel; matches=$($report.final_profile.matches), coins=$($report.final_profile.coins)"
}
