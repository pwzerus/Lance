extends SceneTree
## Formal BattleScene charge-camera study. Fixed-step rule movement plus actual
## rendering; one injected pointer event, scripted urging. No OS/human claims.
const Model = preload("res://scripts/core/joust_match.gd")
const DT = 1.0/30.0
var failures: Array[String] = []
var mode_reports: Array = []
var main: Node
var capture_dir = "E:/GALUMU/docs/development/screenshots/v046/charge-camera"
var report_path = "E:/GALUMU/docs/development/logs/v046/charge-camera-01.json"
var requested_modes: Array = ["arena","war"]
var input_audit: Node

class InputAudit extends Node:
	var events: Array = []
	var test_injection = false
	var mode_name = ""
	var director_tick = -1
	var battle
	func _input(event: InputEvent) -> void:
		if not (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
			return
		var row = {"mode":mode_name,"director_tick":director_tick,"wall_msec":Time.get_ticks_msec(),"process_frame":Engine.get_process_frames(),"type":event.get_class(),"injected_by_this_test":test_injection,"device":event.device}
		if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
			row["position"] = [event.position.x,event.position.y]
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			row["relative"] = [event.relative.x,event.relative.y]
		if is_instance_valid(battle):
			row["pointer_aim_before_dispatch"] = battle.pointer_aim
			row["battle_input_enabled"] = battle.is_processing_input()
			row["battle_unhandled_input_enabled"] = battle.is_processing_unhandled_input()
		events.append(row)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func configure(battle) -> void:
	battle.set_process(false)
	battle.set_physics_process(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	for view in battle.riders:
		view.set_process(false)
	# No director/AI uses wall-clock timers to move the model during this study.
	battle.demo_seed = 4603

func projected_fighter(battle, fighter: Dictionary) -> Dictionary:
	var transform: Transform2D = battle.world.get_global_transform_with_canvas()
	var base = Vector2(fighter.x,fighter.lane_y)
	var left = transform*(base+Vector2(-174,-310))
	var right = transform*(base+Vector2(185,22))
	var head = transform*Model.head_position(fighter)
	var tip = transform*Model.tip_position(fighter)
	var hand = transform*Model.hand_position(fighter)
	var viewport = root.get_visible_rect()
	return {"direction":fighter.direction,"world_x":fighter.x,"speed":fighter.speed,"horse_screen_x_min":minf(left.x,right.x),"horse_screen_x_max":maxf(left.x,right.x),"horse_screen_y_min":minf(left.y,right.y),"horse_screen_y_max":maxf(left.y,right.y),"head_screen":[head.x,head.y],"hand_screen":[hand.x,hand.y],"tip_screen":[tip.x,tip.y],"tip_in_view":viewport.has_point(tip),"horse_x_in_view":minf(left.x,right.x)>=viewport.position.x and maxf(left.x,right.x)<=viewport.end.x}

func snapshot(battle, seconds: float) -> Dictionary:
	var canvas: Transform2D = battle.world.get_global_transform_with_canvas()
	var viewport = root.get_visible_rect()
	var inverse = canvas.affine_inverse()
	var visible_left = inverse*viewport.position
	var visible_right = inverse*viewport.end
	var fighters: Array = []
	for fighter in battle.match_model.fighters:
		fighters.append(projected_fighter(battle,fighter))
	return {"seconds":seconds,"phase":battle.match_model.phase,"signed_gap":float(battle.match_model.fighters[1].x)-float(battle.match_model.fighters[0].x),"camera_position":[battle.camera.position.x,battle.camera.position.y],"zoom":battle.camera.zoom.x,"approach_slow":battle.approach_slow,"pointer_aim":battle.pointer_aim,"viewport":[viewport.position.x,viewport.position.y,viewport.size.x,viewport.size.y],"visible_world_x":[visible_left.x,visible_right.x],"fighters":fighters}

func capture(battle, mode_name: String, name: String, seconds: float, captures: Array) -> void:
	battle._update_hud()
	await RenderingServer.frame_post_draw
	var path = capture_dir+"/"+mode_name+"/"+name+".png"
	var code = root.get_texture().get_image().save_png(path)
	check(code==OK,"Camera screenshot could not be saved: "+path)
	var row = snapshot(battle,seconds)
	row["name"] = name
	row["path"] = path
	captures.append(row)
	print("CHARGE_CAMERA_CAPTURE ",mode_name," ",name," ",code)

func pause_check(battle, mode_name: String, seconds: float, captures: Array, committed_pointer: float) -> void:
	var position_before = float(battle.match_model.fighters[0].x)
	var phase_before = float(battle.match_model.fighters[0].gait_phase)
	var camera_before: Vector2 = battle.camera.position
	var zoom_before: Vector2 = battle.camera.zoom
	battle._toggle_pause()
	check(battle.paused and paused,"Pause stops the formal battle and SceneTree")
	battle._physics_process(.25)
	battle._process(.25)
	check(is_equal_approx(float(battle.match_model.fighters[0].x),position_before),"Paused rule position advanced")
	check(is_equal_approx(float(battle.match_model.fighters[0].gait_phase),phase_before),"Paused horse gait advanced")
	check(battle.camera.position.is_equal_approx(camera_before) and battle.camera.zoom.is_equal_approx(zoom_before),"Paused camera advanced")
	await capture(battle,mode_name,"pause_after_2s",seconds,captures)
	battle._toggle_pause()
	check(not battle.paused and not paused and is_equal_approx(Engine.time_scale,1.0),"Resume restores time and unpauses")
	# Exercise the actual BattleScene input/physics path after the canvas has
	# changed, not just the camera method. These three explicit probe steps
	# have their own record, outside the charge director's measured intervals.
	for probe in range(3):
		battle.mouse_held = true
		battle._physics_process(DT)
		battle._update_camera(DT,Time.get_ticks_msec())
		for view in battle.riders:
			view._process(DT)
		check(absf(float(battle.match_model.fighters[0].aim)-committed_pointer)<.00001,"Formal physics path re-aimed a stationary pointer after camera change")
	Engine.time_scale = 1.0
	var row = snapshot(battle,seconds)
	row["name"] = "post_pause_stationary_pointer_physics_probe"
	row["extra_fixed_steps"] = 3
	captures.append(row)
	await process_frame

func run_mode(mode_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir+"/"+mode_name)
	main._start_match(mode_name,true)
	var battle = main.battle
	configure(battle)
	input_audit.mode_name = mode_name
	input_audit.director_tick = -1
	input_audit.battle = battle
	await process_frame
	# Advance the real countdown. The final 1.35 ready seconds deliberately
	# settle into run-up framing; holding phase_time fixed bypassed that code.
	var model = battle.match_model
	model.rng.seed = 4603
	var ready_samples: Array = []
	var ready_seconds = 0.0
	while model.phase=="ready" and ready_seconds<3.0:
		await process_frame
		model.step(DT)
		ready_seconds += DT
		for event in model.drain_events():
			battle._handle_event(event)
		battle._update_views()
		for view in battle.riders:
			view._process(DT)
		battle._update_camera(DT,Time.get_ticks_msec())
		battle._update_hud()
		var row = snapshot(battle,-maxf(0.0,2.6-ready_seconds))
		row["phase_time"] = model.phase_time
		ready_samples.append(row)
	check(model.phase=="charge","Real ready countdown did not reach charge")
	check(ready_seconds>=2.6-DT and ready_seconds<=2.6+DT*2,"Ready countdown was not advanced for its real duration")
	check(float(player_speed(model))==0.0,"Countdown framing moved the horse before charge")
	for fighter in model.fighters:
		fighter.acted = false
		fighter.guard = .43
		fighter.guard_target = .43
		fighter.aim = -.25 if int(fighter.direction)==1 else .25
		model._cache_pose(fighter)
	# One pointer event chooses the actual lance height in the current canvas.
	# Every later camera update receives no pointer motion and must preserve it.
	var player = model.fighters[0]
	var pointer_world = Model.hand_position(player)+Vector2(200,sin(-.25)*Model.lance_length(player))
	var motion = InputEventMouseMotion.new()
	motion.position = battle.world.get_global_transform_with_canvas()*pointer_world
	motion.relative = Vector2(2,0)
	input_audit.test_injection = true
	root.push_input(motion,true)
	input_audit.test_injection = false
	var committed_pointer = float(battle.pointer_aim)
	check(absf(committed_pointer+.25)<.02,"Initial pointer event did not select the expected real lance height")
	# The old camera02 failure had no input-event log, so OS interference is
	# a hypothesis, not a proven attribution. Isolate callbacks for this
	# camera-only retest while the observer still records external events.
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	var captures: Array = []
	var samples: Array = []
	var seen: Dictionary = {}
	var contacts: Array = []
	var max_player_screen_velocity = 0.0
	var max_player_screen_accel = 0.0
	var previous_screen_x = NAN
	var previous_velocity = NAN
	var max_world_step_error = 0.0
	var minimum_committed_margin = INF
	var pause_done = false
	var crossed = false
	var seconds = 0.0
	for tick in range(900):
		input_audit.director_tick = tick
		await process_frame
		var game_dt = DT*(.72 if battle.approach_slow else 1.0)
		var x_before = float(player.x)
		model.set_controls(0,committed_pointer,0.0,true,game_dt,.43)
		model.set_controls(1,.25,0.0,true,game_dt,.43)
		model.step(game_dt)
		seconds += DT
		if model.phase=="charge":
			max_world_step_error = maxf(max_world_step_error,absf(float(player.x)-x_before-float(player.speed)*game_dt))
		var just_hit = false
		for event in model.drain_events():
			battle._handle_event(event)
			if event.type=="hit":
				contacts.append(event.duplicate(true))
				just_hit = true
		# The director advances fixed game time explicitly; reset the rendering
		# time scale after event FX so MovieMaker timing cannot replace model dt.
		Engine.time_scale = 1.0
		battle._update_views()
		for view in battle.riders:
			view._process(game_dt)
		battle._update_camera(DT,Time.get_ticks_msec())
		battle._update_hud()
		check(absf(float(battle.pointer_aim)-committed_pointer)<.00001,"Stationary pointer was re-aimed by camera movement")
		var row = snapshot(battle,seconds)
		var gap = float(row.signed_gap)
		var screen_x = float(row.fighters[0].head_screen[0])
		if is_finite(previous_screen_x):
			var velocity = (screen_x-previous_screen_x)/DT
			max_player_screen_velocity = maxf(max_player_screen_velocity,absf(velocity))
			if is_finite(previous_velocity):
				max_player_screen_accel = maxf(max_player_screen_accel,absf(velocity-previous_velocity)/DT)
			previous_velocity = velocity
		previous_screen_x = screen_x
		samples.append(row)
		if gap>0 and gap<=1100 and model.phase=="charge":
			var viewport = root.get_visible_rect()
			for projected in row.fighters:
				check(projected.horse_x_in_view,"A horse is horizontally clipped by the 1100-unit commitment zone")
				check(projected.tip_in_view,"A lance tip is outside the viewport in the commitment zone")
				minimum_committed_margin = minf(minimum_committed_margin,minf(float(projected.horse_screen_x_min),viewport.end.x-float(projected.horse_screen_x_max)))
		if seconds>=.8 and not seen.has("time08"):
			seen.time08 = true
			await capture(battle,mode_name,"01_time_0p8",seconds,captures)
		if seconds>=2.0 and not seen.has("time20"):
			seen.time20 = true
			await capture(battle,mode_name,"02_time_2p0",seconds,captures)
		for threshold in [2800,1800,1100,650]:
			var key = "gap"+str(threshold)
			if gap<=threshold and gap>0 and not seen.has(key):
				seen[key] = true
				await capture(battle,mode_name,"gap_"+str(threshold),seconds,captures)
		if just_hit and not seen.has("contact"):
			seen.contact = true
			await capture(battle,mode_name,"contact_actual",seconds,captures)
		if not pause_done and seconds>=2.0:
			pause_done = true
			await pause_check(battle,mode_name,seconds,captures,committed_pointer)
		if gap< -200.0:
			crossed = true
			await capture(battle,mode_name,"crossed",seconds,captures)
			break
	check(crossed,"Charge never reached an actual rider crossing")
	check(not contacts.is_empty(),"No actual swept contact occurred in the camera study")
	check(max_world_step_error<.05,"Rule displacement did not match actual speed and game dt")
	for threshold in [2800,1800,1100,650]:
		check(seen.has("gap"+str(threshold)),"Missing camera threshold capture "+str(threshold))
	var old_battle = battle
	main._start_match(mode_name,true)
	battle = main.battle
	configure(battle)
	await process_frame
	check(battle!=old_battle and battle.match_model.phase=="ready","Restart did not create a fresh ready battle")
	check(is_equal_approx(battle.camera.zoom.x,.28),"Restart did not restore ready camera scale")
	for fighter in battle.match_model.fighters:
		check(fighter.speed==0 and not fighter.gait_moving,"Restart retained moving horse state")
	check(not paused and is_equal_approx(Engine.time_scale,1.0),"Restart left pause/time scale active")
	mode_reports.append({"mode":mode_name,"seconds":seconds,"ready_seconds":ready_seconds,"ready_samples":ready_samples,"world_step_error_max":max_world_step_error,"minimum_committed_horizontal_margin":minimum_committed_margin,"max_head_screen_velocity_px_s":max_player_screen_velocity,"max_head_screen_acceleration_px_s2":max_player_screen_accel,"contact_count":contacts.size(),"contacts":contacts,"stationary_pointer_aim":committed_pointer,"input_isolation":"After one observed viewport motion event, BattleScene _input and _unhandled_input callbacks disabled; real _physics_process probes still run. Observer continues logging other pointer/touch events.","captures":captures,"samples":samples,"scope":"Screen velocity/acceleration are measurements for review, not an assertion that the transition is natural."})
	main._close_battle()
	await process_frame

func player_speed(model) -> float:
	return float(model.fighters[0].speed)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--mode="):
			requested_modes = [arg.trim_prefix("--mode=")]
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_"):
		push_error("Camera study requires -- --test-profile")
		quit(1)
		return
	if DisplayServer.get_name()=="headless":
		push_error("Camera study requires actual rendering")
		quit(1)
		return
	if FileAccess.file_exists(report_path) or FileAccess.file_exists(capture_dir+"/arena/01_time_0p8.png"):
		push_error("Choose fresh output paths to preserve previous evidence")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.settings.shake = false
	state.profile.settings.slow_motion = true
	root.size = Vector2i(1280,720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	input_audit = InputAudit.new()
	input_audit.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(input_audit)
	for mode_name in requested_modes:
		check(mode_name in ["arena","war"],"Unknown camera-study mode")
		if mode_name in ["arena","war"]:
			await run_mode(mode_name)
	main.queue_free()
	await process_frame
	var report = {"passed":failures.is_empty(),"failures":failures,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"fixed_real_dt":DT,"prior_camera02_failure":{"status":"origin unproven; previous run had no event audit","mode":"war","sample_index":96,"seconds":3.23333333333333,"gap":1746.74074074074,"aim_before":-.249999944478716,"aim_after":-.164167063468855,"static_finding":"Camera has no pointer_aim assignment; event-driven _set_pointer_aim does. Isolation retest evaluates camera/physics without external callbacks, not whether the old event was an OS event."},"input_events":input_audit.events,"scope":"Actual BattleScene/world/riders/camera rendering, real 2.6s ready countdown and continuous rule movement; scripted controls and one audited viewport pointer event; callbacks then isolated, threshold/collision/crossing captures, pause/restart. No OS input or human quality claim.","modes":mode_reports}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CHARGE_CAMERA_V046 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
