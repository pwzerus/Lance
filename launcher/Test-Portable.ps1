param([Parameter(Mandatory)][string]$Bundle,[Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference = 'Stop'
$bundlePath = (Resolve-Path -LiteralPath $Bundle).Path
$evidencePath = [IO.Path]::GetFullPath($EvidenceDirectory)
if (Test-Path -LiteralPath $evidencePath) { throw 'Use a fresh evidence directory.' }
New-Item -ItemType Directory -Path $evidencePath | Out-Null
$repo = Split-Path -Parent $PSScriptRoot
$results = [Collections.Generic.List[object]]::new()
function Start-Probe([string]$Name,[string[]]$Extra,[int]$WaitSeconds=0) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = Join-Path $bundlePath 'LanceAndLaurel.exe'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    # Prove that neither Codex's shell nor the developer Godot is resolved by PATH.
    $start.Environment['PATH'] = Join-Path $env:WINDIR 'System32'
    $start.WorkingDirectory = $env:WINDIR
    $arguments = @('--launcher-isolated','--launcher-timeout=30',"--launcher-log=$evidencePath/$Name-memory.log",'--headless','--script',"$repo/game/tests/test_launcher087.gd",'--log-file',"$evidencePath/$Name-engine.log",'--','--test-profile',"--folder=$evidencePath/$Name","--probe-wait=$WaitSeconds") + $Extra
    foreach ($argument in $arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    return $process
}
function Wait-Probe($Process,[string]$Name,[int]$Expected) {
    if (!$Process.WaitForExit(40000)) { throw "Guarded probe did not exit: $Name" }
    $results.Add([ordered]@{name=$Name;code=$Process.ExitCode;expected=$Expected;passed=$Process.ExitCode -eq $Expected})
    $Process.Dispose()
}
$quoted = Start-Probe 'quoted-path' @('--literal=two words','--literal=quote"and\end\','--literal=尾部 空格\') 2
Wait-Probe $quoted 'relocated-arguments' 0
$probe = Get-Content -LiteralPath "$evidencePath/quoted-path/probe.json" -Raw | ConvertFrom-Json
foreach ($literal in @('--literal=two words','--literal=quote"and\end\','--literal=尾部 空格\')) {
    $results.Add([ordered]@{name="argument:$literal";passed=$probe.arguments -ccontains $literal})
}
$results.Add([ordered]@{name='isolated-save-and-guard';passed=($probe.profile -like '*qa_*' -and $probe.guard -eq '1024')})
$holder = Start-Probe 'holder' @() 8
$watch = [Diagnostics.Stopwatch]::StartNew()
while (!(Test-Path -LiteralPath "$evidencePath/holder/probe.json") -and $watch.Elapsed.TotalSeconds -lt 10) {
    [Threading.Thread]::Sleep(100)
}
if (!(Test-Path -LiteralPath "$evidencePath/holder/probe.json")) { throw 'First guarded child failed to start; concurrency test not valid.' }
$duplicate = Start-Probe 'duplicate' @() 0
Wait-Probe $duplicate 'duplicate-blocked' 2
Wait-Probe $holder 'first-unaffected' 0
$timeout = Start-Probe 'timeout' @('--launcher-timeout=2') 15
Wait-Probe $timeout 'finite-timeout' 124
$after = Start-Probe 'after-timeout' @() 0
Wait-Probe $after 'mutex-and-desktop-released' 0
$invalid = Start-Probe 'invalid-timeout' @('--launcher-timeout=601') 0
Wait-Probe $invalid 'invalid-timeout-rejected' 2
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$evidencePath/results.json" -Encoding utf8
$results | Format-Table -AutoSize
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { throw 'Portable launcher verification failed.' }
