param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceRevision,[ValidateRange(1,9)][int]$Candidate=4)
$ErrorActionPreference='Stop'
$repo='E:/GALUMU'
$version113="0.4.60-c$Candidate"
$bundle="$repo/builds/LanceAndLaurel-v$version113"
$run=('{0}/docs/development/logs/dev113-export{1:d2}' -f $repo,$Candidate)
if ((Test-Path -LiteralPath $bundle) -or (Test-Path -LiteralPath $run)) {throw 'Preserve old packages and evidence; choose a new candidate.'}
$project=Get-Content -LiteralPath "$repo/game/project.godot" -Raw
if (!$project.Contains(('config/version="{0}"' -f $version113))) {throw 'Candidate version has not been set.'}
$actual=(Get-Content -LiteralPath "$repo/.git/refs/heads/codex/v0.4" -Raw).Trim()
if ($SourceRevision -ne $actual) {throw 'The requested source revision is not the checked-out HEAD.'}
New-Item -ItemType Directory -Path "$bundle/runtime",$run | Out-Null
foreach ($stage in @('import','export')) {
    $folder=Join-Path $run $stage
    New-Item -ItemType Directory -Path $folder | Out-Null
    $action=if($stage -eq 'import'){'--editor --import --quit'}else{"--export-release `"Windows Desktop`" `"$bundle/runtime/LanceAndLaurel.exe`""}
    & "$repo/Start-MemoryBound.ps1" -Executable "$repo/tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe" -Arguments "--headless --path $repo/game $action --log-file $folder/engine.log -- --test-profile" -TimeoutSeconds 600 -MemoryLog "$folder/memory.log" | Out-Null
    $memory=Get-Content -LiteralPath "$folder/memory.log" -Raw
    $engine=Get-Content -LiteralPath "$folder/engine.log" -Raw -Encoding utf8
    if ($memory -notmatch 'EXIT code=0 ' -or $engine -match 'SCRIPT ERROR|ERROR:') {throw "Import/export requires review: $stage"}
}
& "$repo/launcher/Complete-Package.ps1" -OutputDirectory $bundle -EngineLicenseJson "$repo/docs/development/logs/qa111-portable01/quoted-path/engine-licenses.json" -SourceRevision $SourceRevision -ReleaseNotes "$repo/launcher/RELEASE-NOTES-v$version113.txt"
& "$repo/launcher/Verify-Package.ps1" -Directory $bundle
Write-Output 'Fresh Windows candidate exported and hash-checked. Actual gameplay validation is still required.'
