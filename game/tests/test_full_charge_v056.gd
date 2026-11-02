extends "test_exchange_v056.gd"
## Continuous production Main/Battle, from the normal 4400-unit ready state.
## This file never calls Model.step or Battle's process/physics methods.
## Relative test inheritance also supports an external script with exported PCK.
const QA_SEED = 56056
const QA_CATALOGUE = preload("res://scripts/core/catalogue.gd")
class PhysicsObserver extends Node:
	var observer
	func _physics_process(delta: float) -> void:
		observer.observe_physics(delta)

var live_battle
var physics_samples: Array = []
var rendered_samples: Array = []
var pending_images: Array = []
var markers: Dictionary = {}
var previous_physics: Dictionary = {}
var start_usec = 0
var prior_physics_usec = 0
var prior_render_usec = 0
var charge_start_game = -1.0
var total_game_delta = 0.0
var total_render_game_delta = 0.0
var physics_observer: Node
var initial_stats: Array = []
var finished_first_pass = false
var fixed_capture_mode = false
var requested_horse_id = "horse_bay"
var slow_motion_enabled = true

func observe_physics(delta: float) -> void:
	if not is_instance_valid(live_battle): return
	var model = live_battle.match_model
	var now = Time.get_ticks_usec()
	total_game_delta += delta
	if model.phase=="charge" and charge_start_game<0.0:
		charge_start_game = float(model.time_elapsed)
	var gap = float(model.fighters[1].x)-float(model.fighters[0].x)
	var fighters: Array = []
	for index in range(2):
		var f: Dictionary = model.fighters[index]
		if not previous_physics.is_empty() and int(previous_physics.pass_id)==int(model.pass_number) and previous_physics.phase!="ended":
			var before: Dictionary = previous_physics.fighters[index]
			var committed = previous_physics.phase=="charge" and float(previous_physics.gap)>0.0 and float(previous_physics.gap)<1100.0
			var aim_limit = (.95 if committed else 2.2)*float(f.stats.get("lance_handling",1.0))*delta
			var guard_limit = 2.8*float(f.stats.get("shield_handling",1.0))*delta
			check(absf(float(f.aim)-float(before.aim))<=aim_limit+.00001,"Live physics lance movement exceeded its game-time limit",{"index":index,"delta":delta,"aim_before":before.aim,"aim_after":f.aim,"limit":aim_limit,"gap_before":previous_physics.gap})
			check(absf(float(f.guard)-float(before.guard))<=guard_limit+.00001,"Live physics shield movement exceeded its game-time limit",{"index":index,"delta":delta,"guard_before":before.guard,"guard_after":f.guard,"limit":guard_limit})
		fighters.append({"x":f.x,"speed":f.speed,"aim":f.aim,"guard":f.guard,"guard_target":f.guard_target,
			"gait_phase":f.gait_phase,"boost":f.boost,"stamina":f.stamina,"acceleration":f.acceleration,"motion_drive":f.motion_drive,
			"broken":f.broken,"ko":f.ko,"dead":f.dead})
	var row = {"wall_seconds":float(now-start_usec)/1000000.0,"wall_delta":float(now-prior_physics_usec)/1000000.0 if prior_physics_usec>0 else 0.0,
		"game_delta":delta,"cumulative_game_delta":total_game_delta,"model_time":model.time_elapsed,"phase":model.phase,"pass_id":model.pass_number,
		"gap":gap,"engine_scale":Engine.time_scale,"fighters":fighters,"exchange_state":live_battle.exchange_state.state}
	physics_samples.append(row)
	previous_physics = row
	prior_physics_usec = now

func input_key(code: int, label: String) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	dispatch(live_battle,event,label)
	event = event.duplicate()
	event.pressed = false
	dispatch(live_battle,event,label+"_release")

func choose_aim(angle: float, label: String) -> void:
	var f: Dictionary = live_battle.match_model.fighters[0]
	var point = Model.hand_position(f)+Vector2(180,sin(angle)*Model.lance_length(f))
	var event = InputEventMouseMotion.new()
	event.position = live_battle.world.get_global_transform_with_canvas()*point
	event.relative = Vector2(1,1)
	var old_aim = float(f.aim)
	dispatch(live_battle,event,label)
	check(is_equal_approx(float(f.aim),old_aim),"Viewport aim command teleported the actual lance before physics")
	check(absf(float(live_battle.pointer_aim)-angle)<.02,"Live viewport aim command missed its requested height",{"requested":angle,"actual":live_battle.pointer_aim})

func mark_frame(tag: String, row: Dictionary) -> void:
	if markers.has(tag): return
	markers[tag] = row.duplicate(true)
	if not captures_enabled: return
	# Store GPU readback now, encode PNG after the live pass. File compression
	# must not consume the short contact/read budget during this experiment.
	var begin = Time.get_ticks_usec()
	var frame_image = root.get_texture().get_image()
	pending_images.append({"tag":tag,"image":frame_image})
	markers[tag]["readback_wall_ms"] = float(Time.get_ticks_usec()-begin)/1000.0

