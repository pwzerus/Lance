extends SceneTree
## Focused production-camera evidence. Never sets camera position, zoom,
## offset or calls a fitting helper. Contacts are actual Model swept hits.
const Model = preload("res://scripts/core/joust_match.gd")
var main: Node
var failures: Array[String] = []
var examples: Array = []
var cases: Array = []
var captures: Array = []
var report_path = "E:/GALUMU/docs/development/logs/v050/fall-camera-01.json"
var capture_dir = ""
var original_master_db = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, info: Dictionary = {}) -> void:
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	if examples.size()<40:
		examples.append({"message":message,"context":info.duplicate(true)})

func aim_at(model, attacker: int, zone: String) -> float:
	var defender: Dictionary = model.fighters[1-attacker]
	var target: Vector2 = Model.head_position(defender) if zone=="head" else (Model.flank_position(defender) if zone=="flank" else (Model.shield_position(defender) if zone=="shield" else Model.body_position(defender)))
	return asin(clampf((target.y-Model.hand_position(model.fighters[attacker]).y)/Model.lance_length(model.fighters[attacker]),-.629,.548))

func prepare(model, attacker: int, zone: String, gap: float, phase: float, double_ko: bool) -> void:
	model.phase = "charge"
	model.rng.seed = 49055
	model.events.clear()
	model.result.clear()
	model.time_elapsed = 0.0
	model.time_effect_active = false
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		fighter.x = -gap*.5 if index==0 else gap*.5
		fighter.direction = 1 if index==0 else -1
		fighter.speed = 480.0
		fighter.stamina = 100.0
		fighter.stats.speed = 1.0
		fighter.stats.stability = 1.0
		fighter.stats.reach = 247.0
		fighter.stats.armor = 0.0
		fighter.stats.helmet = 0.0
		fighter.acted = false if double_ko else index!=attacker
		fighter.guard = .43
		fighter.guard_target = .43
		fighter.lean = 0.0
		fighter.lean_velocity = 0.0
		fighter.aim = .58
		fighter.hp = 100.0 if double_ko or index==attacker else 1.0
		fighter.shield = 100.0 if double_ko or index==attacker else 0.0
		fighter.balance = 1.0 if double_ko else 100.0
		fighter.ko = false
		fighter.dead = false
		fighter.broken = false
		fighter.durability = 1000.0
		fighter.wounds = []
		fighter.lance_stability = 1.0
		fighter.gait_phase = phase
		fighter.gait_moving = true
		fighter.boost = true
		fighter.acceleration = 0.0
		fighter.accel_command = 0.0
		fighter.motion_drive = 0.0
	for index in range(2):
		if double_ko or index==attacker:
			model.fighters[index].aim = aim_at(model,index,zone)
	for fighter in model.fighters:
		model._cache_pose(fighter)

func step(model, attacker: int, zone: String, double_ko: bool, dt: float) -> Array:
	for index in range(2):
		model.set_controls(index,aim_at(model,index,zone) if double_ko or index==attacker else .58,0.0,true,dt,.43)
	model.step(dt)
	return model.drain_events()

func double_fixture(battle) -> Dictionary:
	# Lowered balance makes an actual simultaneous shield exchange unseat
	# both riders. No fabricated KO/death events are injected into Battle.
	for phase in [0.0,.15,.4,.8]:
		for gap in [1000.0,1004.0,1008.0,1012.0]:
			var model = Model.new("arena",battle.match_model.fighters[0].stats,battle.match_model.fighters[1].stats,49055)
			prepare(model,0,"shield",gap,phase,true)
			for tick in range(240):
				var hits: Array = []
				for event in step(model,0,"shield",true,1.0/120.0):
					if event.type=="hit" and bool(event.ko):
						hits.append(event)
				if hits.size()==2:
					return {"gap":gap,"phase":phase}
				if model.phase=="ended":
					break
	return {}

