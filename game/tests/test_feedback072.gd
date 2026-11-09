extends "test_impact_v057.gd"
## FEEL-072: retains the v058 live GPU checks; finite travel now includes EQUIP-066 agility.
## Inherits real finite-command sweeps and first-frame loading, not fake hits.
## The separate batch/pause helper probe is explicitly labelled, never counted
## as a genuine two-rider simultaneous rule contact or OS-input evidence.
var shake_off = false
var prior_feedback: Dictionary = {}
var boundary_result: Dictionary = {}

func create_battle(mode_name: String, slow: bool):
	var battle = super.create_battle(mode_name,slow)
	root.get_node("GameState").profile.settings.shake = not shake_off
	prior_feedback.clear()
	return battle

func observe(battle, actor, elapsed: float) -> Dictionary:
	var row = super.observe(battle,actor,elapsed)
	var canvas: Transform2D = battle.world.get_global_transform_with_canvas()
	var offset: Vector2 = battle.camera.offset
	var screen_offset = canvas.basis_xform(offset)
	var envelope: Vector2 = battle._mounted_vertical_bounds()
	var top = canvas*Vector2(0,envelope.x-battle.world.position.y)
	var bottom = canvas*Vector2(0,envelope.y-battle.world.position.y)
	var safe: Rect2 = battle.combat_safe_rect()
	var projected: Array = []
	var model_time = float(battle.match_model.time_elapsed)
	for index in range(2):
		var fighter: Dictionary = battle.match_model.fighters[index]
		var pose: Dictionary = Rider057.arm_pose(fighter)
		var head = canvas*Model.head_position(fighter)
		var grip = canvas*Model.hand_position(fighter)
		var shield = canvas*Model.shield_position(fighter)
		var shield_grip = canvas*Vector2(pose.shield_grip)
		var drawn_grip = canvas*Vector2(pose.right.hand)
		var drawn_shield = canvas*Vector2(pose.shield_center)
		var drawn_shield_grip = canvas*Vector2(pose.left.hand)
		check(grip.distance_to(drawn_grip)<.02 and shield.distance_to(drawn_shield)<.02 and shield_grip.distance_to(drawn_shield_grip)<.02,"Feedback camera separated drawn lance/shield grips from their shared rule pose",{"fighter":index,"state":row.state.state})
		var item = {"fighter":index,"direction":fighter.direction,"tip":point_row(canvas*Model.tip_position(fighter)),"head":point_row(head),"shield":point_row(shield),"lance_grip":point_row(grip),"shield_grip":point_row(shield_grip),"drawn_lance_grip":point_row(drawn_grip),"drawn_shield":point_row(drawn_shield),"drawn_shield_grip":point_row(drawn_shield_grip),"aim":fighter.aim,"guard":fighter.guard}
		if not prior_feedback.is_empty():
			var dt = maxf(0,model_time-float(prior_feedback.model_time))
			var old: Dictionary = prior_feedback.projected[index]
			# This is a conservative legal control rate across a rendered interval;
			# the inherited staging separately checks the stricter committed rate.
			item["aim_travel"] = absf(float(fighter.aim)-float(old.aim))
			item["guard_travel"] = absf(float(fighter.guard)-float(old.guard))
			item["game_interval"] = dt
			check(float(item.aim_travel)<=2.2*dt*float(fighter.stats.get("lance_handling",1))*Model.Condition.agility(fighter.stats)+.0002,"Contact feedback teleported the commanded lance angle",item)
			check(float(item.guard_travel)<=2.8*dt*float(fighter.stats.get("shield_handling",1))*Model.Condition.agility(fighter.stats)+.0002,"Contact feedback teleported the shield guard",item)
		projected.append(item)
	var feedback = {"zoom":battle.camera.zoom.x,"offset_world":point_row(offset),"offset_screen_px":point_row(screen_offset),"offset_screen_length":screen_offset.length(),"camera_impact_age":battle.camera_impact_age,"envelope_top_y":top.y,"envelope_bottom_y":bottom.y,"safe_top_y":safe.position.y,"safe_bottom_y":safe.end.y,"model_time":model_time,"projected":projected,"logical_viewport":point_row(root.get_visible_rect().size),"shake_enabled":not shake_off}
	check(top.y>=safe.position.y-.1 and bottom.y<=safe.end.y+.1,"Contact zoom/shake put the mounted vertical envelope into the HUD",feedback)
	if shake_off:
		check(offset==Vector2.ZERO,"Shake disabled still produced a rendered camera offset",feedback)
	row["feedback"] = feedback
	prior_feedback = feedback
	return row

