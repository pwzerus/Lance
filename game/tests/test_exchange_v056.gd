extends "test_exchange_scene_v049.gd"
## Reuses the real swept-contact/first-frame/pause contracts from v049.
## Adds an engine-dispatched hold/release and run-up framing probe. Not OS input.
const CONTROL_DT = 1.0/60.0
var suite = "all"
var input_events: Array = []
var input_rows: Array = []
var ready_rows: Array = []

func capture(battle, case_name: String, stage: String, elapsed: float) -> void:
	# Input fixtures manually step physics with _process disabled. Refresh
	# its HUD and shadow draw before capturing that real scene, too.
	battle._update_hud()
	battle.queue_redraw()
	await super.capture(battle,case_name,stage,elapsed)

func active_contact_voice(bank) -> bool:
	# v049 predates material-specific cues. Check the production voice tag,
	# not equality to the obsolete generic impact/shield streams.
	for voice in bank.voices:
		if voice.has_stream_playback() and bank.is_contact_cue(str(voice.get_meta("sfx_cue",""))):
			return true
	return false

func projection(battle) -> Dictionary:
	var canvas: Transform2D = battle.world.get_global_transform_with_canvas()
	var viewport: Rect2 = root.get_visible_rect()
	var projected: Array = []
	for index in range(2):
		var fighter: Dictionary = battle.match_model.fighters[index]
		var facing = int(fighter.direction)
		var base = Vector2(float(fighter.x),float(fighter.lane_y))
		var left = canvas*(base+Vector2(-200,-350))
		var right = canvas*(base+Vector2(190,26))
		var tip = canvas*Model.tip_position(fighter)
		var hand = canvas*Model.hand_position(fighter)
		var pose: Dictionary = battle.riders[index].arm_pose(fighter)
		var origin: Vector2 = Model.mount_origin(fighter)
		var hand_local: Vector2 = (pose.right.hand-origin)*Vector2(facing,1)
		var visual_tip: Vector2 = battle.riders[index]._lance_surface_point(hand_local,float(fighter.aim),Model.lance_length(fighter),bool(fighter.broken),Model.lance_length(fighter))
		var drawn_tip = canvas*(origin+visual_tip*Vector2(facing,1))
		var error = drawn_tip.distance_to(tip)
		check(error<.02,"Production drawn lance endpoint lost rule/camera alignment",{"direction":facing,"error_px":error,"state":battle.exchange_state.state})
		check((canvas*Vector2(pose.right.hand)).distance_to(hand)<.02,"Production visible grip lost rule hand alignment")
		projected.append({"direction":facing,"x_min":left.x,"x_max":right.x,"tip":[tip.x,tip.y],"drawn_tip_error_px":error,"horse_in_x":left.x>=viewport.position.x and right.x<=viewport.end.x,"tip_in_view":viewport.has_point(tip)})
	return {"fighters":projected,"world_marker_x":(canvas*Vector2(-1200,80)).x,"camera_x":battle.camera.position.x,"zoom":battle.camera.zoom.x,"gap":float(battle.match_model.fighters[1].x)-float(battle.match_model.fighters[0].x)}

func frame_record(battle, elapsed: float) -> Dictionary:
	var row = super.frame_record(battle,elapsed)
	row["projection"] = projection(battle)
	return row

func dispatch(battle, event: InputEvent, label: String) -> void:
	# Dispatch through Godot's viewport, so Battle._input/_unhandled_input and
	# actual HUD consumption run. Keep the callbacks disabled between probes
	# to avoid interpreting unrelated desktop cursor motion as test commands.
	battle.set_process_input(true)
	battle.set_process_unhandled_input(true)
	root.push_input(event,true)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	input_events.append({"label":label,"type":event.get_class(),"wall_msec":Time.get_ticks_msec(),"engine_viewport_dispatch":true,"os_input":false,"mouse_held":battle.mouse_held,"pointer_aim":battle.pointer_aim,"guard_slot":battle.guard_slot})

