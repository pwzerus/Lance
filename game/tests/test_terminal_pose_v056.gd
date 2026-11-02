extends SceneTree
## Real Battle terminal transition, with explicit phase/clock fixtures. GPU
## captures, not OS play. Never writes or loads the player's normal profile.
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
var main: Node
var failures: Array[String] = []
var cases: Array = []
var captures: Array = []
var report_path = ""
var capture_dir = ""
var hoof_events = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func json_safe(value):
	if value is Vector2:
		return [value.x,value.y]
	if value is Dictionary:
		var row = {}
		for key in value:
			row[key] = json_safe(value[key])
		return row
	if value is Array:
		var rows = []
		for item in value:
			rows.append(json_safe(item))
		return rows
	return value

func snapshot(battle) -> Array:
	var rows: Array = []
	for view in battle.riders:
		var fighter: Dictionary = view.fighter
		# This is the body's actual production drawing input; the rules and
		# seated rider independently use Model.gait_pose/saddle_offset.
		var visual = Gait.body(view.stride_phase,float(fighter.speed),view.moving,float(fighter.stats.stability),float(fighter.get("motion_drive",0.0)))
		var legs: Array = []
		for pose in view.leg_poses:
			legs.append({"hip":pose.hip,"proximal":pose.proximal,"knee":pose.knee,"ankle":pose.ankle,"foot":pose.foot,"cycle":pose.cycle,"toe_angle":pose.toe_angle,"contact":pose.contact})
		rows.append({"direction":fighter.direction,"moving":view.moving,"gait_moving":fighter.gait_moving,"phase":fighter.gait_phase,"speed":fighter.speed,"position":view.position,"visual":visual,"model":Model.gait_pose(fighter),"saddle":Model.saddle_offset(fighter),"hand":Model.hand_position(fighter),"shield":Model.shield_position(fighter),"legs":legs})
	return rows

func pose_error(before: Array, after: Array) -> float:
	var maximum = 0.0
	for index in range(before.size()):
		var a: Dictionary = before[index]
		var b: Dictionary = after[index]
		for key in ["position","saddle","hand","shield"]:
			maximum = maxf(maximum,a[key].distance_to(b[key]))
		maximum = maxf(maximum,absf(float(a.phase)-float(b.phase)))
		for key in ["offset","rider_offset","neck_offset"]:
			maximum = maxf(maximum,a.visual[key].distance_to(b.visual[key]))
		for key in ["pitch","neck","rider_pitch","tail"]:
			maximum = maxf(maximum,absf(float(a.visual[key])-float(b.visual[key])))
		check(a.legs.size()==4 and b.legs.size()==4,"Both terminal riders keep four leg chains")
		for leg_index in range(mini(a.legs.size(),b.legs.size())):
			for key in ["hip","proximal","knee","ankle","foot"]:
				maximum = maxf(maximum,a.legs[leg_index][key].distance_to(b.legs[leg_index][key]))
	return maximum

func consistency_error(rows: Array) -> float:
	var maximum = 0.0
	for row in rows:
		check(row.moving==row.gait_moving,"Terminal renderer and model agree on gait participation")
		for key in ["offset","rider_offset","neck_offset"]:
			maximum = maxf(maximum,row.visual[key].distance_to(row.model[key]))
		for key in ["pitch","neck","rider_pitch","tail"]:
			maximum = maxf(maximum,absf(float(row.visual[key])-float(row.model[key])))
		maximum = maxf(maximum,(row.visual.offset+row.visual.rider_offset).distance_to(row.saddle))
	return maximum

func capture(name: String, rows: Array) -> void:
	await RenderingServer.frame_post_draw
	var path = capture_dir+"/"+name+".png"
	var error = root.get_texture().get_image().save_png(path)
	check(error==OK,"Terminal screenshot saves")
	captures.append({"path":path,"rows":rows,"result_visible":main.result_visible})

