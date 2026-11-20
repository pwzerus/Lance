param([string]$Bundle='E:/GALUMU/builds/LanceAndLaurel-v0.4.59-c1')
$ErrorActionPreference='Stop'
# This is the separate post-stage integration period, never counted in stage 9.
# Starting time is written only when the caller has accepted all five stages.
$cases=@(
 @{Name='starter-arena';Extra='--kit=starter --mode=arena --difficulty=0'},
 @{Name='starter-war';Extra='--kit=starter --mode=war --difficulty=1 --blood'},
 @{Name='french-light';Extra='--kit=french_light --mode=arena --difficulty=2 --no-slow'},
 @{Name='italian-plate';Extra='--kit=italian_plate --mode=war --difficulty=2 --blood --no-shake'},
 @{Name='heavy-arena';Extra='--kit=heavy --mode=arena --difficulty=2'},
 @{Name='english-late';Extra='--kit=english_late --mode=war --difficulty=1 --no-slow --no-shake'},
 @{Name='steady-arena';Extra='--kit=steady --mode=arena --difficulty=1'}
)
foreach($case in $cases){
 & "$PSScriptRoot/qa111-run.ps1" -Name ('qa111-final-'+$case.Name+'01') -Script test_play087.gd -Bundle $Bundle -Extra ('--seconds=480 --capture-render '+$case.Extra)
}
Write-Output 'Seven distinct eight-minute integration cases closed. Separate final inspection and total elapsed-time gate still required.'
