extends "test_impact_v057.gd"
## Inspect the legacy staged shield fixture after FEEL086 lane-depth correction.
## No event/angle override and no pass assertion: preserve actual sweep outcomes.
func run()->void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not state.save_path.contains("qa_"):quit(2);return
	var rows=[]
	for attacker in range(2):
		for guard in [0.0,.43,1.0]:
			for phase in [0.0,.55,1.2,2.2,3.4,4.5]:
				var model=Model.new("arena",state.player_stats(),state.player_stats(),57051)
				stage_model(model,attacker,"shield",false,phase,true,false)
				model.fighters[1-attacker].guard=guard
				model.fighters[1-attacker].guard_target=guard
				var hits=[]
				for tick in range(360):
					for e in step_staged(model,attacker,"shield"):
						if e.type=="hit":hits.append(e)
					if not hits.is_empty() or model.phase=="ended":break
				rows.append({"attacker":attacker,"guard":guard,"phase":phase,"hits":hits})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"scope":"Diagnostic fixed approach; real finite controls and sweeps. Not a performance or human acceptance test."},"\t"))
	print("SHIELD_PROBE087 rows=",rows.size());quit()
