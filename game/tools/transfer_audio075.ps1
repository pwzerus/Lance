# Transfer only our freshly generated v075 output through ordinary file APIs.
# Same endpoint-software compatibility step as build_impact_audio_v056.ps1.
param([string]$PythonPath='python')
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$copyCode=@'
from pathlib import Path
import base64,json,sys
root=Path(sys.argv[1])
for folder in ('game/assets/audio/impact_v075','docs/development/audio/v075'):
    for path in sorted((root/folder).rglob('*')):
        if path.is_file():
            print(json.dumps({'path':str(path),'data':base64.b64encode(path.read_bytes()).decode('ascii')}))
'@
$assetPrefix=(Join-Path $projectRoot 'game/assets/audio/impact_v075')+'\'
$reportPrefix=(Join-Path $projectRoot 'docs/development/audio/v075')+'\'
& $PythonPath -c $copyCode $projectRoot | ForEach-Object {
    $item=$_ | ConvertFrom-Json
    $path=[IO.Path]::GetFullPath($item.path)
    if(-not ($path.StartsWith($assetPrefix) -or $path.StartsWith($reportPrefix))){throw ('Unexpected output path: '+$path)}
    [IO.File]::WriteAllBytes($path,[Convert]::FromBase64String($item.data))
}
if($LASTEXITCODE -ne 0){throw 'Content transfer failed'}
$files=Get-ChildItem -LiteralPath (Join-Path $projectRoot 'game/assets/audio/impact_v075') -Filter '*.wav' -File
if($files.Count -ne 39){throw 'Expected 39 WAVs'}
foreach($file in $files){
    $bytes=[IO.File]::ReadAllBytes($file.FullName)
    if([Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'RIFF'){throw 'Unreadable generated WAV'}
}
Write-Output 'All 39 original v075 WAVs readable as RIFF.'
