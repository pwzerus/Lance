extends "test_head_visual076.gd"
## Diagnostic only: retain every rejected contact instead of hiding it
## behind find_stage's desired nonterminal outcome.
func run()->void:
	var path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	state.profile=state.default_profile();state.profile.settings.sound=false
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	var b=create_battle("war",true)
	var rows=[]
	for attacker in [0,1]:
		for phase in [0.0,.55,1.2,2.2,3.4,4.5]:
			var m=Model.new("war",b.match_model.fighters[0].stats.duplicate(true),b.match_model.fighters[1].stats.duplicate(true),57051)
			stage_model(m,attacker,"head",false,phase)
			var hit={}
			for tick in range(360):
				for e in step_staged(m,attacker,"head"):
					if e.type=="hit" and e.attacker==attacker:hit=e
				if not hit.is_empty() or m.phase=="ended":break
			rows.append({"attacker":attacker,"phase":phase,"event":hit,"stats":[m.fighters[0].stats,m.fighters[1].stats],"state":m.fighters})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"version":ProjectSettings.get_setting("application/config/version")},"\t"))
	main._close_battle();main.sounds.set_enabled(false);main.queue_free()
	await process_frame
	quit()