func summarize_feedback(summary: Dictionary) -> void:
	var before: Dictionary = {}
	var all_rows: Array = []
	for capture_row in captures:
		if capture_row.get("case","")==summary.name:
			all_rows.append(capture_row)
			if capture_row.tag=="before": before = capture_row
	all_rows.append_array(summary.timeline)
	check(not before.is_empty(),"Feedback fixture lacks a rendered pre-contact camera baseline",{"case":summary.name})
	if before.is_empty(): return
	var baseline_zoom = float(before.feedback.zoom)
	var peak_contact_zoom = baseline_zoom
	var peak_shake = 0.0
	var read_start = -1.0
	var read_end = -1.0
	var read_max_scale = 0.0
	var read_min_scale = 1.0
	var max_frame_gap = 0.0
	var previous_wall = -1.0
	var restored = false
	for row in all_rows:
		if row.state.state in ["contact","read"]:
			peak_contact_zoom = maxf(peak_contact_zoom,float(row.feedback.zoom))
		peak_shake = maxf(peak_shake,float(row.feedback.offset_screen_length))
	# Only the live timeline measures duration. Staged snapshots intentionally
	# have elapsed=0 and cannot be treated as additional measured frames.
	for row in summary.timeline:
		var wall = float(row.wall_seconds)
		if previous_wall>=0: max_frame_gap = maxf(max_frame_gap,wall-previous_wall)
		previous_wall = wall
		if row.state.state=="read":
			if read_start<0: read_start = wall-float(row.state.stage_elapsed)
			read_max_scale = maxf(read_max_scale,float(row.state.scale))
			read_min_scale = minf(read_min_scale,float(row.state.scale))
		elif read_start>=0 and read_end<0:
			# release.stage_elapsed includes the overshoot of the transition.
			read_end = wall-float(row.state.stage_elapsed) if row.state.state=="release" else wall
		if row.state.state in ["cross","runup"] and is_equal_approx(float(row.engine_scale),1.0): restored = true
	var zoom_gain = peak_contact_zoom/maxf(.001,baseline_zoom)-1.0
	var read_duration = read_end-read_start if read_end>=0 and read_start>=0 else -1.0
	var strength = 0.0
	for event in summary.actual_events: strength = maxf(strength,Exchange.contact_strength(event))
	var metrics = {"pre_contact_zoom":baseline_zoom,"contact_read_peak_zoom":peak_contact_zoom,"zoom_gain_fraction":zoom_gain,"peak_shake_screen_px":peak_shake,"read_observed_start":read_start,"read_observed_end":read_end,"read_duration_seconds":read_duration,"read_min_scale":read_min_scale,"read_max_scale":read_max_scale,"max_render_interval_seconds":max_frame_gap,"restored_scale_one":restored,"actual_contact_strength":strength,"shake_disabled":shake_off}
	summary["feedback_summary"] = metrics
	if strength>=.70:
		check(zoom_gain>=.18,"Strong swept contact did not add at least 18 percent zoom",{"case":summary.name,"feedback":metrics})
		if not shake_off: check(peak_shake>=10.0,"Strong swept contact never reached 10 logical screen pixels of shake",{"case":summary.name,"feedback":metrics})
	if summary.slow_motion:
		check(read_start>=0 and read_end>=0 and read_max_scale<=.32,"Actual swept contact did not display the slower read stage",{"case":summary.name,"feedback":metrics})
		check(absf(read_duration-.28)<=.045,"Rendered read stage did not retain approximately .28 seconds of wall time",{"case":summary.name,"feedback":metrics})
	else:
		check(read_start<0,"Slow-motion disabled still displayed the read stage",{"case":summary.name,"feedback":metrics})
	check(restored,"Feedback did not restore normal time within the observed contact sequence",{"case":summary.name,"feedback":metrics})

