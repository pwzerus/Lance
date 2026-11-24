param([int]$First=1,[int]$Last=5,[switch]$Heavy,[switch]$HighGuard,[switch]$LowLine,[string]$Bundle='E:/GALUMU/builds/LanceAndLaurel-v0.4.60-c3',[string]$Prefix='dev113-journey',[string]$Profile='E:/GALUMU/docs/development/logs/dev113-campaign/qa_journey')
$ErrorActionPreference='Stop'
if($First -lt 1 -or $Last -gt 80 -or $Last -lt $First){throw 'Use a bounded campaign segment.'}
$runner=Join-Path $PSScriptRoot 'dev113-run.ps1'
for($level113=$First;$level113 -le $Last;$level113+=5){
    $end113=[Math]::Min($Last,$level113+4)
    $name113='{0}-{1:d2}-{2:d2}' -f $Prefix,$level113,$end113
    $options113='--profile={0} --first={1} --last={2} --attempts=3' -f $Profile,$level113,$end113
    if($Heavy){$options113+=' --heavy'}
    if($HighGuard){$options113+=' --high-guard'}
    if($LowLine){$options113+=' --low-line'}
    & $runner -Name $name113 -Script test_journey113.gd -Target bundle -Bundle $Bundle -Extra $options113
    # The driver verifies normal rewards, purchases and saves, and the
    # runner rejects incomplete segments. Never grant clears to continue.
}
