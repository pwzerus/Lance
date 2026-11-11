param([Parameter(Mandatory)][string]$Directory)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Directory).TrimEnd([IO.Path]::DirectorySeparatorChar)
$manifestPath = Join-Path $root 'build-manifest.json'
if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Bundle manifest is missing.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.format -ne 'galumu-windows-bundle-1' -or $manifest.entry -ne 'LanceAndLaurel.exe') { throw 'Unsupported bundle manifest.' }
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $manifest.files) {
    $relative = [string]$entry.path
    if ([IO.Path]::IsPathRooted($relative) -or $relative.Split('/') -contains '..' -or $relative.Contains(':')) { throw 'Unsafe manifest path.' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (!$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or !$seen.Add($relative)) { throw 'Duplicate or escaped manifest path.' }
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) { throw "Bundle file missing: $relative" }
    $file = Get-Item -LiteralPath $full
    if ($file.Length -ne [long]$entry.bytes -or (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Bundle file differs: $relative" }
}
foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse -Force) {
    $relative = $file.FullName.Substring($root.Length+1).Replace('\','/')
    if ($relative -ne 'build-manifest.json' -and !$seen.Contains($relative)) { throw "Unexpected bundle file: $relative" }
}
foreach ($required in @('LanceAndLaurel.exe','runtime/LanceAndLaurel.exe','runtime/LanceAndLaurel.pck','PLAYER-GUIDE.txt','RELEASE-NOTES.txt','licenses/GODOT-LICENSE.txt','licenses/GODOT-THIRD-PARTY.txt','licenses/NOTO-SANS-SC-OFL.txt','licenses/ASSET-NOTICES.txt')) {
    if (!$seen.Contains($required)) { throw "Required manifest entry missing: $required" }
}
$outer = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $root 'LanceAndLaurel.exe'))
if ($outer.ProductVersion -ne $manifest.version) { throw 'Launcher and bundle versions disagree.' }
Write-Output "Verified $($manifest.version): $($seen.Count) files and launcher version match. This is integrity verification, not gameplay validation."