func body_sample(battle, actor) -> Dictionary:
	var bounds: Rect2 = actor.world_body_rect()
	var canvas = root.get_canvas_transform()
	var screen = Rect2(canvas*bounds.position,Vector2.ZERO)
	for corner in [Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:
		screen = screen.expand(canvas*corner)
	var safe: Rect2 = battle.combat_safe_rect()
	return {"facing":int(actor.fighter.direction),"age":float(actor.age),"grounded":bool(actor.grounded),"settled":bool(actor.settled),
		"screen":[screen.position.x,screen.position.y,screen.size.x,screen.size.y],
		"margins":[screen.position.x-safe.position.x,screen.position.y-safe.position.y,safe.end.x-screen.end.x,safe.end.y-screen.end.y],
		"inside":safe.grow(1.0).encloses(screen)}

func capture(name: String, stage: String) -> void:
	if capture_dir.is_empty():
		return
	# Called after frame_post_draw. Do not stop processing or alter the camera.
	var path = capture_dir+"/"+name+"_"+stage+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Production-camera screenshot saves",{"path":path})
	captures.append({"case":name,"stage":stage,"path":path,"camera_override":false})

func run_case(mode_name: String, attacker: int, zone: String, slow: bool, double_ko: bool) -> void:
	var name = "arena_double_ko" if double_ko else "%s_%s_defender_%s" % [mode_name,zone,"right" if attacker==1 else "left"]
	var state = root.get_node("GameState")
	state.profile.settings.slow_motion = slow
	main._start_match(mode_name,true)
	var battle = main.battle
	battle.set_physics_process(false) # Scripted finite controls, not OS input.
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	var fixture = double_fixture(battle) if double_ko else {"gap":3200.0,"phase":0.0}
	check(not fixture.is_empty(),"A genuine simultaneous double-KO fixture exists",{"case":name})
	if fixture.is_empty():
		main._close_battle()
		await process_frame
		return
	prepare(battle.match_model,attacker,zone,float(fixture.gap),float(fixture.phase),double_ko)
	battle._update_views()
	var hits: Array = []
	var timeline: Array = []
	var min_margins = [INF,INF,INF,INF]
	var stages: Dictionary = {}
	var started = Time.get_ticks_msec()
	# Normal production _process updates camera/timing and normal child
	# processes animate the fall. Only pre-terminal Model input is scripted.
	while Time.get_ticks_msec()-started<14000:
		await physics_frame
		if battle.match_model.phase!="ended":
			# Preserve the actual render-driven cinematic scale. Subdivision only
			# improves collision resolution; it does not fabricate a contact.
			var remaining = Engine.time_scale/maxf(1.0,Engine.physics_ticks_per_second)
			while remaining>.0000001 and battle.match_model.phase!="ended":
				var dt = minf(remaining,1.0/120.0)
				battle.match_model.time_effect_active = bool(battle.exchange_state.impact_active)
				var events: Array = step(battle.match_model,attacker,zone,double_ko,dt)
				battle._consume_events(events)
				for event in events:
					if event.type=="hit":
						hits.append(event.duplicate(true))
				remaining -= dt
			battle._update_views()
		await process_frame
		await RenderingServer.frame_post_draw
		if not battle.effects.bodies.is_empty():
			var samples: Array = []
			for actor in battle.effects.bodies:
				var sample = body_sample(battle,actor)
				samples.append(sample)
				for index in range(4):
					min_margins[index] = minf(min_margins[index],float(sample.margins[index]))
				check(bool(sample.inside),"Production camera keeps complete fallen body and shield between HUD bands",{"case":name,"sample":sample,"camera":str(battle.camera.position),"zoom":str(battle.camera.zoom),"offset":str(battle.camera.offset)})
			timeline.append({"wall_ms":Time.get_ticks_msec()-started,"camera":[battle.camera.position.x,battle.camera.position.y,battle.camera.zoom.x,battle.camera.offset.x,battle.camera.offset.y],"is_finished":battle.is_finished,"bodies":samples})
			for stage in ["first_contact","landed","settled"]:
				var ready = stage=="first_contact" or (stage=="landed" and battle.effects.bodies[0].grounded) or (stage=="settled" and battle.effects.falls_settled())
				if ready and not stages.has(stage):
					stages[stage] = true
					capture(name,stage)
		if battle.is_finished:
			break
	var expected_bodies = 2 if double_ko else 1
	check(battle.effects.bodies.size()==expected_bodies and hits.size()==expected_bodies,"Actual swept fixture produces the requested fallen riders",{"case":name,"hits":hits,"bodies":battle.effects.bodies.size()})
	for hit in hits:
		check(bool(hit.ko) and bool(hit.dead)==(mode_name=="war"),"Camera fixture retains arena/war death rules",{"case":name,"event":hit})
	check(battle.is_finished and battle.effects.falls_settled(),"Production terminal path reaches settled falls and bounded result state",{"case":name,"elapsed_ms":Time.get_ticks_msec()-started,"finished":battle.is_finished})
	check(not timeline.is_empty() and is_equal_approx(Engine.time_scale,1.0),"Production camera was sampled through a terminal exchange with restored time",{"case":name})
	cases.append({"name":name,"mode":mode_name,"slow_motion":slow,"fixture":fixture,"hits":hits,"minimum_margins_ltrb":min_margins,"samples":timeline,"camera_override":false})
	main._close_battle()
	await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): report_path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Fall camera checks require rendering and -- --test-profile")
		quit(1)
		return
	if FileAccess.file_exists(report_path):
		push_error("Choose a fresh fall camera report path")
		quit(2)
		return
	if not capture_dir.is_empty():
		if DirAccess.dir_exists_absolute(capture_dir):
			var existing = DirAccess.open(capture_dir)
			if existing!=null and not existing.get_files().is_empty():
				push_error("Choose a fresh fall camera capture directory")
				quit(2)
				return
		DirAccess.make_dir_recursive_absolute(capture_dir)
	state.profile = state.default_profile()
	state.profile.settings.blood = false
	state.profile.settings.sound = true
	state.profile.settings.shake = true
	original_master_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-60.0)
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false) # Keep results overlay from hiding sampled actors.
	await run_case("arena",0,"head",true,false)
	await run_case("war",1,"flank",false,false)
	# Fixed normal-time pre-contact substeps reproduce the searched same-step
	# double exchange; slow-on is separately exercised by the first case.
	await run_case("arena",0,"shield",false,true)
	main._close_battle()
	main.queue_free()
	await process_frame
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"cases":cases,"captures":captures,
		"project_version":ProjectSettings.get_setting("application/config/version","unknown"),
		"scope":"Production Battle._process camera/offset/terminal timing and ordinary fallen child process/physics, with no camera position/zoom/offset override or fitting. Scripted pre-terminal finite controls produce genuine Model swept contacts. Two single-KO directions plus a searched actual simultaneous low-balance shield double KO; 1HP and low balance are contract fixtures, not balance evidence. Body bounds include shield, head and both legs, not an obligation to retain every flying weapon. 1440x810 logical viewport only; optional PNG saves can stall timing. No OS input, human verdict, universal equipment/motion proof or unmodified full-distance starting-runup claim."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Could not write fall camera report")
		quit(3)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FALL_CAMERA_V050 ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":cases.size()}))
	quit(0 if failures.is_empty() else 1)
