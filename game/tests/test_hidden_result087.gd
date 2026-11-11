extends "test_ui082.gd"
## Explicit gap: result pages do not pause a finished Battle. Count individual
## canvas draw callbacks, not only whole-window frames, with H overlay enabled.
func run()->void:
	var hidden_seconds=90.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--hidden-seconds="):hidden_seconds=clampf(float(arg.trim_prefix("--hidden-seconds=")),15,90)
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	main._start_match("arena",false)
	var battle=main.battle
	battle.autoplay=true;battle.match_model.rng.seed=87091;battle.ai_rng.seed=87444
	if root.focus_exited.is_connected(battle._on_focus_lost):root.focus_exited.disconnect(battle._on_focus_lost)
	battle.training_zones=true;battle.zone_overlay.visible=true
	var counts={"zones":0,"cues":0,"rider0":0,"rider1":0}
	battle.zone_overlay.draw.connect(func():counts.zones+=1)
	battle.combat_cues.draw.connect(func():counts.cues+=1)
	battle.riders[0].draw.connect(func():counts.rider0+=1)
	battle.riders[1].draw.connect(func():counts.rider1+=1)
	var started=Time.get_ticks_msec()
	while not main.result_visible and Time.get_ticks_msec()-started<120000:await process_frame
	check(main.result_visible and battle.is_finished,"Actual normal match did not reach results")
	if not main.result_visible:quit(1);return
	await capture("01_result_visible")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var until=Time.get_ticks_msec()+1200
	while Time.get_ticks_msec()<until:await process_frame
	check(not DisplayServer.window_can_draw(),"Result did not become non-drawable")
	var before=counts.duplicate(true)
	var rows=[]
	var hidden_start=Time.get_ticks_msec()
	var sample=0
	while Time.get_ticks_msec()-hidden_start<int(hidden_seconds*1000):
		await process_frame
		if Time.get_ticks_msec()>=sample:
			sample=Time.get_ticks_msec()+1000
			rows.append({"seconds":(Time.get_ticks_msec()-hidden_start)/1000.0,"counts":counts.duplicate(true),"frames_drawn":Engine.get_frames_drawn(),"nodes":get_node_count()})
			# Retain the last counts even if the memory guard stops a regression.
			if rows.size()%5==0:FileAccess.open(folder+"/hidden-progress.json",FileAccess.WRITE).store_string(JSON.stringify({"before":before,"latest":rows.back(),"samples":rows}))
	var after=counts.duplicate(true)
	for key in counts:check(int(after[key])-int(before[key])<=1,"Hidden finished battle kept redrawing "+key)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	until=Time.get_ticks_msec()+1200
	while Time.get_ticks_msec()<until:await process_frame
	check(main.result_visible and state.profile.matches==1,"Restore duplicated or dismissed result/reward")
	await capture("02_result_restored")
	check(click_result_back(),"Restored result cannot return to camp")
	await process_frame
	check(main.page=="home" and not is_instance_valid(main.battle),"Finished battle remained after return to camp")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"before":before,"after":after,"samples":rows,"version":ProjectSettings.get_setting("application/config/version"),"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"hidden_seconds":hidden_seconds,"scope":"Normal Main/autoplay match and result, bounded truly minimized interval on isolated desktop, individual CanvasItem draw signal counters. H overlay enabled. Engine window modes and viewport return click, no OS input or human play."},"\t"))
	print("HIDDEN_RESULT087 ",failures," before=",before," after=",after)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)

func click_result_back()->bool:
	for button in buttons(main.screen):
		if button.text!="返回营地":continue
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=button.get_global_rect().get_center()
		root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
		return true
	return false
