extends SceneTree
const Probe = preload("res://tests/profiler083.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder=""
	var seconds=60.0
	var omit="none"
	var no_vsync=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--seconds="): seconds=clampf(float(arg.trim_prefix("--seconds=")),10,90)
		if arg.begins_with("--omit="): omit=arg.trim_prefix("--omit=")
		if arg=="--no-vsync": no_vsync=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	state.profile.region=2
	state.profile.renown=60
	state.profile.equipped.merge({"armor":"de_armor_5","helmet":"de_helmet_5","shield":"de_shield_5","lance":"de_lance_stout_5","horse":"horse_courser","caparison":"caparison_velvet","crest":"crest_bend"},true)
	root.size=Vector2i(1280,720)
	if no_vsync: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	root.add_child(preload("res://scripts/core/window_activity.gd").new())
	var b=load("res://tests/profile_battle083.gd").new()
	b.autoplay=true
	b.demo_seed=8217
	b.practice=false
	root.add_child(b)
	if root.focus_exited.is_connected(b._on_focus_lost): root.focus_exited.disconnect(b._on_focus_lost)
	if omit=="rider_draw":
		for rider in b.riders: rider.suppress_draw=true
	if omit=="pixel_shader":
		for rider in b.riders: rider.material=null
	await create_timer(2,true,false,true).timeout
	Probe.totals.clear()
	Probe.enabled=true
	var rows: Array=[]
	var gaps: Array[float]=[]
	var started=Time.get_ticks_usec()
	var last=started
	var next_sample=0.0
	while (Time.get_ticks_usec()-started)/1000000.0<seconds:
		await process_frame
		var now=Time.get_ticks_usec()
		gaps.append((now-last)/1000.0)
		last=now
		var elapsed=(now-started)/1000000.0
		if elapsed>=next_sample:
			next_sample+=.5
			rows.append({"seconds":elapsed,"phase":b.match_model.phase,"fps":Engine.get_frames_per_second(),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"render_setup_ms":RenderingServer.get_frame_setup_time_cpu(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"process":Performance.get_monitor(Performance.TIME_PROCESS),"physics":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)})
	Probe.enabled=false
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"omit":omit,"vsync":DisplayServer.window_get_vsync_mode(),"profile":Probe.totals,"samples":rows,"frame_ms":gaps,"scope":"Instrumented production Battle subclasses on isolated desktop; inclusive nested wall times, diagnostic omissions only, not release FPS proof."},"\t"))
	print("PROFILE083 ",omit," frames=",gaps.size())
	b.sound.stop_all()
	b.wind.stop()
	b.queue_free()
	await create_timer(.15,true,false,true).timeout
	quit()
