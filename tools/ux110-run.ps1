param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$Script,[ValidateSet('gpu','parse','rules')][string]$Budget='gpu',[string]$Extra='')
$ErrorActionPreference='Stop'
if($Name -notmatch '^ux110-[a-z0-9-]+$'){throw 'Use a new UX110 evidence name'}
$project='E:\GALUMU'
$run=Join-Path $project ('docs\development\logs\'+$Name)
if(Test-Path -LiteralPath $run){throw "Preserve existing evidence: $run"}
New-Item -ItemType Directory -Path $run | Out-Null
$part=if($Budget -eq 'gpu'){'screens'}else{'evidence'}
$headless=if($Budget -eq 'gpu'){''}else{'--headless'}
$params=@{Executable="$project/tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe";Arguments="$headless --path E:/GALUMU/game --audio-driver Dummy --script res://tests/$Script --log-file $run/engine.log -- --test-profile --folder=$run/$part --report=$run/$part $Extra";TimeoutSeconds=600;MemoryLog="$run/memory.log"}
if($Budget -eq 'gpu'){$params.IsolatedDesktop=$true}elseif($Budget -eq 'parse'){$params.HeadlessDiagnostics=$true}else{$params.GeometryDiagnostics=$true}
& "$project/Start-MemoryBound.ps1" @params | Out-Null
$memory=Get-Content -LiteralPath "$run/memory.log" -Raw
if($memory -notmatch 'EXIT code=0 ' -or ($Budget -eq 'gpu' -and $memory -notmatch 'QA_DESKTOP_CLOSED=True')){throw "Incomplete protected run: $run"}
$log=Get-Content -LiteralPath "$run/engine.log" -Raw -Encoding utf8
$unexpected=$log
if($Script -eq 'test_save_ui087.gd'){
    $expected="ERROR: Failed to open '$run/$part/blocked_backup'."
    if([regex]::Matches($log,[regex]::Escape($expected)).Count -ne 2){throw 'Expected two deliberate backup-copy faults; inspect actual log'}
    $unexpected=$unexpected.Replace($expected,'EXPECTED STORAGE FAULT')
}
if($unexpected -match 'SCRIPT ERROR|ERROR:'){throw "Review engine failure: $run"}
$reportPath=Join-Path $run "$part/report.json"
if(Test-Path -LiteralPath $reportPath){
    $report=Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json
    if($report.PSObject.Properties.Name -contains 'passed' -and !$report.passed){throw "Assertions failed: $run"}
    if($report.PSObject.Properties.Name -contains 'completed_requested_segment' -and !$report.completed_requested_segment){throw "Actual campaign segment incomplete: $run"}
}
if($Budget -eq 'parse' -and $log -notmatch 'PARSE065_RESULT failed=0'){throw 'Compile gate incomplete'}
Write-Output "Verified protected engine exit: $Name"
