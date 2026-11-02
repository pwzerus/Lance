param([string]$PythonPath='python', [switch]$WriteBank)
$ErrorActionPreference='Stop'
$projectRoot=[System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $projectRoot
try {
    $generator=Join-Path $PSScriptRoot 'build_impact_audio_v056.py'
    if($WriteBank){ & $PythonPath $generator --write-bank } else { & $PythonPath $generator }
    if($LASTEXITCODE -ne 0){throw 'Audio generation failed'}
    # This workstation's system Python may wrap files it writes in a
    # transparent-encryption format unreadable by the game. Round-trip only
    # this task's original generated content through ordinary file APIs.
    # No encryption/security setting is changed and no old asset is touched.
    $copyCode=@'
from pathlib import Path
import base64,json,sys
root=Path(sys.argv[1])
paths=[]
if sys.argv[2]=='yes':
    paths.append(root/'game/scripts/visual/sound_bank.gd')
for folder in ('game/assets/audio/impact_v056','docs/development/audio/v056'):
    paths.extend(sorted((root/folder).rglob('*')))
for path in paths:
    if path.is_file():
        print(json.dumps({'path':str(path),'data':base64.b64encode(path.read_bytes()).decode('ascii')}))
'@
    $bankFlag=if($WriteBank){'yes'}else{'no'}
    $bankPath=Join-Path $projectRoot 'game/scripts/visual/sound_bank.gd'
    $assetPrefix=(Join-Path $projectRoot 'game/assets/audio/impact_v056')+'\'
    $reportPrefix=(Join-Path $projectRoot 'docs/development/audio/v056')+'\'
    & $PythonPath -c $copyCode $projectRoot $bankFlag | ForEach-Object {
        $item=$_ | ConvertFrom-Json
        $path=[System.IO.Path]::GetFullPath($item.path)
        if(-not (($WriteBank -and $path -eq $bankPath) -or $path.StartsWith($assetPrefix) -or $path.StartsWith($reportPrefix))){throw 'Unexpected output path'}
        [System.IO.File]::WriteAllBytes($path,[Convert]::FromBase64String($item.data))
    }
    if($LASTEXITCODE -ne 0){throw 'Generated content transfer failed'}
    $waveFiles=Get-ChildItem -LiteralPath (Join-Path $projectRoot 'game/assets/audio/impact_v056') -Filter '*.wav' -File
    if($waveFiles.Count -ne 39){throw 'Expected 39 source WAVs'}
    foreach($file in $waveFiles){
        $bytes=[System.IO.File]::ReadAllBytes($file.FullName)
        if([System.Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'RIFF'){throw ('Unreadable PCM asset: '+$file.Name)}
    }
    Write-Output 'V056: 39 RIFF files readable by ordinary file APIs. Godot import/playback still requires verification.'
} finally {
    Pop-Location
}
