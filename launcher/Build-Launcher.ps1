param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath($OutputDirectory)
$allowed = [IO.Path]::GetFullPath((Join-Path $repo 'builds')) + [IO.Path]::DirectorySeparatorChar
if (!$output.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Launcher output must be inside this workspace builds directory.'
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
$target = Join-Path $output 'LanceAndLaurel.exe'
if (Test-Path -LiteralPath $target) { throw 'Refusing to overwrite an existing release executable. Use a new build folder.' }
$guard = Join-Path $repo 'Start-MemoryBound.ps1'
$source = [IO.File]::ReadAllText($guard)
$match = [regex]::Match($source, "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
if (!$match.Success) { throw 'MemoryBound source block was not found; no launcher built.' }
$generated = Join-Path $output 'MemoryBound.generated.cs'
[IO.File]::WriteAllText($generated, $match.Groups[1].Value, [Text.UTF8Encoding]::new($false))
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$icon = Join-Path $PSScriptRoot 'assets/LanceAndLaurel.ico'
if (!(Test-Path -LiteralPath $icon)) { throw 'Project icon is missing. Run the protected build_icon087.gd conversion first.' }
$project = [IO.File]::ReadAllText((Join-Path $repo 'game/project.godot'))
$versionMatch = [regex]::Match($project, '(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z]*[0-9]+)?)"')
if (!$versionMatch.Success) { throw 'Cannot determine a safe project version for launcher metadata.' }
$version = $versionMatch.Groups[1].Value
$numbers = @([regex]::Matches($version,'\d+') | ForEach-Object { $_.Value })
while ($numbers.Count -lt 4) { $numbers += '0' }
$fileVersion = ($numbers[0..3] -join '.')
$metadata = Join-Path $output 'Launcher.AssemblyInfo.cs'
$assemblyInfo = @"
using System.Reflection;
[assembly: AssemblyTitle("Lance & Laurel")]
[assembly: AssemblyDescription("Lance & Laurel Windows game launcher")]
[assembly: AssemblyCompany("GALUMU")]
[assembly: AssemblyProduct("Lance & Laurel")]
[assembly: AssemblyFileVersion("$fileVersion")]
[assembly: AssemblyInformationalVersion("$version")]
"@
[IO.File]::WriteAllText($metadata, $assemblyInfo, [Text.UTF8Encoding]::new($false))
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /warnaserror+ /reference:System.Windows.Forms.dll "/win32icon:$icon" "/out:$target" (Join-Path $PSScriptRoot 'Launcher.cs') $generated $metadata
if ($LASTEXITCODE -ne 0) { throw "Launcher compiler failed: $LASTEXITCODE" }
$manifest = [ordered]@{
    format = 'galumu-launcher-1'
    guard_sha256 = (Get-FileHash -LiteralPath $guard -Algorithm SHA256).Hash
    extracted_guard_sha256 = (Get-FileHash -LiteralPath $generated -Algorithm SHA256).Hash
    launcher_source_sha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Launcher.cs') -Algorithm SHA256).Hash
    launcher_sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    icon_sha256 = (Get-FileHash -LiteralPath $icon -Algorithm SHA256).Hash
    product_version = $version
    file_version = $fileVersion
    built_utc = [DateTime]::UtcNow.ToString('o')
    note = 'Compiled from the same MemoryBound source; 1024 MiB Job, 900 MiB early stop, 500 MiB system reserve, 25% CPU and one instance.'
}
[IO.File]::WriteAllText((Join-Path $output 'launcher-manifest.json'), ($manifest | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
# This generated intermediate is kept with QA evidence, not needed by players.
Write-Output "Built protected portable launcher: $target"
