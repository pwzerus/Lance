$ErrorActionPreference = 'Stop'
$qaExe = 'E:/GALUMU/builds/LanceAndLaurel-v0.4.17-r3/LanceAndLaurel.exe'
$qaRoot = 'E:/GALUMU/docs/development/logs/v057'
$qaShots = 'E:/GALUMU/docs/development/screenshots/v057'
$qaRuns = @(
    @{Name='full-charge-package02'; Script='test_full_charge_v056.gd'; Extra=@()},
    @{Name='impact-solid-package01'; Script='test_impact_v057.gd'; Extra=@('--suite=solid')},
    @{Name='timing-package01'; Script='test_timing_v057.gd'; Extra=@()},
    @{Name='audio-exit-package01'; Script='test_audio_exit_v055.gd'; Extra=@('--paused-exit')}
)
$qaResults = @()
foreach ($qaCase in $qaRuns) {
    $qaName = $qaCase.Name
    $qaArgs = @('--rendering-method','gl_compatibility','--minimized','--script',("E:/GALUMU/game/tests/"+$qaCase.Script),'--log-file',"$qaRoot/$qaName.log",'--','--test-profile',"--report=$qaRoot/$qaName.json","--captures=$qaShots/$qaName") + $qaCase.Extra
    $qaProcess = Start-Process -FilePath $qaExe -ArgumentList $qaArgs -WindowStyle Hidden -PassThru -Wait
    $qaResults += [ordered]@{name=$qaName; exit_code=$qaProcess.ExitCode; log="$qaRoot/$qaName.log"}
    Write-Output "$qaName EXIT=$($qaProcess.ExitCode)"
    Get-Content -LiteralPath "$qaRoot/$qaName.log" -Tail 3
    if ($qaProcess.ExitCode -ne 0) { throw "QA failed: $qaName" }
}
$qaResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$qaRoot/final-package-exits.json" -Encoding utf8