func run_case(cycle: float) -> void:
	main._start_match("arena",true)
	var battle = main.battle
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	battle.sound.music.stop()
	battle.exchange_director.reset(1)
	battle.exchange_state = battle.exchange_director.sample()
	battle.contact_first_frame_pending = false
	battle.contact_audio.clear()
	var model = battle.match_model
	model.phase = "charge"
	model.drain_events()
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		fighter.x = -440.0 if index==0 else 440.0
		fighter.speed = 480.0
		fighter.gait_phase = TAU*cycle
		fighter.gait_moving = true
		fighter.motion_drive = 0.0
		fighter.acted = true
		fighter.aim = -.08
		fighter.lean = 0.0
		fighter.guard = .43
		model._cache_pose(fighter)
		battle.riders[index].set_process(false)
	battle._update_views()
	for view in battle.riders:
		view._process(0.0)
	model._finish("passes")
	battle._consume_events(model.drain_events())
	# Do not mutate is_finished. Backdate only the documented presentation
	# clock, leaving the production _process responsible for the transition.
	# The fixture keeps departure_elapsed=0 so riders remain at panel edges.
	battle.terminal_at = Time.get_ticks_msec()-2701
	for tick in range(60):
		battle._update_camera(1.0/60.0,Time.get_ticks_msec())
	var before = snapshot(battle)
	check(not battle.is_finished,"Terminal fixture begins before results")
	var tag = "cycle_%03d" % roundi(cycle*100)
	await capture(tag+"_before",before)
	battle.last_visual_time = Time.get_ticks_msec()
	battle._process(0.0)
	for view in battle.riders:
		view._process(0.0)
	var after = snapshot(battle)
	check(battle.is_finished,"Production Battle._process enters results")
	var transition_error = pose_error(before,after)
	var agreement_error = consistency_error(after)
	check(transition_error<.03,"Results cannot snap a frozen horse or rider into standing geometry")
	check(agreement_error<.03,"Visible horse body and model saddle remain coincident after results")
	await capture(tag+"_after",after)
	hoof_events = 0
	for view in battle.riders:
		view.hoof_contact.connect(func(_leg_index: int): hoof_events += 1)
	var maximum_drift = 0.0
	for frame in range(60):
		battle._process(1.0/60.0)
		for view in battle.riders:
			view._process(1.0/60.0)
		maximum_drift = maxf(maximum_drift,pose_error(after,snapshot(battle)))
		await process_frame
	check(maximum_drift<.03,"Finished rider leg continuation cannot drift at frozen phase")
	check(hoof_events==0,"Frozen result horses do not emit new landings")
	main._process(0.0)
	check(main.result_visible,"Production Main displays the result panel")
	await capture(tag+"_result",snapshot(battle))
	cases.append({"cycle":cycle,"transition_error":transition_error,"model_visual_agreement_error":agreement_error,"frozen_60_frame_maximum_drift":maximum_drift,"frozen_hoof_events":hoof_events,"before":before,"after":after})
	main._close_battle()
	await process_frame

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		if argument.begins_with("--captures="): capture_dir = argument.trim_prefix("--captures=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Terminal pose test requires GPU and -- --test-profile")
		quit(2)
		return
	if report_path.is_empty() or capture_dir.is_empty() or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(capture_dir):
		push_error("Provide fresh --report and --captures paths")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(capture_dir)
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.settings.shake = false
	state.profile.settings.slow_motion = false
	root.size = Vector2i(1280,720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	# Keep terminal_at positive even when using a fast import cache.
	while Time.get_ticks_msec()<3000:
		await process_frame
	for cycle in [.45,.85]:
		await run_case(cycle)
	main.queue_free()
	await process_frame
	var report = {"passed":failures.is_empty(),"failures":failures,"cases":cases,"captures":captures,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"scope":"Actual Battle end event/_process and Main.show_result, two fixed phases and both facings; backdated presentation clock and fixed side positions are explicit fixtures, no actual scoring simulation or OS input. Recoil zero to isolate freeze consistency. Render captures and 60 process frames per phase, not real-time FPS or human naturalness approval."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write terminal pose report")
		quit(2)
		return
	file.store_string(JSON.stringify(json_safe(report),"\t"))
	file.close()
	print("TERMINAL_POSE_V056 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
