param(
    [Parameter(Mandatory)][string]$Bundle,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [string]$JourneyProfile='',
    [switch]$VerboseEngine
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$bundleRoot=(Resolve-Path -LiteralPath $Bundle).Path
$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo 'logs/comm087'))+[IO.Path]::DirectorySeparatorChar
if (!$evidence.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)) { throw 'Use a fresh COMM087 evidence directory.' }
& (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Directory $bundleRoot
$profiles=@(
    @{name='legacy-r3';source='portable-live01/qa_profile.json'},
    @{name='earned-rewards';source='r2-war-hard-heavy01/qa_profile.json'},
    @{name='learned-controls';source='r2-ui01/guide/qa_profile.json'},
    @{name='audio-settings';source='r2-ui01/audio/qa_profile.json'}
)
if ($JourneyProfile) {
    $journey=(Resolve-Path -LiteralPath $JourneyProfile).Path
    if (!$journey.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($journey) -notlike 'qa_*') { throw 'Journey profile must be an existing QA file under logs/comm087.' }
    $profiles+=@{name='earned-journey';source=$journey.Substring($allowed.Length)}
}
foreach ($profile in $profiles) {
    if (!(Test-Path -LiteralPath (Join-Path $allowed $profile.source) -PathType Leaf)) { throw "Missing real prior QA save: $($profile.source)" }
}
New-Item -ItemType Directory -Path $evidence | Out-Null
$rows=[Collections.Generic.List[object]]::new()
foreach ($profile in $profiles) {
    foreach ($stage in @('import','reopen')) {
        $name=$profile.name+'-'+$stage
        $folder=(Join-Path $evidence $profile.name).Replace('\','/')
        $source=(Join-Path $allowed $profile.source).Replace('\','/')
        $sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $start=[Diagnostics.ProcessStartInfo]::new()
        $start.FileName=Join-Path $bundleRoot 'LanceAndLaurel.exe'
        $start.WorkingDirectory=$env:WINDIR
        $start.UseShellExecute=$false
        $start.CreateNoWindow=$true
        $start.Environment['PATH']=Join-Path $env:WINDIR 'System32'
        $launchArguments=@('--launcher-isolated','--launcher-timeout=60',"--launcher-log=$evidence/$name-memory.log",'--audio-driver','Dummy','--script',"$repo/game/tests/test_resume087.gd",'--log-file',"$evidence/$name-engine.log",'--','--test-profile',"--folder=$folder","--profile-source=$source","--stage=$stage")
        if ($VerboseEngine) { $launchArguments=@('--verbose')+$launchArguments }
        foreach ($argument in $launchArguments) {$start.ArgumentList.Add($argument)}
        Write-Output "START save restart: $name"
        $process=[Diagnostics.Process]::Start($start)
        $returned=$process.WaitForExit(75000)
        if (!$returned -and !$process.HasExited) { $process.Kill();[void]$process.WaitForExit(5000) }
        $code=if ($returned) {$process.ExitCode} else {124}
        $process.Dispose()
        $reportPath=Join-Path $folder "report-$stage.json"
        $report=$null
        if (Test-Path -LiteralPath $reportPath) {$report=Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json}
        $unchanged=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -eq $sourceHash
        $engineLog=Join-Path $evidence "$name-engine.log"
        $unexpectedMessages=if (Test-Path -LiteralPath $engineLog) { @(Get-Content -LiteralPath $engineLog -Encoding utf8 | Where-Object {$_ -match '^(SCRIPT ERROR|ERROR|WARNING):'}) } else { @('Engine log is missing') }
        $passed=$code -eq 0 -and $report.passed -eq $true -and $unchanged -and $unexpectedMessages.Count -eq 0
        $rows.Add([ordered]@{name=$name;passed=$passed;exit_code=$code;source_sha256=$sourceHash;source_unchanged=$unchanged;report=$reportPath;failures=$report.failures;unexpected_engine_messages=@($unexpectedMessages)})
        [IO.File]::WriteAllText((Join-Path $evidence 'suite.json'),([ordered]@{passed=@($rows | Where-Object {!$_.passed}).Count -eq 0;complete=$rows.Count -eq $profiles.Count*2;tests=$rows.ToArray();scope='Two separate actual engine processes per copied prior QA save. Native protected launcher, restricted PATH, isolated desktop and normal shutdown. No formal player save or OS input.'} | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        Write-Output "END $name passed=$passed exit=$code"
        if (!$passed) {throw "Restart verification stopped on $name; evidence retained."}
    }
}
