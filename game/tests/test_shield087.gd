extends "test_impact_v057.gd"
## The v057 solid-shield fixture compensated for the old drawn-lane force bug
## by choosing opposite high/low guards. FEEL086 correctly removed lane depth
## from thrust; now the chest guard creates the same level incidence both ways.
## Keep production sweeps, finite command movement and all inherited FX checks.
func stage_model(model,attacker:int,zone:String,fatal:bool,phase:float,solid:bool=false,broken_fixture:bool=false)->void:
	super.stage_model(model,attacker,zone,fatal,phase,solid,broken_fixture)
	if not solid:return
	model.fighters[1-attacker].guard=.43
	model.fighters[1-attacker].guard_target=.43
	model.fighters[attacker].aim=aim_for(model,attacker,zone)
	for fighter in model.fighters:model._cache_pose(fighter)

func run()->void:
	await super.run()
	var report=JSON.parse_string(FileAccess.get_file_as_string(report_path))
	report.scope="COMM087 corrected legacy solid-shield staging after FEEL086 lane-depth fix: same chest guard .43 both directions, normal live sweeps and finite commands, actual Battle FX and audio selection. One 1-durability lance isolates genuine break continuity. Not a normal match, balance trial, FPS test or OS input."
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
