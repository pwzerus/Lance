extends SceneTree
## Rendered HUD/figure geometry fixtures and input-contract checks.
## These fixtures do not rate camera naturalness or replace human play.
const Model = preload("res://scripts/core/joust_match.gd")
const DT = 1.0/120.0
var main: Node
var failures: Array[String] = []
var rows: Array = []
var capture_dir = "E:/GALUMU/docs/development/screenshots/v047/hud01"
var report_path = "E:/GALUMU/docs/development/logs/v047/hud01.json"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func configure(battle) -> void:
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	for view in battle.riders:
		view.set_process(false)

func figure_screen_bounds(battle, index: int) -> Rect2:
	var fighter: Dictionary = battle.match_model.fighters[index]
	var base = Vector2(fighter.x,fighter.lane_y)
	var pivot = Model.HIP+Model.saddle_offset(fighter)
	var facing = Vector2(fighter.direction,1)
	var angle = Model.pose_angle(fighter)
	var points: Array[Vector2] = []
	# Horse silhouette/ground allowance plus actual rider texture corners.
	for corner in [Vector2(-220,-290),Vector2(220,-290),Vector2(220,26),Vector2(-220,26)]:
		points.append(base+corner)
	var head_width = 84.0 if int(fighter.stats.get("helmet_tier",0))==4 else 70.0
	for corner in [Vector2(-head_width*.5,-151),Vector2(head_width*.5,-151),Vector2(head_width*.5,-71),Vector2(-head_width*.5,-71)]:
		points.append(base+(pivot+corner.rotated(angle))*facing)
	for point in Model.Shield.world_polygon(Model.shield_position(fighter),angle,int(fighter.direction),str(fighter.stats.get("shield_shape","kite"))):
		points.append(point)
	points.append(Model.hand_position(fighter))
	points.append(Model.tip_position(fighter))
	var view = battle.riders[index]
	for leg in view.leg_poses:
		points.append(base+leg.foot*facing+Vector2(-12,0))
		points.append(base+leg.foot*facing+Vector2(12,-15))
	var transform: Transform2D = battle.world.get_global_transform_with_canvas()
	var first = transform*points[0]
	var bounds = Rect2(first,Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(transform*point)
	return bounds

func set_fixture(battle, phase: String, gap: float, phase_time: float, lean: float, guard: float, impact: bool = false) -> void:
	var model = battle.match_model
	model.phase = phase
	model.phase_time = phase_time
	battle.terminal_at = 0
	battle.is_finished = false
	for index in range(2):
		var fighter = model.fighters[index]
		fighter.x = -gap*.5 if index==0 else gap*.5
		fighter.lean = lean if index==0 else -lean
		fighter.guard = guard
		fighter.guard_target = guard
		fighter.speed = 480.0 if phase=="charge" else 0.0
		fighter.gait_moving = phase=="charge"
		fighter.gait_phase = .8 if index==0 else 2.2
		fighter.aim = -.1 if index==0 else .1
		fighter.acted = true
		fighter.ko = false
		fighter.dead = false
		model._cache_pose(fighter)
		battle.riders[index].moving = false
		battle.riders[index]._process(0)
	battle._update_views()
	for view in battle.riders:
		view._process(DT)
	# Settle the actual camera method at each explicit layout fixture.
	for tick in range(90):
		battle._update_camera(1.0/30.0,Time.get_ticks_msec())
	if impact:
		battle.contact_label.text = "你命中 · 胸甲 · 冲击 103 · 失稳 · 盾已破损"
		battle.enemy_contact_label.text = "对手命中 · 盾牌格挡 · 盾已破损"
		battle.contact_until = Time.get_ticks_msec()+60000
	else:
		battle.contact_until = 0
	battle._update_hud()

func measure(battle, name: String, require_both: bool, capture_image: bool = true) -> void:
	await process_frame
	await process_frame
	var safe: Rect2 = battle.combat_safe_rect()
	var viewport = root.get_visible_rect()
	var hud_rects: Array = []
	for node in battle.hud.find_children("*","Control",true,false):
		if not node.is_visible_in_tree():
			continue
		if node is Label and node.text.is_empty():
			continue
		var rect: Rect2 = node.get_global_rect()
		check(not safe.grow(-.5).intersects(rect.grow(-.5)),name+": normal HUD intrudes into the mounted combat area: "+node.name)
		check(viewport.grow(.5).encloses(rect),name+": HUD control exceeds the logical viewport: "+node.name)
		hud_rects.append({"node":str(node.name),"type":node.get_class(),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	var figures: Array = []
	for index in range(2):
		var bounds = figure_screen_bounds(battle,index)
		if index==0 or require_both:
			check(safe.grow(.5).encloses(bounds),name+": rider/horse/weapon silhouette is cropped by HUD or viewport, side "+str(index))
		figures.append([bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y])
	rows.append({"name":name,"window":[root.size.x,root.size.y],"viewport":[viewport.size.x,viewport.size.y],"safe":[safe.position.x,safe.position.y,safe.size.x,safe.size.y],"zoom":battle.camera.zoom.x,"camera_y":battle.camera.position.y,"figures":figures,"hud":hud_rects})
	if capture_image:
		await RenderingServer.frame_post_draw
		var code = root.get_texture().get_image().save_png(capture_dir+"/"+name+".png")
		check(code==OK,"Could not save HUD screenshot "+name)
		print("HUD_V047_CAPTURE ",name," ",code)

func direct_mouse(battle, point: Vector2, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	battle._input(event)

func input_contract(battle) -> void:
	set_fixture(battle,"charge",900,0,0,.43)
	var fighter = battle.match_model.fighters[0]
	for point in [battle.guard_buttons[0].get_global_rect().get_center(),Vector2(1340,30),Vector2(1100,780)]:
		direct_mouse(battle,point,true)
		battle._physics_process(DT)
		check(not fighter.boost and battle.ui_pointer_held,"HUD click accidentally urged the horse")
		direct_mouse(battle,point,false)
	direct_mouse(battle,Vector2(900,400),true)
	battle._physics_process(DT)
	check(fighter.boost,"Combat-area hold failed to urge the horse")
	direct_mouse(battle,Vector2(900,400),false)
	battle._physics_process(DT)
	check(not fighter.boost,"Mouse release left the urging input active")
	# Canvas inverse mapping still agrees after the new framing constraint.
	var target = Model.hand_position(fighter)+Vector2(180,-25)
	var motion = InputEventMouseMotion.new()
	motion.position = battle.world.get_global_transform_with_canvas()*target
	motion.relative = Vector2(1,0)
	battle._input(motion)
	var selected_aim = float(battle.pointer_aim)
	check(absf(selected_aim-asin(-25/Model.lance_length(fighter)))<.0001,"HUD framing broke canvas inverse pointer mapping")
	for tick in range(12):
		battle._update_camera(DT,Time.get_ticks_msec())
	check(absf(battle.pointer_aim-selected_aim)<.00001,"Camera constraint redirected a stationary pointer")
	# A new shield/aim target must still travel at the existing finite rates.
	fighter.guard = 1.0
	fighter.guard_target = 1.0
	fighter.aim = -.5
	battle.pointer_aim = .5
	battle._select_guard(2)
	battle._physics_process(DT)
	check(fighter.guard>0 and fighter.guard<1,"Shield target selection teleported the shield")
	check(1.0-float(fighter.guard)<=DT*2.8*float(fighter.stats.get("shield_handling",1.0))+.0001,"Shield selection exceeded its continuous movement limit")
	check(fighter.aim>-.5 and fighter.aim<.5,"Pointer target teleported the lance")
	check(float(fighter.aim)+.5<=DT*2.2*float(fighter.stats.get("lance_handling",1.0))+.0001,"Lance target exceeded its continuous angular limit")
	var x_before = float(fighter.x)
	battle._toggle_pause()
	battle._physics_process(.25)
	check(battle.paused and paused and fighter.x==x_before,"HUD pause did not freeze rule movement")
	battle._toggle_pause()
	check(not battle.paused and not paused and is_equal_approx(Engine.time_scale,1.0),"HUD resume did not restore the normal time state")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("HUD study requires rendering and -- --test-profile")
		quit(1)
		return
	if FileAccess.file_exists(report_path):
		push_error("Choose a new HUD report path to preserve evidence")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.settings.shake = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for window_size in [Vector2i(1280,720),Vector2i(1440,810),Vector2i(1920,1080)]:
		root.size = window_size
		await process_frame
		for mode_name in ["arena","war"]:
			main._start_match(mode_name,true)
			var battle = main.battle
			configure(battle)
			await process_frame
			var prefix = str(window_size.x)+"_"+mode_name+"_"
			set_fixture(battle,"ready",4400,2.6,0,.43)
			await measure(battle,prefix+"ready_wide",true)
			set_fixture(battle,"ready",4400,.1,0,1)
			await measure(battle,prefix+"ready_follow",false)
			set_fixture(battle,"charge",3200,0,0,.43)
			await measure(battle,prefix+"run_up",false)
			set_fixture(battle,"charge",1100,0,0,.43)
			await measure(battle,prefix+"duel",true)
			set_fixture(battle,"charge",400,0,0,1)
			await measure(battle,prefix+"close_high_shields",true)
			set_fixture(battle,"charge",400,0,1,0,true)
			await measure(battle,prefix+"close_lean_and_contact",true)
			if window_size.x==1280:
				input_contract(battle)
			main._close_battle()
			await process_frame
	main.queue_free()
	await process_frame
	var report = {"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Actual rendered formal BattleScene layout fixtures, both modes, 1280x720/1440x810/1920x1080 windows under project canvas stretch. Normal HUD vs mounted silhouette geometry, direct engine-handler input/continuous aim-shield movement contracts; not OS input, continuous camera quality or human play evidence."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("HUD_V047 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
