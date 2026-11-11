param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$EngineLicenseJson,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$SourceRevision,
    [Parameter(Mandatory)][string]$ReleaseNotes
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$root = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar)
$allowed = [IO.Path]::GetFullPath((Join-Path $repo 'builds')) + [IO.Path]::DirectorySeparatorChar
if (!$root.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Package must be a child of workspace builds.' }
$audit = $root + '-packaging-evidence'
if (Test-Path -LiteralPath $audit) { throw 'Packaging evidence already exists. Use a fresh candidate directory.' }
$runtime = Join-Path $root 'runtime'
$innerExe = Join-Path $runtime 'LanceAndLaurel.exe'
$pack = Join-Path $runtime 'LanceAndLaurel.pck'
foreach ($path in @($innerExe,$pack,$EngineLicenseJson,$ReleaseNotes)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required input is missing: $path" }
}
# Never silently incorporate developer tools, previous launchers or extra data.
$rootEntries = @(Get-ChildItem -LiteralPath $root -Force)
if ($rootEntries.Count -ne 1 -or $rootEntries[0].Name -ne 'runtime') { throw 'Candidate root must contain only the newly exported runtime directory.' }
$runtimeEntries = @(Get-ChildItem -LiteralPath $runtime -Force)
if ($runtimeEntries.Count -ne 2 -or @($runtimeEntries | Where-Object Name -NotIn @('LanceAndLaurel.exe','LanceAndLaurel.pck')).Count -ne 0) {
    throw 'Runtime directory contains unexpected files. Keep diagnostic artifacts outside the player package.'
}
$project = [IO.File]::ReadAllText((Join-Path $repo 'game/project.godot'))
$versionMatch = [regex]::Match($project,'(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z]*[0-9]+)?)"')
if (!$versionMatch.Success) { throw 'Project version is invalid.' }
$version = $versionMatch.Groups[1].Value
& (Join-Path $PSScriptRoot 'Build-Launcher.ps1') -OutputDirectory $audit
Copy-Item -LiteralPath (Join-Path $audit 'LanceAndLaurel.exe') -Destination $root
& (Join-Path $PSScriptRoot 'Write-Notices.ps1') -EngineLicenseJson $EngineLicenseJson -OutputDirectory (Join-Path $root 'licenses')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PLAYER-GUIDE.txt') -Destination $root
Copy-Item -LiteralPath $ReleaseNotes -Destination (Join-Path $root 'RELEASE-NOTES.txt')
$files = @()
foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse | Sort-Object FullName) {
    $relative = $file.FullName.Substring($root.Length+1).Replace('\','/')
    $files += [ordered]@{ path=$relative; bytes=$file.Length; sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
}
$launcher = Get-Content -LiteralPath (Join-Path $audit 'launcher-manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
$manifest = [ordered]@{
    format='galumu-windows-bundle-1'; version=$version; source_revision=$SourceRevision.ToLowerInvariant()
    built_utc=[DateTime]::UtcNow.ToString('o'); engine='4.5.1.stable'; platform='Windows x64'
    entry='LanceAndLaurel.exe'; signed=$false; launcher=$launcher; files=$files
    status='Candidate package; validation and platform approval are recorded separately.'
}
[IO.File]::WriteAllText((Join-Path $root 'build-manifest.json'),($manifest | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
Write-Output "Packaged $version at $root. Generated C# and build tools remain in $audit."
