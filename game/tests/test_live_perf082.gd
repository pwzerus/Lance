extends SceneTree
## Wall-clock frame sampling of the actual packaged Main/Battle, no screenshots.
## Use the SAME external script/arguments with old/new PCKs for comparison.
var folder=""
var seconds=150.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--seconds="): seconds=clampf(float(arg.trim_prefix("--seconds=")),30,300)
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate()
	main.smoke_mode=true # Fixed production demo seed and existing autopilot.
	root.add_child(main)
	current_scene=main
	main.set_process(false) # No screenshot smoke sequencer; Battle stays live.
	await create_timer(5,true,false,true).timeout
	var rows: Array=[]
	var matches=0
	var started=Time.get_ticks_msec()
	main._start_match("arena",true)
	if root.focus_exited.is_connected(main.battle._on_focus_lost): root.focus_exited.disconnect(main.battle._on_focus_lost)
	while (Time.get_ticks_msec()-started)/1000.0<seconds:
		var b=main.battle
		if b.is_finished:
			matches+=1
			main._start_match("arena",true)
			if root.focus_exited.is_connected(main.battle._on_focus_lost): root.focus_exited.disconnect(main.battle._on_focus_lost)
			b=main.battle
		rows.append({"seconds":(Time.get_ticks_msec()-started)/1000.0,"match":matches,"phase":b.match_model.phase,"gap":b.match_model.fighters[1].x-b.match_model.fighters[0].x,"fps":Engine.get_frames_per_second(),"frames":Engine.get_frames_drawn(),"process_seconds":Performance.get_monitor(Performance.TIME_PROCESS),"physics_seconds":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"static_bytes":OS.get_static_memory_usage(),"time_scale":Engine.time_scale})
		await create_timer(.5,true,false,true).timeout
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":matches>=1,"version":ProjectSettings.get_setting("application/config/version"),"matches_completed":matches,"samples":rows,"scope":"Actual wall-clock rendering at 1280x720 on isolated desktop, fixed seed, ordinary practice autopilot, CPU25% protector, no screenshot work. Host load and throttling still affect FPS."},"\t"))
	print("LIVE_PERF082 version=",ProjectSettings.get_setting("application/config/version")," complete_matches=",matches)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
