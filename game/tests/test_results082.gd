extends "test_gui082.gd"
const Report=preload("res://scripts/ui/combat_report.gd")
const Model=preload("res://scripts/core/joust_match.gd")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	main.set_process(false)
	for mode in ["arena","war"]:
		main._start_match(mode,true)
		var b=main.battle
		b.set_process(false)
		b.set_physics_process(false)
		# Explicit presentation fixture, with force/damage resolved by the
		# production model. Not an aiming, difficulty or win-rate test.
		var m=Model.new(mode,{"stability":8.0},{"stability":8.0},8202)
		m._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":"shield","shield_region":"rim","speed":800.0,"position":Vector2.ZERO})
		m._apply_contact({"type":"hit","attacker":1,"defender":0,"zone":"body","speed":700.0,"position":Vector2.ZERO})
		b.exchange_log.clear()
		for event in m.drain_events():
			if event.type=="hit": b.exchange_log.append(event)
		main.practice_match=false # Only the presentation; no award callback.
		m.pass_number=3
		m._finish("condition") # Keep displayed scores/health consistent with the events.
		main.pending_result=m.result.duplicate(true)
		main.reward={"coins":55+(30 if mode=="war" else 0),"renown":1}
		b.is_finished=true
		b._update_hud()
		check(not b.hud.visible,"Finished battle HUD obscures result")
		main.show_result()
		for _i in range(3): await process_frame
		var text=Report.summarize(b.exchange_log,mode)
		check(text.contains("盾缘受击") and text.contains("胸甲"),"Resolved contact areas missing from result")
		check(not text.contains("平衡余量") and not text.contains("速度系数"),"Default result shows numeric diagnostics")
		if mode=="arena": check(text.contains("分"),"Arena hides contact score")
		else: check(not text.contains("计分") and not text.contains(" 分"),"War result falsely shows tournament score")
		await capture(mode+"_compact")
		click_text("详细数据")
		for _i in range(2): await process_frame
		var summary=main.screen.find_child("ContactSummary",true,false)
		check(summary!=null and summary.text.contains("平衡余量"),"Details GUI switch did not reveal diagnostic data")
		await capture(mode+"_details")
		main._close_battle()
		main.show_home()
		await process_frame
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Mode-specific results from resolved force fixtures, GPU layout at 960x540, actual engine GUI details toggle; no natural match/win-rate claim."},"\t"))
	print("RESULT082 ",failures)
	quit(0 if failures.is_empty() else 1)
