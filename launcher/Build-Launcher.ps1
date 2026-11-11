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
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /warnaserror+ /reference:System.Windows.Forms.dll "/out:$target" (Join-Path $PSScriptRoot 'Launcher.cs') $generated
if ($LASTEXITCODE -ne 0) { throw "Launcher compiler failed: $LASTEXITCODE" }
$manifest = [ordered]@{
    format = 'galumu-launcher-1'
    guard_sha256 = (Get-FileHash -LiteralPath $guard -Algorithm SHA256).Hash
    extracted_guard_sha256 = (Get-FileHash -LiteralPath $generated -Algorithm SHA256).Hash
    launcher_source_sha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Launcher.cs') -Algorithm SHA256).Hash
    launcher_sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    built_utc = [DateTime]::UtcNow.ToString('o')
    note = 'Compiled from the same MemoryBound source; 1024 MiB Job, 900 MiB early stop, 500 MiB system reserve, 25% CPU and one instance.'
}
[IO.File]::WriteAllText((Join-Path $output 'launcher-manifest.json'), ($manifest | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
# This generated intermediate is kept with QA evidence, not needed by players.
Write-Output "Built protected portable launcher: $target"
