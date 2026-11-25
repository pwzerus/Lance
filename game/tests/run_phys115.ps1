param(
    [Parameter(Mandatory)][ValidatePattern('^phys115-[a-z0-9-]+$')][string]$Name,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9_]+\.gd$')][string]$Script,
    [ValidateSet('source','bundle')][string]$Target='source',
    [string]$Bundle='',
    [ValidateSet('gpu','normal','small')][string]$Budget='gpu',
    [switch]$FolderOutput,
    [switch]$ReportOnly,
    [string]$Extra='',
    [ValidateRange(1,600)][int]$TimeoutSeconds=600
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$run=Join-Path $repo ('docs/development/logs/'+$Name)
if(Test-Path -LiteralPath $run){throw "Preserve earlier evidence: $run"}
New-Item -ItemType Directory -Path $run | Out-Null
$driver=Join-Path $PSScriptRoot $Script
if(!(Test-Path -LiteralPath $driver -PathType Leaf)){throw 'Missing test driver.'}
if($Target -eq 'source'){
    $exe=Join-Path $repo 'tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe'
    $mount="--path `"$repo/game`""
    $ref=(Get-Content -LiteralPath "$repo/.git/HEAD" -Raw).Trim()
    if($ref -notmatch '^ref: (refs/heads/codex/v[0-9.]+)$'){throw 'Unexpected source branch.'}
    $revision=(Get-Content -LiteralPath (Join-Path "$repo/.git" $Matches[1]) -Raw).Trim()
    $packHash=$null
}else{
    if([string]::IsNullOrWhiteSpace($Bundle)){throw 'Explicit release bundle required.'}
    $manifest=Get-Content -LiteralPath "$Bundle/build-manifest.json" -Raw -Encoding utf8 | ConvertFrom-Json
    $exe="$Bundle/runtime/LanceAndLaurel.exe"
    $pack="$Bundle/runtime/LanceAndLaurel.pck"
    $packHash=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash
    $revision=$manifest.source_revision
    $mount="--path `"$Bundle/runtime`" --main-pack `"$pack`""
}
$chain=@();$testPath=$driver
for($depth=0;$depth -lt 16 -and (Test-Path -LiteralPath $testPath);$depth++){
    $chain+=@{path=$testPath;sha256=(Get-FileHash -LiteralPath $testPath -Algorithm SHA256).Hash}
    $extends=[regex]::Match((Get-Content -LiteralPath $testPath -Raw),'(?m)^extends "([^"\r\n]+)"')
    if(!$extends.Success -or $extends.Groups[1].Value.StartsWith('res://')){break}
    $testPath=Join-Path (Split-Path -Parent $testPath) $extends.Groups[1].Value
}
$meta=[ordered]@{target=$Target;executable=$exe;source_revision=$revision;pck_sha256=$packHash;budget=$Budget;extra=$Extra;external_driver_chain=$chain;scope='Protected background QA; GPU on an isolated desktop. No real mouse/keyboard or human play claim.'}
$meta.external_inputs=@()
foreach($match in [regex]::Matches($Extra,'--(?:solver|reference|candidate|input|audit)=([^ ]+)')){
    $inputPath=$match.Groups[1].Value
    if(Test-Path -LiteralPath $inputPath -PathType Leaf){$meta.external_inputs+=@{path=$inputPath;sha256=(Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash}}
}
if($Target -eq 'source'){
    $meta.source_fingerprints=@(Get-ChildItem -LiteralPath "$repo/game/scripts","$repo/game/data" -Recurse -File | Where-Object { $_.Extension -in @('.gd','.json') } | Sort-Object FullName | ForEach-Object { @{path=$_.FullName.Substring($repo.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
}
[IO.File]::WriteAllText("$run/target.json",($meta | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$headless=if($Budget -eq 'gpu'){''}else{'--headless'}
# Optional picture drivers reject --folder in headless mode. Some rule
# drivers use a folder for their JSON files; explicitly retain that contract.
if($FolderOutput -and $ReportOnly){throw 'Choose one output contract.'}
$folderDrivers=@('test_condition113.gd','test_injury113.gd','test_simultaneous113.gd','test_shield113.gd')
$folderArgument=if(!$ReportOnly -and ($Budget -eq 'gpu' -or $FolderOutput -or $Script -in $folderDrivers)){"--folder=$run/results"}else{''}
$parameters=@{Executable=$exe;Arguments="$headless $mount --audio-driver Dummy --script `"$driver`" --log-file `"$run/engine.log`" -- --test-profile $folderArgument --report=$run/report.json $Extra";TimeoutSeconds=$TimeoutSeconds;MemoryLog="$run/memory.log"}
if($Budget -eq 'gpu'){$parameters.IsolatedDesktop=$true}
elseif($Budget -eq 'small'){$parameters.HeadlessDiagnostics=$true}
& "$repo/Start-MemoryBound.ps1" @parameters | Out-Null
$exitCode=$LASTEXITCODE
$memory=Get-Content -LiteralPath "$run/memory.log" -Raw
$engine=Get-Content -LiteralPath "$run/engine.log" -Raw -Encoding utf8
# Preserve and explicitly classify the existing isolated GLES cache warning;
# it is not a shader compilation failure and is never hidden from evidence.
$cacheWarning="ERROR: Can't create shader cache folder, no shader caching will happen: user://"
$unexpected=$engine.Replace($cacheWarning,'KNOWN ISOLATED CACHE WARNING')
$receipt=[ordered]@{exit_code=$exitCode;guardian_exit_zero=($memory -match 'EXIT code=0 ');isolated_desktop_closed=($memory -match 'QA_DESKTOP_CLOSED=True');cache_warning_count=[regex]::Matches($engine,[regex]::Escape($cacheWarning)).Count;unexpected_engine_error=($unexpected -match 'SCRIPT ERROR|ERROR:');reports=@()}
foreach($path in @("$run/report.json","$run/results/report.json")){
    if(Test-Path -LiteralPath $path){
        $report=Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
        $receipt.reports+=@{path=$path;passed=$report.passed;complete=$report.completed_requested_segment}
        if(($report.PSObject.Properties.Name -contains 'passed' -and !$report.passed) -or ($report.PSObject.Properties.Name -contains 'completed_requested_segment' -and !$report.completed_requested_segment)){$receipt.unexpected_engine_error=$true}
    }
}
[IO.File]::WriteAllText("$run/receipt.json",($receipt | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
if(!$receipt.guardian_exit_zero -or $receipt.unexpected_engine_error -or ($Budget -eq 'gpu' -and !$receipt.isolated_desktop_closed)){throw "Protected QA requires review: $run"}
Write-Output "Verified protected $Target execution: $Name (cache warnings: $($receipt.cache_warning_count))."
