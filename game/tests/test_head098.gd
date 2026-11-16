extends "test_head076.gd"
## REQ-098 changes the old helmet-block expectation: a full square war hit
## can end even a high-tier helmet; grazing, a raised shield and speed matter.
func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2)
		return
	for facing in [1,-1]:
		for helmet in [.08,.41]:
			var full=sweep(facing,"war",0,960,helmet)
			var slow=sweep(facing,"war",0,400,helmet)
			var glance=sweep(facing,"war",22,960,helmet)
			var broken=sweep(facing,"war",0,960,helmet,1.0,true)
			var shielded=sweep(facing,"war",0,960,helmet,1.0,false,1.0,true)
			var arena=sweep(facing,"arena",0,960,helmet)
			if full.is_empty() or slow.is_empty() or glance.is_empty() or broken.is_empty() or shielded.is_empty() or arena.is_empty(): continue
			check(full.defender.dead,"full square war head strike must end fight")
			for weak in [slow,glance,broken,shielded]: check(not weak.defender.dead,"glance, slow, broken or shielded line became instant death")
			check(not arena.defender.dead,"arena killed a rider")
			check(shielded.event.zone=="shield","raised shield failed to intercept")
			for result in [full,slow,glance,broken,shielded,arena]:
				rows.append({"facing":facing,"helmet":helmet,"event":result.event,"mode":result.model.mode,"hp":result.defender.hp,"dead":result.defender.dead})
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"  "))
	print("HEAD098 "+JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
