extends SceneTree
## External old/new package driver. Includes synchronous creation and first frames.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless": quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.region=2
	state.profile.renown=60
	state.profile.equipped.merge({"armor":"de_armor_5","helmet":"de_helmet_5","shield":"de_shield_5","lance":"de_lance_stout_5","horse":"horse_courser","caparison":"caparison_velvet","crest":"crest_bend"},true)
	state.profile.settings.sound=true
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate()
	main.smoke_mode=true
	root.add_child(main)
	current_scene=main
	main.set_process(false)
	await create_timer(2,true,false,true).timeout
	var rows=[]
	for cycle in range(5):
		for action in ["battle","home","armory","home"]:
			await process_frame
			var started=Time.get_ticks_usec()
			match action:
				"battle": main._start_match("arena",false)
				"home":
					main._close_battle()
					main.show_home()
				"armory": main.show_armory()
			var sync_ms=(Time.get_ticks_usec()-started)/1000.0
			if action=="battle" and root.focus_exited.is_connected(main.battle._on_focus_lost): root.focus_exited.disconnect(main.battle._on_focus_lost)
			var gaps=[]
			var previous=started
			for frame in range(8):
				await process_frame
				var now=Time.get_ticks_usec()
				gaps.append((now-previous)/1000.0)
				previous=now
			rows.append({"cycle":cycle,"action":action,"sync_ms":sync_ms,"first_frames_ms":gaps,"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
			await create_timer(.4,true,false,true).timeout
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"rows":rows,"scope":"Actual rendering, same external old/new driver, transitions including creation; no OS input."},"\t"))
	print("TRANSITION084 complete")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
