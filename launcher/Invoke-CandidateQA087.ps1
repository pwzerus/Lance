param(
    [Parameter(Mandatory)][string]$Bundle,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [ValidateSet('UI','Rules','Matches')][string]$Suite='UI'
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$bundleRoot=(Resolve-Path -LiteralPath $Bundle).Path
$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo 'logs/comm087'))+[IO.Path]::DirectorySeparatorChar
if (!$evidence.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)) { throw 'Use a fresh COMM087 evidence directory.' }
& (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Directory $bundleRoot
$manifest=Get-Content -LiteralPath (Join-Path $bundleRoot 'build-manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
New-Item -ItemType Directory -Path $evidence | Out-Null
$jobs=if ($Suite -eq 'UI') { @(
    @{name='intro';script='test_intro087.gd';timeout=60;extra=@()},
    @{name='guide';script='test_guide087.gd';timeout=100;extra=@('--compact','--mouse-only','--elite','--resume-test')},
    @{name='compare';script='test_compare087.gd';timeout=90;extra=@('--compact')},
    @{name='saves';script='test_save_ui087.gd';timeout=90;extra=@('--compact');fault=$true},
    @{name='audio';script='test_audio_ui087.gd';timeout=90;extra=@('--compact');fault=$true},
    @{name='help';script='test_help087.gd';timeout=60;extra=@('--compact')},
    @{name='exit-retry';script='test_exit087.gd';timeout=60;extra=@();fault=$true},
    @{name='exit-discard';script='test_exit087.gd';timeout=60;extra=@('--discard');fault=$true}
) } elseif ($Suite -eq 'Matches') { @(
    @{name='italian-war-hard';script='test_play087.gd';timeout=530;extra=@('--seconds=480','--mode=war','--difficulty=2','--kit=italian_plate','--blood')},
    @{name='english-arena-easy';script='test_play087.gd';timeout=530;extra=@('--seconds=480','--mode=arena','--difficulty=0','--kit=english_late','--fullscreen')}
) } else { @(
    @{name='inventory';script='test_bundle087.gd';timeout=60;extra=@("--version=$($manifest.version)")},
    @{name='head';script='test_head086.gd';timeout=90;reportFlag='--report=';extra=@()},
    @{name='depth';script='test_depth086.gd';timeout=90;reportFlag='--report=';extra=@()},
    @{name='head-handover';script='test_head_release086.gd';timeout=90;reportFlag='--report=';extra=@()},
    @{name='sound-bank';script='test_audio086.gd';timeout=90;reportFlag='--report-path=';extra=@();audio=$true}
) }
$rows=[Collections.Generic.List[object]]::new()
foreach ($job in $jobs) {
    $folder=Join-Path $evidence $job.name
    $report=Join-Path $folder 'report.json'
    if ($job.reportFlag) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=Join-Path $bundleRoot 'LanceAndLaurel.exe'
    $start.WorkingDirectory=$env:WINDIR
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.Environment['PATH']=Join-Path $env:WINDIR 'System32'
    $launchArguments=@('--launcher-isolated',"--launcher-timeout=$($job.timeout)","--launcher-log=$evidence/$($job.name)-memory.log",'--audio-driver','Dummy','--script',"$repo/game/tests/$($job.script)",'--log-file',"$evidence/$($job.name)-engine.log")
    if ($Suite -eq 'Rules') { $launchArguments+=@('--headless') }
    $launchArguments+=@('--','--test-profile')
    $launchArguments+=if ($job.reportFlag) { @($job.reportFlag+$report) } else { @("--folder=$folder") }
    $launchArguments+=$job.extra
    if ($job.audio) { $launchArguments+=@("--audio-dir=$folder/audio") }
    foreach ($argument in $launchArguments) { $start.ArgumentList.Add($argument) }
    Write-Output "START $Suite/$($job.name): protected $($manifest.version), isolated QA"
    $clock=[Diagnostics.Stopwatch]::StartNew()
    $process=[Diagnostics.Process]::Start($start)
    # The native launcher owns the bounded Job and finite timeout. No second
    # protector, no desktop switch, no replacement of the player's process.
    $returned=$process.WaitForExit(($job.timeout+15)*1000)
    if (!$returned -and !$process.HasExited) {
        # Only this exact QA launcher; closing its Job also ends its child.
        $process.Kill()
        [void]$process.WaitForExit(5000)
    }
    $exitCode=if ($returned) { $process.ExitCode } else { 124 }
    $process.Dispose()
    $result=$null
    if (Test-Path -LiteralPath $report) { $result=Get-Content -LiteralPath $report -Raw -Encoding utf8 | ConvertFrom-Json }
    $engineLog=Join-Path $evidence "$($job.name)-engine.log"
    $unexpectedMessages=@()
    if (Test-Path -LiteralPath $engineLog) {
        $unexpectedMessages=@(Get-Content -LiteralPath $engineLog -Encoding utf8 | Where-Object {
            $_ -match '^(SCRIPT ERROR|ERROR|WARNING):' -and !($job.fault -and ($_ -match '^ERROR: Failed to open ' -or $_ -match '^WARNING: SAVE_IO:'))
        })
    } else { $unexpectedMessages=@('Engine log is missing') }
    $passed=$exitCode -eq 0 -and $null -ne $result -and $result.passed -eq $true -and $unexpectedMessages.Count -eq 0
    $rows.Add([ordered]@{name=$job.name;passed=$passed;exit_code=$exitCode;wall_seconds=$clock.Elapsed.TotalSeconds;report=$report;report_sha256=if ($result) {(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash} else {''};intentional_file_fault=[bool]$job.fault;failures=$result.failures;unexpected_engine_messages=$unexpectedMessages})
    $summary=[ordered]@{suite=$Suite;version=$manifest.version;source_revision=$manifest.source_revision;bundle=$bundleRoot;tests=$rows.ToArray();passed=@($rows | Where-Object {!$_.passed}).Count -eq 0;complete=$rows.Count -eq $jobs.Count;scope='Serial actual EXE/PCK through native protected launcher; restricted PATH, separate QA saves, no foreground or OS input. Expected file-fault cases are identified.'}
    [IO.File]::WriteAllText((Join-Path $evidence 'suite.json'),($summary | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    Write-Output "END $($job.name): passed=$passed exit=$exitCode seconds=$([math]::Round($clock.Elapsed.TotalSeconds,2))"
    if (!$passed) { throw "Candidate QA stopped on $($job.name). Evidence retained; later cases were not run." }
}
