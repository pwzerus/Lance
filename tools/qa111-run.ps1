param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$Script,[ValidateSet('gpu','parse','rules')][string]$Budget='gpu',[ValidateSet('source','bundle')][string]$Target='bundle',[string]$Bundle='E:/GALUMU/builds/LanceAndLaurel-v0.4.59-c1',[string]$Extra='')
$ErrorActionPreference='Stop'
if($Name -notmatch '^qa111-[a-z0-9-]+$'){throw 'Use a new QA111 evidence name'}
$project='E:/GALUMU';$run=Join-Path $project ('docs/development/logs/'+$Name)
if(Test-Path -LiteralPath $run){throw "Preserve existing evidence: $run"}
New-Item -ItemType Directory -Path $run | Out-Null
$part=if($Budget -eq 'gpu'){'screens'}else{'evidence'}
$headless=if($Budget -eq 'gpu'){''}else{'--headless'}
if($Target -eq 'source'){
 $exe="$project/tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe";$mount="--path $project/game";$driver="res://tests/$Script";$packHash=$null;$revision=$null
}else{
 $exe="$Bundle/runtime/LanceAndLaurel.exe";$pack="$Bundle/runtime/LanceAndLaurel.pck"
 $mount="--path `"$Bundle/runtime`" --main-pack `"$pack`"";$driver="$project/game/tests/$Script"
 $packHash=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash
 $revision=(Get-Content -LiteralPath "$Bundle/build-manifest.json" -Raw -Encoding utf8 | ConvertFrom-Json).source_revision
}
$meta=[ordered]@{target=$Target;executable=$exe;pck_sha256=$packHash;source_revision=$revision;external_test=$driver;budget=$Budget;extra=$Extra;scope='Single protected process. GPU uses isolated desktop; engine/viewport input only, never OS input. External tests load res:// from the actual PCK for bundle targets.'}
$chain=@();$testPath=Join-Path "$project/game/tests" $Script
for($depth=0;$depth -lt 12 -and (Test-Path -LiteralPath $testPath);$depth++){
 $chain+=@{path=$testPath;sha256=(Get-FileHash -LiteralPath $testPath -Algorithm SHA256).Hash}
 $extends=[regex]::Match((Get-Content -LiteralPath $testPath -Raw),'(?m)^extends "([^"\r\n]+)"')
 if(!$extends.Success -or $extends.Groups[1].Value.StartsWith('res://')){break}
 $testPath=Join-Path (Split-Path -Parent $testPath) $extends.Groups[1].Value
}
$meta.external_driver_chain=$chain
[IO.File]::WriteAllText("$run/target.json",($meta | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$params=@{Executable=$exe;Arguments="$headless $mount --audio-driver Dummy --script `"$driver`" --log-file `"$run/engine.log`" -- --test-profile --folder=$run/$part --report=$run/$part $Extra";TimeoutSeconds=600;MemoryLog="$run/memory.log"}
if($Budget -eq 'gpu'){$params.IsolatedDesktop=$true}elseif($Budget -eq 'parse'){$params.HeadlessDiagnostics=$true}else{$params.GeometryDiagnostics=$true}
& "$project/Start-MemoryBound.ps1" @params | Out-Null
$memory=Get-Content -LiteralPath "$run/memory.log" -Raw
if($memory -notmatch 'EXIT code=0 ' -or ($Budget -eq 'gpu' -and $memory -notmatch 'QA_DESKTOP_CLOSED=True')){throw "Incomplete protected run: $run"}
$log=Get-Content -LiteralPath "$run/engine.log" -Raw -Encoding utf8;$unexpected=$log
if($Script -eq 'test_save_ui087.gd'){
 $expected="ERROR: Failed to open '$run/$part/blocked_backup'."
 if([regex]::Matches($log,[regex]::Escape($expected)).Count -ne 2){throw 'Expected two deliberate exact backup-copy faults'}
 $unexpected=$unexpected.Replace($expected,'EXPECTED STORAGE FAULT')
}
if($unexpected -match 'SCRIPT ERROR|ERROR:'){throw "Review engine failure: $run"}
$reportPath=Join-Path $run "$part/report.json"
if(Test-Path -LiteralPath $reportPath){
 $report=Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json
 if($report.PSObject.Properties.Name -contains 'passed' -and !$report.passed){throw "Assertions failed: $run"}
 if($report.PSObject.Properties.Name -contains 'completed_requested_segment' -and !$report.completed_requested_segment){throw "Actual campaign segment incomplete: $run"}
}
if($Script -eq 'test_parse065.gd' -and $log -notmatch 'PARSE065_RESULT failed=0'){throw 'Compile gate incomplete'}
Write-Output "Verified protected $Target engine exit: $Name"
