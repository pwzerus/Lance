param([Parameter(Mandatory)][string]$LauncherBundle,[Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Use a fresh QA directory.' }
New-Item -ItemType Directory -Path "$output/runtime" | Out-Null
Copy-Item -LiteralPath (Join-Path $LauncherBundle 'LanceAndLaurel.exe') -Destination $output
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /warnaserror+ "/out:$output/runtime/LanceAndLaurel.exe" (Join-Path $PSScriptRoot 'GuardProbe.cs')
if ($LASTEXITCODE -ne 0) { throw 'QA guard probe compilation failed.' }
[IO.File]::WriteAllText("$output/runtime/LanceAndLaurel.pck",'QA fixture; not an actual game PCK')
function Start-GuardProbe([string]$Name,[int]$Hold,[int]$Code) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "$output/LanceAndLaurel.exe"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    foreach ($arg in @('--launcher-isolated','--launcher-timeout=40',"--launcher-log=$output/$Name.log",'--','--test-profile',"--probe-output=$output/$Name.json","--probe-hold=$Hold","--probe-code=$Code")) { $start.ArgumentList.Add($arg) }
    return [Diagnostics.Process]::Start($start)
}
$first = Start-GuardProbe 'observed-limits' 1 37
if (!$first.WaitForExit(10000)) { throw 'Probe timeout.' }
$observation = Get-Content -LiteralPath "$output/observed-limits.json" -Raw | ConvertFrom-Json
$exitPropagation = $first.ExitCode -eq 37
$first.Dispose()
$owner = Start-GuardProbe 'owner-exit' 30 0
$watch = [Diagnostics.Stopwatch]::StartNew()
while (!(Test-Path -LiteralPath "$output/owner-exit.json") -and $watch.Elapsed.TotalSeconds -lt 8) { [Threading.Thread]::Sleep(100) }
$childInfo = Get-Content -LiteralPath "$output/owner-exit.json" -Raw | ConvertFrom-Json
# Only terminate the exact launcher Process instance created by this test.
# The Job, not a broad process-name kill, must clean up its one QA child.
$owner.Kill()
$owner.WaitForExit()
$owner.Dispose()
$childExited = $false
try {
    $child = [Diagnostics.Process]::GetProcessById($childInfo.pid)
    $childExited = $child.WaitForExit(5000)
    $child.Dispose()
} catch [ArgumentException] { $childExited = $true }
$again = Start-GuardProbe 'after-owner-exit' 0 0
if (!$again.WaitForExit(10000)) { throw 'Recovery probe timeout.' }
$restart = $again.ExitCode -eq 0
$again.Dispose()
$result = [ordered]@{observed=$observation;exit_code_propagated=$exitPropagation;child_exited_with_owner=$childExited;restart_after_owner_exit=$restart;scope='Native QA child queries real Job limits; no large allocation. Actual packaged engine tested separately.'}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$output/results.json" -Encoding utf8
$result | ConvertTo-Json -Depth 6
if (!$observation.passed -or !$exitPropagation -or !$childExited -or !$restart) { throw 'Guard verification failed.' }
