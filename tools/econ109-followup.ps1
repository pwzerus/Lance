param([ValidateSet('rules','recovery','heavy','heavy11','replay')][string]$Group='rules')
$ErrorActionPreference='Stop'
$project='E:\GALUMU'
$engine=Join-Path $project 'tools\godot-4.5.1\Godot_v4.5.1-stable_win64.exe'
function Invoke-EconomyCheck([string]$Name,[string]$Script,[string]$Budget,[string]$Extra='') {
    $run=Join-Path $project ('docs\development\logs\'+$Name)
    if(Test-Path -LiteralPath $run){throw "Preserve existing evidence: $run"}
    New-Item -ItemType Directory -Path $run | Out-Null
    $screen=if($Budget -eq 'gpu'){'screens'}else{'evidence'}
    $headless=if($Budget -eq 'gpu'){''}else{'--headless'}
    $params=@{Executable=$engine; Arguments="$headless --path E:/GALUMU/game --audio-driver Dummy --script res://tests/$Script --log-file $run/engine.log -- --test-profile --folder=$run/$screen $Extra"; TimeoutSeconds=600; MemoryLog="$run/memory.log"}
    if($Budget -eq 'gpu'){$params.IsolatedDesktop=$true}
    elseif($Budget -eq 'parse'){$params.HeadlessDiagnostics=$true}
    else{$params.GeometryDiagnostics=$true}
    & (Join-Path $project 'Start-MemoryBound.ps1') @params | Out-Null
    $memory=Get-Content -LiteralPath "$run/memory.log" -Raw
    if($memory -notmatch 'EXIT code=0 ' -or ($Budget -eq 'gpu' -and $memory -notmatch 'QA_DESKTOP_CLOSED=True')){throw "Incomplete protected run: $run"}
    $log=Get-Content -LiteralPath "$run/engine.log" -Raw -Encoding utf8
    $unexpected=$log
    if($Script -eq 'test_economy_fault109.gd'){
        # Three intentional blocked-backup writes exercise reward, purchase
        # rollback and protection against discarding pending progress. Godot
        # logs the native copy failure as ERROR as well as our SAVE_IO warning.
        # Exempt only this exact fixture path and exact occurrence count.
        $expected="ERROR: Failed to open '$run/evidence/blocked_backup'."
        if([regex]::Matches($log,[regex]::Escape($expected)).Count -ne 3){throw 'Expected fault signature changed; inspect manually'}
        $unexpected=$unexpected.Replace($expected,'EXPECTED STORAGE FAULT')
    }
    if($unexpected -match 'SCRIPT ERROR|ERROR:'){throw "Review engine failure: $run"}
    if($Budget -eq 'parse'){
        if($log -notmatch 'PARSE065_RESULT failed=0'){throw 'Parse result missing'}
    } else {
        $report=Get-Content -LiteralPath "$run/$screen/report.json" -Raw -Encoding utf8 | ConvertFrom-Json
        if(!$report.passed){throw "Assertions failed: $run"}
        if($report.PSObject.Properties.Name -contains 'completed_requested_segment'){
            if(!$report.completed_requested_segment){throw "Actual growth incomplete: $run"}
        }
    }
    Write-Output "Verified $Name"
}
if($Group -eq 'rules'){
    Invoke-EconomyCheck 'econ109-parse02' 'test_parse065.gd' 'parse'
    Invoke-EconomyCheck 'econ109-shop01' 'test_shop109.gd' 'rules'
    Invoke-EconomyCheck 'econ109-fault03' 'test_economy_fault109.gd' 'rules'
}
if($Group -eq 'recovery'){Invoke-EconomyCheck 'econ109-recovery01' 'test_recovery_play109.gd' 'gpu'}
if($Group -eq 'heavy'){Invoke-EconomyCheck 'econ109-heavy01' 'test_earned109.gd' 'gpu' '--heavy --profile=E:/GALUMU/docs/development/logs/econ109-heavy/qa_journey --first=6 --last=10'}
if($Group -eq 'heavy11'){Invoke-EconomyCheck 'econ109-heavy02' 'test_earned109.gd' 'gpu' '--heavy --profile=E:/GALUMU/docs/development/logs/econ109-heavy/qa_journey --first=11 --last=15'}
if($Group -eq 'replay'){
    foreach($case in @(@{Name='econ109-replay01';Level=2;Coins=33},@{Name='econ109-replay02';Level=80;Coins=342})){
        Invoke-EconomyCheck $case.Name 'test_earned109.gd' 'gpu' "--profile=E:/GALUMU/docs/development/logs/econ109-replay/qa_journey --first=$($case.Level) --last=$($case.Level)"
        $report=Get-Content -LiteralPath "$project/docs/development/logs/$($case.Name)/screens/report.json" -Raw -Encoding utf8 | ConvertFrom-Json
        $wins=@($report.rows | Where-Object {$_.result.winner -eq 0})
        if($wins.Count -ne 1 -or $wins[0].reward.first_clear -or $wins[0].reward.coins -ne $case.Coins -or $wins[0].reward.renown -ne 0){throw "Replay reward mismatch: $($case.Name)"}
        if($report.final_profile.campaign_cleared.Count -ne 80 -or $report.final_profile.renown -ne $report.initial_profile.renown -or $report.final_profile.coins -ne ($report.initial_profile.coins+$case.Coins)){throw 'Replay changed first-clear progression or paid twice'}
        Write-Output "Real replay level $($case.Level) paid $($case.Coins) coins and no renown"
    }
}
