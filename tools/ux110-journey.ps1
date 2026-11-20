param([ValidateRange(1,16)][int]$FirstBatch=2,[ValidateRange(1,16)][int]$LastBatch=16)
$ErrorActionPreference='Stop'
if($LastBatch -lt $FirstBatch){throw 'Invalid ordered segments'}
for($batch=$FirstBatch;$batch -le $LastBatch;$batch++){
    $name='ux110-journey{0:d2}' -f $batch
    $first=($batch-1)*5+1
    $last=$batch*5
    & "$PSScriptRoot/ux110-run.ps1" -Name $name -Script 'test_journey110.gd' -Extra "--profile=E:/GALUMU/docs/development/logs/ux110-journey/qa_journey --first=$first --last=$last"
    $report=Get-Content -LiteralPath "E:/GALUMU/docs/development/logs/$name/screens/report.json" -Raw -Encoding utf8 | ConvertFrom-Json
    if(!$report.passed -or !$report.completed_requested_segment){throw "UI campaign stopped at $name"}
    Write-Output ("UI_JOURNEY completed={0} attempts={1} coins={2} renown={3}" -f $last,$report.rows.Count,$report.final_profile.coins,$report.final_profile.renown)
}
