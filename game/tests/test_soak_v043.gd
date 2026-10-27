extends SceneTree
var main: Node
var state: Node
var failures: Array[String] = []
var rows: Array = []
var started = 0
var capture_dir = "E:/GALUMU/docs/development/screenshots/v043/soak/"
var report_path = "E:/GALUMU/docs/development/logs/v043/soak.json"
var round_count = 12

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="):
			round_count = clampi(int(arg.trim_prefix("--rounds=")),1,30)
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")+"/"
	state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.save_path = "user://qa_v043_soak.json"
	state.backup_path = "user://qa_v043_soak.backup.json"
	state.profile = state.default_profile()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	started = Time.get_ticks_msec()
	var initial_orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var expected_matches = 0
	for round_index in range(round_count):
		state.profile.settings.difficulty = round_index%3
		state.profile.settings.blood = round_index%2==1
		state.profile.settings.sound = round_index%4!=0
		state.profile.settings.slow_motion = round_index%4!=2
		state.profile.settings.aim_cues = round_index%4!=3
		var practice = round_index in [3,8]
		var mode_value = "arena" if round_index%2==0 else "war"
		main._start_match(mode_value,practice)
		main.battle.autoplay = true
		main.battle.guard_slot = round_index%3
		main.battle.match_model.rng.seed = 43000+round_index
		main.battle.ai_rng.seed = 53000+round_index
		var round_started = Time.get_ticks_msec()
		var sampled_fps: Array = []
		var sample_at = round_started+3000
		while not main.result_visible and Time.get_ticks_msec()-round_started<90000:
			await process_frame
			if Time.get_ticks_msec()>=sample_at:
				sample_at += 1000
				sampled_fps.append(Engine.get_frames_per_second())
		if not main.result_visible:
			failures.append("Match timed out: "+str(round_index))
			break
		if not practice:
			expected_matches += 1
		if int(state.profile.matches)!=expected_matches:
			failures.append("Career/practice award count mismatch: "+str(round_index))
		if Engine.time_scale!=1.0 or paused:
			failures.append("Terminal global state remained slowed/paused")
		var result = main.pending_result.duplicate(true)
		var hits = main.battle.exchange_log.size()
		if round_index in [0,round_count-1]:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(capture_dir)
			root.get_texture().get_image().save_png(capture_dir+"result_"+str(round_index)+".png")
		main._close_battle()
		main.show_home()
		await process_frame
		await process_frame
		await create_timer(.4,true,false,true).timeout
		var row = {"match":round_index+1,"mode":mode_value,"practice":practice,"difficulty":round_index%3,"seconds":(Time.get_ticks_msec()-round_started)/1000.0,"hits":hits,"result":result,"fps":sampled_fps,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
		rows.append(row)
		if row.orphans>initial_orphans:
			failures.append("Orphan nodes accumulated after closing match "+str(round_index+1))
		if rows.size()>2 and float(row.nodes)>float(rows[1].nodes)+12:
			failures.append("Scene nodes grew beyond bounded audio voice pool")
		print("SOAK_PROGRESS ",round_index+1,"/",round_count," seconds=",row.seconds," nodes=",row.nodes," orphans=",row.orphans," memory=",row.memory_bytes)
	state.save_profile()
	var report = {"passed":failures.is_empty() and rows.size()==round_count,"failures":failures,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"rows":rows,"scope":"rendered automated matches with audio, difficulty/blood/cues/slow-motion toggles and scene teardown; not human play"}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("SOAK_V043 ",report.passed," rounds=",rows.size()," seconds=",report.wall_seconds," failures=",failures)
	main.queue_free()
	await process_frame
	await create_timer(.4,true,false,true).timeout
	quit(0 if report.passed else 1)
