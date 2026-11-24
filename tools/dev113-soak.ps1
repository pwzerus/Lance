param([int]$First=1,[int]$Last=8)
$ErrorActionPreference='Stop'
if($First -lt 1 -or $Last -gt 8 -or $Last -lt $First){throw 'Select existing bounded configurations.'}
$runner=Join-Path $PSScriptRoot 'dev113-run.ps1'
$config113=@(
    '--mode=arena --kit=starter --difficulty=0',
    '--mode=war --kit=starter --difficulty=1 --blood',
    '--mode=war --kit=heavy --difficulty=2 --blood',
    '--mode=arena --kit=heavy --difficulty=2',
    '--mode=war --kit=steady --difficulty=1 --no-slow',
    '--mode=arena --kit=french_light --difficulty=1 --no-shake',
    '--mode=war --kit=italian_plate --difficulty=2 --fullscreen',
    '--mode=war --kit=english_late --difficulty=2 --no-slow --no-shake'
)
for($index113=$First;$index113 -le $Last;$index113++){
    & $runner -Name ('dev113-soak{0:d2}' -f $index113) -Script profile_result099.gd -Target bundle -Extra ('--seconds=360 --capture-render --trace099 '+$config113[$index113-1])
}