func run() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v056/full-charge01.json"
	capture_dir = "E:/GALUMU/docs/development/screenshots/v056/full-charge01"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
		elif arg.begins_with("--horse-id="): requested_horse_id = arg.trim_prefix("--horse-id=")
		elif arg=="--slow-off": slow_motion_enabled = false
		elif arg=="--no-captures": captures_enabled = false
	for arg in OS.get_cmdline_args():
		if arg in ["--write-movie","--fixed-fps"] or arg.begins_with("--write-movie=") or arg.begins_with("--fixed-fps="):
			fixed_capture_mode = true
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Continuous charge verification requires GPU and isolated -- --test-profile")
		quit(2)
		return
	var selected_horse: Dictionary = QA_CATALOGUE.find(state.items,requested_horse_id)
	if selected_horse.is_empty() or str(selected_horse.get("slot",""))!="horse":
		push_error("Requested --horse-id is not a horse in the loaded catalogue: "+requested_horse_id)
		quit(2)
		return
	if FileAccess.file_exists(report_path) or (captures_enabled and DirAccess.dir_exists_absolute(capture_dir)):
		push_error("Use fresh full-charge evidence paths")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	if captures_enabled: DirAccess.make_dir_recursive_absolute(capture_dir)
	var original_profile: Dictionary = state.profile.duplicate(true)
	state.profile = state.default_profile()
	# Equip only the isolated, in-memory QA collection. Preserve renown so
	# the normal opponent's era/equipment does not change with this boundary.
	if requested_horse_id not in state.profile.owned:
		state.profile.owned.append(requested_horse_id)
	state.profile.equipped.horse = requested_horse_id
	state.profile.settings.sound = true
	state.profile.settings.shake = true
	state.profile.settings.slow_motion = slow_motion_enabled
	state.profile.settings.mouse_only = true
	original_master_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-60.0)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_match("arena",true)
	live_battle = main.battle
	# Seed before any live physics tick; retain normal opponent stats, AI,
	# HP, durability, distance, ready countdown and both complete processes.
	live_battle.match_model.rng.seed = QA_SEED
	live_battle.ai_rng.seed = QA_SEED+431
	for f in live_battle.match_model.fighters: initial_stats.append(f.stats.duplicate(true))
	if root.focus_exited.is_connected(live_battle._on_focus_lost):
		root.focus_exited.disconnect(live_battle._on_focus_lost)
	live_battle.set_process_input(false)
	live_battle.set_process_unhandled_input(false)
	main.set_process_input(false)
	main.set_process_unhandled_input(false)
	physics_observer = PhysicsObserver.new()
	physics_observer.observer = self
	live_battle.add_child(physics_observer)
	start_usec = Time.get_ticks_usec()
	var initial_aim_chosen = false
	var released = false
	var reheld = false
	var late_changed = false
	var contact_count = 0
	var prior_game = 0.0
	var prior_marker_x = NAN
	while Time.get_ticks_usec()-start_usec<28000000:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(live_battle):
			check(false,"Live Battle disappeared before first-pass observation completed")
			break
		var now = Time.get_ticks_usec()
		var wall = float(now-start_usec)/1000000.0
		var model = live_battle.match_model
		var row = projection(live_battle)
		var render_wall_delta = float(now-prior_render_usec)/1000000.0 if prior_render_usec>0 else 0.0
		var observed_game_delta = total_game_delta-prior_game
		var marker_flow = (float(row.world_marker_x)-prior_marker_x)/render_wall_delta if is_finite(prior_marker_x) and render_wall_delta>0 else 0.0
		row.merge({"wall_seconds":wall,"wall_delta":render_wall_delta,"physics_game_delta_since_render":observed_game_delta,
			"process_game_delta":live_battle.get_process_delta_time(),"model_time":model.time_elapsed,"phase":model.phase,"pass_id":model.pass_number,
			"engine_scale":Engine.time_scale,"exchange":live_battle.exchange_state.duplicate(true),"mouse_held":live_battle.mouse_held,
			"pointer_aim":live_battle.pointer_aim,"camera_center":[live_battle.camera.position.x,live_battle.camera.position.y],
			"camera_offset":[live_battle.camera.offset.x,live_battle.camera.offset.y],"marker_pixels_per_wall_second":marker_flow,
			"player_speed":model.fighters[0].speed,"opponent_speed":model.fighters[1].speed,"player_gait_phase":model.fighters[0].gait_phase,
			"player_aim":model.fighters[0].aim,"player_guard":model.fighters[0].guard,"contact_count":live_battle.exchange_log.size()})
		rendered_samples.append(row)
		if not slow_motion_enabled:
			check(str(live_battle.exchange_state.state) not in ["approach","read"],"Slow-motion-off run entered an approach or read stage",row)
		prior_render_usec = now
		prior_game = total_game_delta
		prior_marker_x = float(row.world_marker_x)
		if not initial_aim_chosen:
			mark_frame("ready",row)
			choose_aim(-.24,"initial_aim_once")
			mouse_button(live_battle,true)
			initial_aim_chosen = true
		if model.phase=="ready":
			check(row.fighters[0].horse_in_x,"Normal ready camera clipped player horse",row)
		if model.phase=="charge":
			mark_frame("charge_start",row)
			var charge_game = float(model.time_elapsed)-charge_start_game
			if charge_game>=1.9 and not released:
				mark_frame("release_spur",row)
				mouse_button(live_battle,false)
				released = true
			if charge_game>=2.55 and not reheld:
				mark_frame("rehold_spur",row)
				mouse_button(live_battle,true)
				input_key(KEY_3,"guard_flank")
				reheld = true
			for gap_mark in [2200,1900,1550,1200,1100,850]:
				if float(row.gap)<=gap_mark: mark_frame("gap_"+str(gap_mark),row)
			if float(row.gap)>0 and float(row.gap)<=1100:
				for f in row.fighters:
					check(f.horse_in_x and f.tip_in_view,"Full run-up did not establish both riders and tips before commitment",row)
			if float(row.gap)<=1000 and float(row.gap)>0 and not late_changed:
				var old_guard = float(model.fighters[0].guard)
				input_key(KEY_1,"late_guard_head")
				check(is_equal_approx(old_guard,float(model.fighters[0].guard)),"Late shield key teleported guard before physics")
				choose_aim(-.20,"late_small_aim_change")
				late_changed = true
		if live_battle.exchange_log.size()>contact_count:
			var first_contact = contact_count==0
			contact_count = live_battle.exchange_log.size()
			mark_frame("actual_contact",row)
			# A later strike in the same pass deliberately keeps the current
			# read/release budget. Only the first contact begins the hold.
			if first_contact and slow_motion_enabled:
				check(str(live_battle.exchange_state.state)=="contact","Actual first contact rendered frame lost contact stage",row)
		if live_battle.exchange_state.state=="read": mark_frame("read",row)
		if live_battle.exchange_state.state=="release": mark_frame("release",row)
		if float(row.gap)<-500: mark_frame("crossed_rollout",row)
		if model.phase=="turn" or (model.phase=="ended" and live_battle.is_finished):
			mark_frame("first_pass_complete",row)
			finished_first_pass = true
			break
	check(finished_first_pass,"Continuous first pass did not complete within 28 wall seconds")
	check(released and reheld and late_changed,"Continuous run missed scheduled hold/release/guard commands")
	check(contact_count>0,"Normal AI run produced no actual contact; contact portion remains unverified")
	check(markers.has("gap_1900") and markers.has("gap_1550") and markers.has("gap_1200") and markers.has("gap_1100"),"Continuous run omitted part of the 1900-to-1200 camera transition")
	var actual_events: Array = live_battle.exchange_log.duplicate(true)
	var completion_wall = float(Time.get_ticks_usec()-start_usec)/1000000.0
	mouse_button(live_battle,false)
	physics_observer.set_physics_process(false)
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main._close_battle()
	live_battle = null
	main.queue_free()
	await wait_wall_msec(160)
	state.profile = original_profile
	AudioServer.set_bus_volume_db(0,original_master_db)
	check(is_equal_approx(Engine.time_scale,1.0) and not paused,"Continuous run exit left slow motion or pause active")
	for item in pending_images:
		var path = capture_dir+"/"+str(item.tag)+".png"
		check(item.image.save_png(path)==OK,"Continuous live-frame PNG could not be saved",{"path":path})
		markers[item.tag]["path"] = path
	pending_images.clear()
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"qa_seed":QA_SEED,"initial_stats":initial_stats,
		"horse_id":requested_horse_id,"slow_motion_enabled":slow_motion_enabled,
		"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"completion_wall_seconds":completion_wall,
		"physics_samples":physics_samples,"rendered_samples":rendered_samples,"markers":markers,"input_events":input_events,"actual_contacts":actual_events,
		"movie_or_fixed_fps":fixed_capture_mode,
		"scope":"Production Main/Battle and ordinary engine process/physics from the untouched ready countdown and 4400-unit separation through first pass. Normal practice AI and full-health equipment. Viewport-dispatched hold, release, repress, shield keys and two aim movements; no OS input. Physics observer follows Battle in the scene tree; no manual stepping, camera fitting, invented contacts or overridden speeds.",
		"limits":"Isolated QA profile; background focus pause disconnected and external input callbacks disabled between injected commands. GPU frames stored in memory and PNG encoded only after play; readback cost recorded. Standard --write-movie records engine frames; movie/fixed-fps clock differs from desktop real-time and cannot establish playable framerate. Visual/movie review and real OS input remain separate evidence."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write continuous charge report")
		quit(3)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FULL_CHARGE_V056 passed=",report.passed," wall=",completion_wall," contacts=",actual_events.size()," failures=",failures)
	quit(0 if report.passed else 1)