func mouse_button(battle, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event = InputEventMouseButton.new()
	event.position = Vector2(900,440)
	event.button_index = button
	event.pressed = pressed
	dispatch(battle,event,("press" if pressed else "release")+"_"+str(button))

func ready_and_input_probe() -> void:
	var battle = create_battle("arena",true)
	var model = battle.match_model
	await process_frame
	var ready_seconds = 0.0
	while model.phase=="ready" and ready_seconds<3.0:
		model.step(CONTROL_DT)
		ready_seconds += CONTROL_DT
		battle._consume_events(model.drain_events())
		battle._update_views()
		for view in battle.riders: view._process(CONTROL_DT)
		battle._update_camera(CONTROL_DT,Time.get_ticks_msec())
		var row = projection(battle)
		row["seconds"] = ready_seconds
		row["phase_time"] = model.phase_time
		ready_rows.append(row)
		check(row.fighters[0].horse_in_x,"Ready-to-follow transition cropped the player horse",row)
		if ready_rows.size() in [1,80,150]:
			await capture(battle,"runup","ready_"+str(ready_rows.size()),ready_seconds)
		else:
			await process_frame
	check(model.phase=="charge" and is_zero_approx(float(model.fighters[0].speed)),"Ready countdown did not enter charge from rest")
	# Keep the opponent distant so hold/coast measurements stay in stable
	# follow framing. This is an explicit input fixture, not a normal match.
	model.fighters[1].x = 5500.0
	for fighter in model.fighters:
		fighter.acted = true
		fighter.stats.speed = 1.0
		model._cache_pose(fighter)
	var player: Dictionary = model.fighters[0]
	var target_angle = -.25
	var target_world = Model.hand_position(player)+Vector2(200,sin(target_angle)*Model.lance_length(player))
	var motion = InputEventMouseMotion.new()
	motion.position = battle.world.get_global_transform_with_canvas()*target_world
	motion.relative = Vector2(2,0)
	dispatch(battle,motion,"choose_aim_once")
	var pointer = float(battle.pointer_aim)
	check(absf(pointer-target_angle)<.02,"Viewport aim event failed to select the intended height")
	var speed_before_hold = 0.0
	var speed_at_release = 0.0
	var release_first_speed = 0.0
	var release_late_speed = 0.0
	var previous_marker = NAN
	var samples_by_stage: Dictionary = {"cruise":[],"hold":[],"coast":[]}
	for tick in range(360):
		var label = "cruise" if tick<120 else ("hold" if tick<240 else "coast")
		if tick==120:
			speed_before_hold = float(player.speed)
			mouse_button(battle,true)
		if tick==240:
			speed_at_release = float(player.speed)
			mouse_button(battle,false)
		var prior_x = float(player.x)
		var prior_aim = float(player.aim)
		var prior_guard = float(player.guard)
		battle._physics_process(CONTROL_DT)
		battle._update_camera(CONTROL_DT,Time.get_ticks_msec())
		battle._update_views()
		for view in battle.riders: view._process(CONTROL_DT)
		check(bool(player.boost)==(label=="hold"),"Dispatched left-button hold/release did not reach real Battle controls",{"tick":tick,"stage":label,"boost":player.boost,"mouse_held":battle.mouse_held})
		check(absf(float(player.aim)-prior_aim)<=2.2*CONTROL_DT*float(player.stats.get("lance_handling",1.0))+.0001,"Input probe teleported the lance")
		check(absf(float(player.guard)-prior_guard)<=2.8*CONTROL_DT*float(player.stats.get("shield_handling",1.0))+.0001,"Input probe teleported the shield")
		check(absf(float(player.x)-prior_x-float(player.speed)*CONTROL_DT)<.01,"Real speed and world displacement disagree")
		check(is_equal_approx(float(battle.pointer_aim),pointer),"Camera changed the committed stationary-pointer angle")
		if tick==240: release_first_speed = float(player.speed)
		if tick==359: release_late_speed = float(player.speed)
		var row = projection(battle)
		var flow = (float(row.world_marker_x)-previous_marker)/CONTROL_DT if is_finite(previous_marker) else 0.0
		previous_marker = float(row.world_marker_x)
		row.merge({"tick":tick,"simulated_seconds":(tick+1)*CONTROL_DT,"stage":label,"speed":player.speed,"boost":player.boost,"fixed_marker_screen_velocity":flow,"gait_phase":player.gait_phase,"aim":player.aim,"guard":player.guard})
		input_rows.append(row)
		if tick in [115,116,117,118,119,235,236,237,238,239,355,356,357,358,359]:
			samples_by_stage[label].append({"speed":player.speed,"marker_flow":flow})
		if tick in [119,239,359]:
			await capture(battle,"input",label,(tick+1)*CONTROL_DT)
		else:
			await process_frame
	check(speed_at_release>speed_before_hold*1.55,"Holding the mouse did not produce clearly greater actual speed",{"cruise":speed_before_hold,"hold":speed_at_release})
	check(release_first_speed<speed_at_release,"Releasing the mouse failed to begin deceleration on the next physics step")
	check(release_first_speed>Model.TROT_SPEED+50,"Release teleported the horse directly to cruise speed")
	check(release_late_speed<speed_at_release*.8,"Released spur retained most sprint speed after two seconds")
	var cruise_flow = average_field(samples_by_stage.cruise,"marker_flow")
	var sprint_flow = average_field(samples_by_stage.hold,"marker_flow")
	check(absf(sprint_flow)>absf(cruise_flow)*1.4,"Stable-camera world landmarks did not move meaningfully faster at sprint",{"cruise_flow":cruise_flow,"sprint_flow":sprint_flow})
	# An engine-dispatched late switch must update targets, never snap actual
	# aim/guard. Use a close but contact-disabled state on both directions.
	model.fighters[0].x = -450
	model.fighters[1].x = 450
	for fighter in model.fighters: model._cache_pose(fighter)
	battle._update_views()
	for view in battle.riders: view._process(0.0)
	for frame in range(45): battle._update_camera(CONTROL_DT,Time.get_ticks_msec())
	var before_guard = float(player.guard)
	mouse_button(battle,true,MOUSE_BUTTON_RIGHT)
	var before_aim = float(player.aim)
	var local_target = Model.hand_position(player)+Vector2(170,sin(.45)*Model.lance_length(player))
	motion = InputEventMouseMotion.new()
	motion.position = battle.world.get_global_transform_with_canvas()*local_target
	motion.relative = Vector2(2,1)
	dispatch(battle,motion,"late_change")
	check(absf(float(battle.pointer_aim)-.45)<.02,"Close-range viewport event missed its requested lance height")
	battle._physics_process(.016*.45)
	check(absf(float(player.aim)-before_aim)<=.95*.016*.45*float(player.stats.get("lance_handling",1.0))+.0001,"Viewport late-change input bypassed lance travel time")
	check(absf(float(player.guard)-before_guard)<=2.8*.016*.45*float(player.stats.get("shield_handling",1.0))+.0001,"Viewport late-change input bypassed shield travel time")
	check(absf(float(player.aim)-float(battle.pointer_aim))>.1,"Late lance change reached the full target in one physics step")
	check(absf(float(player.guard)-float(player.guard_target))>.1,"Late shield change reached the full target in one physics step")
	# Mirror the rate-boundary probe for the other direction as well. This
	# part is an explicit rule-control fixture, not a second mouse player.
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		var old_aim = float(fighter.aim)
		var old_guard = float(fighter.guard)
		var target = .58 if old_aim<0 else -.68
		model.set_controls(index,target,0,true,.016*.45,1.0 if old_guard<.5 else 0.0)
		check(absf(float(fighter.aim)-old_aim)<=.95*.016*.45*float(fighter.stats.get("lance_handling",1.0))+.0001,"Late slow-motion lance command teleported")
		check(absf(float(fighter.guard)-old_guard)<=2.8*.016*.45*float(fighter.stats.get("shield_handling",1.0))+.0001,"Late slow-motion shield command teleported")
	await input_safety_probe(battle)
	cases.append({"name":"ready_and_engine_hold_release","source":"real countdown, viewport-dispatched mouse events, manually stepped production Battle._physics_process; distant acted opponent is a fixture","cruise_speed":speed_before_hold,"sprint_speed":speed_at_release,"release_first_speed":release_first_speed,"coast_after_two_seconds":release_late_speed,"cruise_marker_flow":cruise_flow,"sprint_marker_flow":sprint_flow,"late_prior_aim":before_aim,"late_prior_guard":before_guard,"ready_samples":ready_rows,"input_timeline":input_rows})
	main._close_battle()
	await process_frame

func input_safety_probe(battle) -> void:
	var fighter: Dictionary = battle.match_model.fighters[0]
	mouse_button(battle,true)
	battle._physics_process(CONTROL_DT)
	check(fighter.boost,"Safety probe did not start from a held spur")
	battle._toggle_pause()
	var paused_x = float(fighter.x)
	battle._physics_process(.25)
	check(battle.paused and paused and not battle.mouse_held and float(fighter.x)==paused_x,"Pause failed to clear held input or freeze movement")
	await wait_wall_msec(90)
	battle._toggle_pause()
	battle._physics_process(CONTROL_DT)
	check(not fighter.boost,"Resume restarted a released mouse spur")
	mouse_button(battle,true)
	battle._physics_process(CONTROL_DT)
	battle._on_focus_lost()
	check(battle.paused and not battle.mouse_held and battle.touch_roles.is_empty(),"Focus-lost callback retained held spur or touch role")
	battle._toggle_pause()
	battle._physics_process(CONTROL_DT)
	check(not fighter.boost,"Focus recovery restarted the old spur")
	var hud_event = InputEventMouseButton.new()
	hud_event.button_index = MOUSE_BUTTON_LEFT
	hud_event.pressed = true
	hud_event.position = battle.guard_buttons[0].get_global_rect().get_center()
	dispatch(battle,hud_event,"hud_guard_press")
	battle._physics_process(CONTROL_DT)
	check(battle.ui_pointer_held and not battle.mouse_held and not fighter.boost,"Clicking the shield HUD also urged the horse")
	hud_event = hud_event.duplicate()
	hud_event.pressed = false
	dispatch(battle,hud_event,"hud_guard_release")
	battle._physics_process(CONTROL_DT)
	check(not battle.ui_pointer_held and not fighter.boost,"Releasing HUD input left spur state behind")
	cases.append({"name":"input_safety","source":"viewport-dispatched mouse; direct production pause/focus-lost handlers, not actual OS focus switching","paused_world_x":paused_x,"held_after_resume":battle.mouse_held,"boost_after_hud":fighter.boost})

func start_from_rest_probe() -> void:
	var battle = create_battle("arena",false)
	var model = battle.match_model
	model.phase = "charge"
	model.fighters[1].x = 5500.0
	for fighter in model.fighters:
		fighter.speed = 0.0
		fighter.acted = true
		fighter.stats.speed = 1.0
		model._cache_pose(fighter)
	var reference = Model.new("arena",{"speed":1.0},{"speed":1.0},5610)
	reference.phase = "charge"
	for fighter in reference.fighters: fighter.acted = true
	battle._update_views()
	for view in battle.riders: view._process(0.0)
	for frame in range(90): battle._update_camera(CONTROL_DT,Time.get_ticks_msec())
	await process_frame
	var origin_x = float(model.fighters[0].x)
	var reference_x = float(reference.fighters[0].x)
	var samples: Array = []
	var previous_speed = 0.0
	mouse_button(battle,true)
	for tick in range(120):
		battle._physics_process(CONTROL_DT)
		reference.set_controls(0,0,0,false,CONTROL_DT,.43)
		reference.step(CONTROL_DT)
		battle._update_camera(CONTROL_DT,Time.get_ticks_msec())
		battle._update_views()
		for view in battle.riders: view._process(CONTROL_DT)
		var speed = float(model.fighters[0].speed)
		check(speed>=previous_speed,"Held acceleration from rest reversed before top speed")
		if tick==0:
			check(speed>0 and speed<Model.TROT_SPEED*.1,"First held step was either unresponsive or an instant speed jump")
		previous_speed = speed
		if tick in [29,53,119]:
			var row = {"simulated_seconds":(tick+1)*CONTROL_DT,"held_speed":speed,"automatic_speed":reference.fighters[0].speed,"held_displacement":float(model.fighters[0].x)-origin_x,"automatic_displacement":float(reference.fighters[0].x)-reference_x}
			row["displacement_difference"] = float(row.held_displacement)-float(row.automatic_displacement)
			samples.append(row)
			check(float(row.held_speed)>float(row.automatic_speed),"Held-from-rest speed did not exceed automatic advance",row)
			check(float(row.displacement_difference)>0,"Held-from-rest displacement did not exceed automatic advance",row)
			await capture(battle,"from_rest","time_"+str(tick+1),(tick+1)*CONTROL_DT)
		else:
			await process_frame
	mouse_button(battle,false)
	check(float(model.fighters[0].speed)>=Model.GALLOP_SPEED*.95,"Two-second held spur did not approach the horse's configured sprint speed")
	cases.append({"name":"engine_held_from_rest","source":"viewport left-button press and real Battle physics from standstill; independent non-boosted model is the automatic-advance comparison","samples":samples,"interpretation":"0.5/0.9/2-second displacement differences are measured, not arbitrary acceptance thresholds or proof of good game feel"})
	main._close_battle()
	await process_frame

func average_field(rows: Array, field: String) -> float:
	var total = 0.0
	for row in rows: total += float(row[field])
	return total/maxi(1,rows.size())

func step_rules(battle, scaled_delta: float, kind: String) -> Array:
	var events: Array = super.step_rules(battle,scaled_delta,kind)
	var gap = float(battle.match_model.fighters[1].x)-float(battle.match_model.fighters[0].x)
	if gap>0 and gap<=1100 and battle.match_model.phase=="charge":
		# Camera is updated after rule stepping; allow a single physics step
		# of camera lag at the exact 1100 boundary by checking below 1080.
		if gap<=1080:
			var row = projection(battle)
			for fighter in row.fighters:
				check(fighter.horse_in_x,"Both horses are not visible inside the commitment region",row)
				check(fighter.tip_in_view,"A lance tip is outside the commitment-region viewport",row)
	return events

func run() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v056/exchange01.json"
	capture_dir = "E:/GALUMU/docs/development/screenshots/v056/exchange01"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
		if arg=="--no-captures": captures_enabled = false
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("V056 exchange verification requires GPU rendering and -- --test-profile")
		quit(2)
		return
	if FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(capture_dir):
		push_error("Use fresh v056 report and capture paths")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	if captures_enabled: DirAccess.make_dir_recursive_absolute(capture_dir)
	state.profile = state.default_profile()
	state.profile.settings.sound = true
	state.profile.settings.shake = true
	original_master_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-60)
	root.size = Vector2i(1280,720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	if suite in ["all","input"]:
		await ready_and_input_probe()
		await start_from_rest_probe()
	if suite in ["all","exchange"]:
		for item in [["arena",true,"shield"],["arena",false,"shield"],["war",true,"body"],["arena",true,"miss"],["war",false,"miss"],["war",true,"wounded"]]:
			await run_case(item[0],item[1],item[2])
		await simultaneous_scene_order()
	check(suite in ["all","input","exchange"],"Unknown test suite")
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main._close_battle()
	main.queue_free()
	await wait_wall_msec(160)
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"suite":suite,"cases":cases,"captures":captures,"input_events":input_events,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"scope":"GPU production scene and actual swept contacts, inherited v049 first-frame/audio/pause/settings/exit/simultaneous contracts plus real countdown and engine viewport hold/release. Fixed-step input telemetry is simulated time, not framerate. Existing scene fixture uses explicitly staged contacts and scripted controls; no OS or human feel/audio approval. Projection endpoint checks include both directions; screenshot review remains required."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("EXCHANGE_V056 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
