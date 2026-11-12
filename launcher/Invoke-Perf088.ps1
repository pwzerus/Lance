param(
 [string]$Bundle=(Join-Path (Split-Path -Parent $PSScriptRoot) 'builds/LanceAndLaurel-v0.4.42-r2'),
 [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,
 [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_]+\.gd$')][string]$Script,
 [ValidateRange(1,600)][int]$Seconds=120,
 [string[]]$Extra=@(),[switch]$Headless,
 [ValidateSet('--folder=','--report=','--report-path=')][string]$ReportFlag='--folder='
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$Bundle=(Resolve-Path -LiteralPath $Bundle).Path
& (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Directory $Bundle
$base=Join-Path $repo 'logs/perf088';$folder=Join-Path $base $Name
New-Item -ItemType Directory -Path $base -Force | Out-Null
if (Test-Path -LiteralPath $folder) {throw 'Evidence already exists'}
if ($ReportFlag -ne '--folder=') {New-Item -ItemType Directory -Path $folder | Out-Null}
$report=Join-Path $folder 'report.json';$engine=Join-Path $base ($Name+'-engine.log');$memory=Join-Path $base ($Name+'-memory.log')
$start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=Join-Path $Bundle 'LanceAndLaurel.exe';$start.WorkingDirectory=$env:WINDIR;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.Environment['PATH']=Join-Path $env:WINDIR 'System32'
$launch=@('--launcher-isolated',"--launcher-timeout=$Seconds","--launcher-log=$memory",'--audio-driver','Dummy','--script',(Join-Path $repo "game/tests/$Script"),'--log-file',$engine)
if ($Headless) {$launch+='--headless'}
$launch+=@('--','--test-profile',($ReportFlag+$(if ($ReportFlag -eq '--folder=') {$folder} else {$report})));$launch+=$Extra
foreach ($arg in $launch) {$start.ArgumentList.Add($arg)}
$clock=[Diagnostics.Stopwatch]::StartNew();$proc=[Diagnostics.Process]::Start($start);$proc.WaitForExit()
$unexpected=if (Test-Path -LiteralPath $engine) {@(Get-Content -LiteralPath $engine -Encoding utf8 | Where-Object {$_ -match '^(SCRIPT ERROR|ERROR|WARNING):'})} else {@('Missing engine log')}
$result=if(Test-Path -LiteralPath $report){Get-Content -LiteralPath $report -Raw -Encoding utf8 | ConvertFrom-Json}else{$null}
$passed=$proc.ExitCode -eq 0 -and $unexpected.Count -eq 0 -and $null -ne $result -and ($null -eq $result.passed -or $result.passed)
$row=[ordered]@{name=$Name;bundle=$Bundle;script=$Script;passed=$passed;exit=$proc.ExitCode;seconds=$clock.Elapsed.TotalSeconds;report=$report;sha256=if($result){(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash}else{''};unexpected=$unexpected}
[IO.File]::WriteAllText((Join-Path $base ($Name+'-receipt.json')),($row|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$row|ConvertTo-Json -Compress -Depth 5
if (!$passed) {throw "QA failed: $Name"}
