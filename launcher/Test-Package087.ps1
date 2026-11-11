param([Parameter(Mandatory)][string]$Directory,[Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$root=[IO.Path]::GetFullPath($Directory)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo 'builds'))+[IO.Path]::DirectorySeparatorChar
if (!$root.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or !(Split-Path -Leaf $root).StartsWith('COMM087-package-tool-qa')) { throw 'Only disposable COMM087 package-tool QA fixtures may be modified.' }
$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if (!$evidence.StartsWith([IO.Path]::GetFullPath((Join-Path $repo 'logs/comm087'))+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)) { throw 'Evidence must be a fresh COMM087 logs child.' }
New-Item -ItemType Directory -Path $evidence | Out-Null
$manifest=Join-Path $root 'build-manifest.json'
$original=[IO.File]::ReadAllBytes($manifest)
$rows=[Collections.Generic.List[object]]::new()
try {
    & (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Directory $root | Out-Null
    $rows.Add(@{case='valid';passed=$true})
    foreach ($scenario in @('wrong-hash','truncated-size','escaped-path','duplicate','missing-entry')) {
        $data=[Text.Encoding]::UTF8.GetString($original) | ConvertFrom-Json
        switch ($scenario) {
            'wrong-hash' { $data.files[0].sha256='0'*64 }
            'truncated-size' { $data.files[0].bytes=[long]$data.files[0].bytes+1 }
            'escaped-path' { $data.files[0].path='../outside.txt' }
            'duplicate' { $data.files+=@($data.files[0]) }
            'missing-entry' { $data.files=@($data.files | Select-Object -Skip 1) }
        }
        [IO.File]::WriteAllText($manifest,($data | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        $rejected=$false;$message=''
        try { & (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Directory $root | Out-Null } catch { $rejected=$true;$message=$_.Exception.Message }
        $rows.Add(@{case=$scenario;passed=$rejected;message=$message})
        [IO.File]::WriteAllBytes((Join-Path $evidence ($scenario+'.json')),[IO.File]::ReadAllBytes($manifest))
        [IO.File]::WriteAllBytes($manifest,$original)
    }
    # Test actual file corruption as well as malformed metadata.
    $guide=Join-Path $root 'PLAYER-GUIDE.txt'
    $guideOriginal=[IO.File]::ReadAllBytes($guide)
    try {
        [IO.File]::AppendAllText($guide,'QA-corruption')
        $rejected=$false;$message=''
        try { & (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Directory $root | Out-Null } catch { $rejected=$true;$message=$_.Exception.Message }
        $rows.Add(@{case='actual-file-corruption';passed=$rejected;message=$message})
    } finally { [IO.File]::WriteAllBytes($guide,$guideOriginal) }
} finally { [IO.File]::WriteAllBytes($manifest,$original) }
& (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Directory $root | Out-Null
$passed=@($rows | Where-Object { !$_.passed }).Count -eq 0
[IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{passed=$passed;cases=$rows;scope='Actual bundle hashes, files and launcher PE metadata. QA fixture restored byte-for-byte; gameplay is separate.'} | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
if (!$passed) { throw 'Some corrupt package cases were not rejected.' }
Write-Output 'Package verification rejected all corrupt cases and accepted the restored fixture.'