func live_case(attacker: int, zone: String, fatal: bool, slow: bool, solid: bool = false, broken_fixture: bool = false) -> void:
	var old_size = cases.size()
	await super.live_case(attacker,zone,fatal,slow,solid,broken_fixture)
	if cases.size()>old_size: summarize_feedback(cases[-1])

func reset_impulse_probe(battle) -> void:
	battle.camera_impact_age = 0.0
	battle.camera_impact_strength = -1.0
	battle.camera_impact_attacker = 2147483647
	battle.shake = 0.0
	battle.impact_kick = Vector2.ZERO

func batch_and_pause_probe(source_event: Dictionary) -> void:
	var battle = create_battle("arena",true)
	stage_model(battle.match_model,0,"body",false,.55)
	battle.match_model.fighters[0].x = -150
	battle.match_model.fighters[1].x = 150
	battle._update_views()
	for view in battle.riders: view._process(0.0)
	for tick in range(90): battle._update_camera(1.0/60.0,Time.get_ticks_msec())
	var first = source_event.duplicate(true)
	var second = source_event.duplicate(true)
	first.attacker = 0
	second.attacker = 1
	var close_first = first.duplicate(true)
	var close_second = second.duplicate(true)
	# Synthetic strength boundary only: strict less-than must not conflict
	# with approximate equality when determining the dominant direction.
	close_first.speed = 900.0
	close_first.impulse = 63.75
	close_first.glanced = false
	close_second.speed = 900.0
	close_second.impulse = 63.750085
	close_second.glanced = false
	var samples: Array = []
	for group in [[first],[first,second],[second,first],[close_first,close_second],[close_second,close_first]]:
		reset_impulse_probe(battle)
		battle._load_camera_impulse(group)
		var value: Vector2 = battle._contact_camera_offset()*battle.camera.zoom.x
		samples.append({"offset_px":point_row(value),"magnitude":value.length(),"attacker":battle.camera_impact_attacker,"age":battle.camera_impact_age})
	check(Vector2(samples[1].offset_px[0],samples[1].offset_px[1]).distance_to(Vector2(samples[2].offset_px[0],samples[2].offset_px[1]))<.0001,"Opposite contact batch changed its camera impulse with event ordering",{"samples":samples})
	check(int(samples[3].attacker)==int(samples[4].attacker) and Vector2(samples[3].offset_px[0],samples[3].offset_px[1]).distance_to(Vector2(samples[4].offset_px[0],samples[4].offset_px[1]))<.0001,"Nearly equal opposite contacts changed dominant camera impulse with event ordering",{"forward":samples[3],"reverse":samples[4]})
	if not shake_off:
		check(float(samples[1].magnitude)>=10 and float(samples[1].magnitude)>=float(samples[0].magnitude)*.95,"Opposite contact batch cancelled the dominant camera impulse",{"samples":samples})
	else:
		for sample in samples: check(is_zero_approx(float(sample.magnitude)),"Shake-off helper emitted an impulse",sample)
	# Exercise the production pause gate, with the battle manually driven so
	# this independent boundary probe cannot advance a rule contact by accident.
	battle.camera_impact_age = .04
	battle.last_visual_time = Time.get_ticks_msec()
	battle._process(0)
	var before_age = float(battle.camera_impact_age)
	var before_offset: Vector2 = battle.camera.offset
	var before_helper: Vector2 = battle._contact_camera_offset()
	battle._toggle_pause()
	var waited = await wait_wall_msec(180)
	battle._process(0)
	var paused_age = float(battle.camera_impact_age)
	var paused_offset: Vector2 = battle.camera.offset
	check(is_equal_approx(before_age,paused_age) and before_offset==paused_offset,"Paused camera changed impulse age or displayed offset",{"before_age":before_age,"paused_age":paused_age,"before_offset":point_row(before_offset),"paused_offset":point_row(paused_offset)})
	battle._toggle_pause()
	var resumed_helper: Vector2 = battle._contact_camera_offset()
	check(before_helper.distance_to(resumed_helper)<.0001,"Resuming a paused impact jumped the vibration phase",{"before":point_row(before_helper),"resumed":point_row(resumed_helper)})
	battle._process(0)
	check(float(battle.camera_impact_age)-before_age<.025,"Resume consumed paused wall time as camera impulse age",{"before_age":before_age,"resume_age":battle.camera_impact_age})
	var resumed_age = float(battle.camera_impact_age)
	# A long actual render interval must expire the bounded feedback, even
	# though camera position interpolation may deliberately clamp its delta.
	battle.last_visual_time = Time.get_ticks_msec()-500
	battle._process(0)
	check(float(battle.camera_impact_age)>=.48 and battle.camera.offset==Vector2.ZERO,"A long unpaused render interval stretched the camera impulse beyond its wall-time budget",{"age":battle.camera_impact_age,"offset":point_row(battle.camera.offset)})
	boundary_result = {"scope":"Production impulse helper with mirrored copies of one recorded hit plus explicit near-equal synthetic strengths; not simultaneous rule collisions. Production pause/resume methods plus 180ms actual wall wait. A separate last_visual_time injection models a 500ms rendering interval. No OS input.","batch":samples,"pause_wall_msec":waited,"before_age":before_age,"paused_age":paused_age,"resumed_age":resumed_age,"before_offset":point_row(before_offset),"paused_offset":point_row(paused_offset),"resume_helper_error":before_helper.distance_to(resumed_helper),"long_frame_age":battle.camera_impact_age,"long_frame_offset":point_row(battle.camera.offset)}
	main._close_battle()
	await process_frame
	check(is_equal_approx(Engine.time_scale,1),"Closing feedback boundary probe left global time scaled")

