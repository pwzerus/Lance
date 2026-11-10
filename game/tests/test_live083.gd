extends SceneTree
## Same external driver for the old and new packaged game. No captures while
## timing; warmed per-frame timings retain contact/turn phase and stutter tails.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder=""
	var seconds=150.0
	var sync="project"
	var mode="arena"
	var practice=true
	var sound=false
	var geometry_only=false
	var elite=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--seconds="): seconds=clampf(float(arg.trim_prefix("--seconds=")),30,240)
		if arg.begins_with("--sync="): sync=arg.trim_prefix("--sync=")
		if arg=="--war": mode="war"
		if arg=="--competitive": practice=false
		if arg=="--sound": sound=true
		if arg=="--geometry-only": geometry_only=true
		if arg=="--elite": elite=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or (DisplayServer.get_name()=="headless" and not geometry_only):
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=sound
	if elite:
		state.profile.region=2
		state.profile.renown=60
		var selected={}
		for item in state.items:
			var slot=str(item.get("slot",""))
			if slot not in state.profile.equipped or str(item.get("region","")) not in ["德意志","欧洲共通"]: continue
			if not selected.has(slot) or int(item.get("price",0))>int(selected[slot].get("price",0)): selected[slot]=item
		for slot in selected:
			state.profile.equipped[slot]=selected[slot].id
			if selected[slot].id not in state.profile.owned: state.profile.owned.append(selected[slot].id)
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate()
	main.smoke_mode=true
	root.add_child(main)
	current_scene=main
	main.set_process(false)
	if sync!="project": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if sync=="off" else DisplayServer.VSYNC_ENABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await create_timer(3,true,false,true).timeout
	if elite and not geometry_only:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/loadout.png")
	main._start_match(mode,practice)
	if root.focus_exited.is_connected(main.battle._on_focus_lost): root.focus_exited.disconnect(main.battle._on_focus_lost)
	var started=Time.get_ticks_usec()
	var last=started
	var warm_until=started+1000000
	var next_sample=0.0
	var previous_phase="ready"
	var matches=0
	var rows: Array=[]
	var phases: Dictionary={}
	var frame_ms: Array[float]=[]
	var all_frame_ms: Array[float]=[]
	while (Time.get_ticks_usec()-started)/1000000.0<seconds:
		await process_frame
		var now=Time.get_ticks_usec()
		var ms=(now-last)/1000.0
		last=now
		all_frame_ms.append(ms)
		if now>warm_until:
			frame_ms.append(ms)
			if not phases.has(previous_phase): phases[previous_phase]=[]
			phases[previous_phase].append(ms)
		var b=main.battle
		if b.is_finished:
			matches+=1
			main._start_match(mode,practice)
			b=main.battle
			if root.focus_exited.is_connected(b._on_focus_lost): root.focus_exited.disconnect(b._on_focus_lost)
			warm_until=now+1000000
		previous_phase=b.match_model.phase
		if bool(b.exchange_state.get("impact_active",false)): previous_phase="contact"
		var elapsed=(now-started)/1000000.0
		if elapsed>=next_sample:
			next_sample+=.5
			rows.append({"seconds":elapsed,"phase":previous_phase,"fps":Engine.get_frames_per_second(),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"draws":Engine.get_frames_drawn(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	var summaries: Dictionary={}
	for key in phases: summaries[key]=stats(phases[key])
	var result={"version":ProjectSettings.get_setting("application/config/version"),"mode":mode,"practice":practice,"sound":sound,"requested_sync":sync,"actual_sync":DisplayServer.window_get_vsync_mode(),"matches":matches,"frame_summary":stats(frame_ms),"all_frame_summary":stats(all_frame_ms),"phases":summaries,"samples":rows,"frame_ms":frame_ms,"scope":"Actual EXE/PCK, 1280x720, CPU25%/memory protection, isolated desktop, ordinary autopilot, first second after each creation excluded from warmed percentiles only (all_frame_summary retains transitions). No human/foreground/tearing acceptance."}
	result.executable=OS.get_executable_path()
	result.equipped=state.profile.equipped.duplicate()
	result.elite=elite
	result.scope="1280x720, CPU25%/memory protection, isolated rendering, ordinary autopilot. Warmed percentiles exclude first second after creation; all_frame_summary retains transitions. Check executable/launch command for source engine vs EXE/PCK. No OS input/human/foreground acceptance."
	if geometry_only:
		result.scope="HEADLESS GEOMETRY ONLY. No GPU/frame-rate acceptance. Ordinary match with polygon probe."
		result.inspected_polygons=load("res://tests/polygon_probe083.gd").inspected
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LIVE083 ",JSON.stringify(result.frame_summary)," matches=",matches," sync=",result.actual_sync)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var ordered=values.duplicate()
	ordered.sort()
	var total=0.0
	var over_30=0
	var over_50=0
	for value in values:
		total+=float(value)
		if float(value)>33.334: over_30+=1
		if float(value)>50.0: over_50+=1
	return {"frames":values.size(),"fps":values.size()*1000.0/total,"p50_ms":ordered[int((ordered.size()-1)*.5)],"p95_ms":ordered[int((ordered.size()-1)*.95)],"p99_ms":ordered[int((ordered.size()-1)*.99)],"max_ms":ordered[-1],"over_33ms":over_30,"over_50ms":over_50}
