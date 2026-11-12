extends SceneTree
## COMM-087 native transitions after a real two-second warmup.
## --no-prewarm substitutes ONLY the four menu prewarm jobs; no rider probes.
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
	var main=load("res://tests/profile_main088.gd").new()
	main.smoke_mode=true
	root.add_child(main)
	current_scene=main
	main.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var warm_start=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm_start<2000000: await process_frame
	var warm_seconds=(Time.get_ticks_usec()-warm_start)/1000000.0
	var rows=[]
	for cycle in range(3):
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
			rows.append({"cycle":cycle,"action":action,"sync_ms":sync_ms,"first_frames_ms":gaps,"costs":main.battle.cost.duplicate() if main.battle else {},"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
			await create_timer(.4,true,false,true).timeout
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"rows":rows,"warm_seconds":warm_seconds,"no_prewarm":"--no-prewarm" in OS.get_cmdline_user_args(),"scope":"Actual rendering, same external old/new driver, transitions including creation; no OS input."},"\t"))
	print("TRANSITION087 complete warm_seconds=",warm_seconds)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
