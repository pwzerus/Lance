param([Parameter(Mandatory)][string]$EngineLicenseJson,[Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$licenseData = Get-Content -LiteralPath $EngineLicenseJson -Raw -Encoding utf8 | ConvertFrom-Json
if (!$licenseData.godot -or !$licenseData.licenses -or !$licenseData.copyright) { throw 'Incomplete engine license evidence.' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
$allowed = [IO.Path]::GetFullPath((Join-Path $repo 'builds')) + [IO.Path]::DirectorySeparatorChar
if (!$output.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'License output must be inside workspace builds.' }
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -gt 0) {
    throw 'Refusing to overwrite existing license attachments. Use a new bundle folder.'
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $output 'GODOT-LICENSE.txt'), $licenseData.godot, $utf8)
$text = [Text.StringBuilder]::new()
[void]$text.AppendLine('Godot Engine 4.5.1 - third-party notices')
[void]$text.AppendLine('Extracted from the actual engine: Engine.get_copyright_info() and Engine.get_license_info().')
foreach ($component in $licenseData.copyright) {
    [void]$text.AppendLine("`n=== $($component.name) ===")
    foreach ($part in $component.parts) {
        [void]$text.AppendLine('Files: ' + ($part.files -join ', '))
        [void]$text.AppendLine(($part.copyright -join "`n"))
        [void]$text.AppendLine('License: ' + $part.license)
    }
}
foreach ($license in $licenseData.licenses.PSObject.Properties | Sort-Object Name) {
    [void]$text.AppendLine("`n=== License text: $($license.Name) ===")
    [void]$text.AppendLine($license.Value)
}
[IO.File]::WriteAllText((Join-Path $output 'GODOT-THIRD-PARTY.txt'), $text.ToString(), $utf8)
Copy-Item -LiteralPath (Join-Path $repo 'game/assets/fonts/OFL.txt') -Destination (Join-Path $output 'NOTO-SANS-SC-OFL.txt')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ASSET-NOTICES.txt') -Destination $output
Write-Output "Wrote engine, third-party, font and asset notices to $output"