func run() -> void:
	report_path = ""
	capture_dir = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
		if arg.begins_with("--cases="): case_limit = int(arg.trim_prefix("--cases="))
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
		if arg=="--no-captures": captures_enabled = false
		if arg=="--shake-off": shake_off = true
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("V058 feedback requires actual GPU scene and isolated --test-profile")
		quit(2)
		return
	if report_path.is_empty() or capture_dir.is_empty() or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(capture_dir):
		push_error("V058 requires explicit fresh --report and --captures paths")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	if captures_enabled: DirAccess.make_dir_recursive_absolute(capture_dir)
	state.profile = state.default_profile()
	state.profile.settings.sound = true
	state.profile.settings.shake = not shake_off
	original_master_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-60)
	root.size = Vector2i(1280,720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	var jobs = [[0,"body",false,true,false,false],[1,"head",false,true,false,false],[0,"shield",false,true,true,false],[1,"shield",false,true,true,false],[0,"shield",false,false,true,false]]
	if suite=="solid": jobs = [[0,"shield",false,true,true,false],[1,"shield",false,true,true,false]]
	for job in jobs:
		if case_limit>0 and cases.size()>=case_limit: break
		await live_case(job[0],job[1],job[2],job[3],job[4],job[5])
	if not cases.is_empty() and not cases[0].actual_events.is_empty():
		await batch_and_pause_probe(cases[0].actual_events[0])
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main._close_battle()
	main.queue_free()
	await process_frame
	for item in images:
		var error = item.image.save_png(item.path)
		check(error==OK,"Failed to save feedback screenshot",{"path":item.path,"error":error})
	images.clear()
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"suite":suite,"shake_disabled":shake_off,"cases":cases,"captures":captures,"boundary_probe":boundary_result,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"scope":"Inherits genuine Model sweeps and live Battle/GPU contact sequence from v057. Default: body, opposite-facing head, both solid shield directions, slow-off solid shield. --suite=solid selects the two shield directions. V058 records pre-hit versus contact/read zoom, logical screen-space shake, common-canvas tip/head/shield/grips, full mounted vertical HUD envelope and finite aim/guard travel. Batch/pause helper probe is separate synthetic mirrored metadata, not a simultaneous rule hit. --shake-off requires exact zero displayed offsets in every observed frame. PNG files written after live timing. No OS/human play, audio listening, physical-pixel alpha collision or subjective-feel approval."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FEEDBACK072 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
