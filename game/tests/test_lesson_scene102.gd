extends "test_play087.gd"
const Campaign102=preload("res://scripts/core/campaign.gd")
func run() -> void:
	var folder=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.combat_brief_v044=true
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	var rows=[]
	for n in [12,21]:
		var level=Campaign102.level(state.items,n)
		state.profile.equipped=level.equipment.duplicate(true)
		for id in level.equipment.values():
			if id not in state.profile.owned:state.profile.owned.append(id)
		state.profile.campaign_cleared=range(1,n)
		main._start_level(n);var b=main.battle
		prepare(b,10212+n)
		var started=Time.get_ticks_msec();var seen="";var changes=[];var captured_hit=false
		while Time.get_ticks_msec()-started<60000:
			await process_frame
			if not b.presentation_ready:continue
			if b.ai_controller.last_observation_time>=0 and seen!=b.ai_zone:
				seen=b.ai_zone
				changes.append({"zone":seen,"aim":b.match_model.fighters[1].aim,"gap":absf(b.match_model.fighters[0].x-b.match_model.fighters[1].x)})
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder+"/level%d-line%d.png"%[n,changes.size()])
			if not b.exchange_log.is_empty():
				if not captured_hit:
					captured_hit=true
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(folder+"/level%d-hit.png"%n)
				if not b.exchange_state.impact_active:break
		check(captured_hit and not changes.is_empty(),"Lesson reaches visible contact "+str(n))
		var changes_first=level.ai.get("attack_lesson","")=="change_once" and 1 in level.ai.get("lesson_change_passes",[1,2,3])
		check(changes.size()==(2 if changes_first else 1),"Expected readable line sequence "+str(n))
		rows.append({"level":n,"changes":changes,"hits":b.exchange_log.duplicate(true),"profile":b.ai_controller.profile})
		main._close_battle();await process_frame
		check(is_equal_approx(Engine.time_scale,1.0),"Lesson exit restores time")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Isolated GPU Main levels 12/21; autoplay injected in engine, QA unlock and matched kit, first exchange only. No OS/human evidence."},"\t"))
	main.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
