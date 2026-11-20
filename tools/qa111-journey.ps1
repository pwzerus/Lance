param([ValidateRange(1,16)][int]$FirstBatch=1,[ValidateRange(1,16)][int]$LastBatch=16)
$ErrorActionPreference='Stop'
if($LastBatch -lt $FirstBatch){throw 'Invalid order'}
for($batch=$FirstBatch;$batch -le $LastBatch;$batch++){
 $name='qa111-journey{0:d2}' -f $batch;$first=($batch-1)*5+1;$last=$batch*5
 & "$PSScriptRoot/qa111-run.ps1" -Name $name -Script test_journey111.gd -Extra "--profile=E:/GALUMU/docs/development/logs/qa111-journey/qa_journey --first=$first --last=$last"
 Write-Output "PACKAGED_JOURNEY completed=$last"
}
