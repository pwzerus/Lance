extends "test_gui082.gd"
## Actual menu hit testing, display-setting migration/persistence and layout.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	var legacy=state.profile.duplicate(true)
	legacy.settings.erase("vsync")
	check(not state.sanitize(legacy).settings.vsync,"Old save does not migrate to capped unsynchronized display")
	legacy.settings.vsync=true
	check(state.sanitize(legacy).settings.vsync,"Explicit sync preference was lost")
	legacy.settings.vsync="false"
	check(not state.sanitize(legacy).settings.vsync,"Invalid sync value was accepted")
	root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await capture("home_1280")
	check(DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"Default display sync remains blocking")
	for action in buttons(main):
		var area=action.get_global_rect()
		check(Rect2(0,0,1440,810).encloses(area),"Home button outside screen: "+action.text)
	root.size=Vector2i(960,540)
	await capture("home_960")
	click_text("练习场")
	await process_frame
	check(is_instance_valid(main.brief_overlay),"Camp practice skipped first-time instructions")
	click_text("返回选择")
	await process_frame
	check(main.page=="home" and not is_instance_valid(main.brief_overlay),"Practice cancel did not restore camp")
	click_text("设置")
	await process_frame
	click_text("垂直同步 · 撕裂时开启")
	await process_frame
	check(state.profile.settings.vsync and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_ENABLED,"Sync switch did not apply")
	var disk=JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	check(disk is Dictionary and disk.settings.vsync,"Sync preference was not saved")
	state.load_profile()
	check(state.profile.settings.vsync,"Saved sync preference did not reload")
	await capture("settings_sync")
	click_text("垂直同步 · 撕裂时开启")
	await process_frame
	check(not state.profile.settings.vsync and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"Sync switch did not release wait")
	click_text("返回营地")
	await process_frame
	state.profile.renown=999999999
	state.profile.matches=999999999
	state.profile.wins=999999999
	for region in range(4):
		state.profile.region=region
		main.show_home()
		await capture("veteran_"+str(region))
		for row in labels(main.screen):
			check(row.x+row.w<=1441 and row.y+row.h<=811,"Home label overflow: "+row.text)
	click_text("练习场")
	await process_frame
	click_text("明白了，出战")
	await process_frame
	check(main.page=="battle" and main.practice_match,"Camp practice did not start a practice match")
	if root.focus_exited.is_connected(main.battle._on_focus_lost): root.focus_exited.disconnect(main.battle._on_focus_lost)
	main.battle.set_physics_process(false)
	main._close_battle()
	main.show_home()
	await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Isolated GPU, actual viewport click path, QA save migration/reload and four regions with extreme progress; no OS input."},"\t"))
	print("HOME083 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
