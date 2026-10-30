extends SceneTree
## Actual swept Model contacts consumed by the formal Battle scene. Initial
## 1HP/weapon-state fixtures exercise presentation contracts, not balance.
## All motion after first contact uses normal process/physics, including the
## released weapon's RigidBody2D. Camera fitting is a documented QA override.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const PHYSICS_DT = 1.0/120.0
var main: Node
var failures: Array[String] = []
var examples: Array = []
var cases: Array = []
var captures: Array = []
var report_path = "E:/GALUMU/docs/development/logs/v050/fall-scene-01.json"
var capture_dir = "E:/GALUMU/docs/development/screenshots/v050/fall-scene01"
var captures_enabled = true
var case_limit = 0
var blood_toggle_only = false
var blood_toggle_results: Array = []
var original_master_db = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, info: Dictionary = {}) -> void:
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	if examples.size()<80:
		examples.append({"message":message,"context":info.duplicate(true)})

func configure(battle) -> void:
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	for view in battle.riders:
		view.set_process(false)
	battle.sound.music.stop()
	battle.exchange_director.reset(1)
	battle.exchange_state = battle.exchange_director.sample()
	battle.contact_first_frame_pending = false
	battle.contact_audio.clear()

func create_battle(mode_name: String, blood: bool = false):
	var state = root.get_node("GameState")
	state.profile.settings.blood = blood
	state.profile.settings.slow_motion = false
	main._start_match(mode_name,true)
	configure(main.battle)
	return main.battle

func target_aim(model, attacker: int, zone: String) -> float:
	var a: Dictionary = model.fighters[attacker]
	var b: Dictionary = model.fighters[1-attacker]
	var target = Model.head_position(b) if zone=="head" else (Model.flank_position(b) if zone=="flank" else Model.body_position(b))
	return asin(clampf((target.y-Model.hand_position(a).y)/Model.lance_length(a),-.629,.548))

func prepare_model(model, attacker: int, zone: String, broken: bool, phase: float) -> void:
	model.phase = "charge"
	model.rng.seed = 50051
	model.events.clear()
	model.result.clear()
	model.time_elapsed = 0.0
	model.time_effect_active = false
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		fighter.x = -600.0 if index==0 else 600.0
		fighter.direction = 1 if index==0 else -1
		fighter.speed = 480.0
		fighter.stamina = 100.0
		fighter.stats.speed = 1.0
		fighter.stats.stability = 1.0
		fighter.stats.reach = 247.0
		fighter.stats.armor = 0.0
		fighter.stats.helmet = 0.0
		fighter.acted = index!=attacker
		fighter.guard = .43
		fighter.guard_target = .43
		fighter.lean = 0.0
		fighter.lean_velocity = 0.0
		fighter.aim = .58
		fighter.hp = 100.0 if index==attacker else 1.0
		fighter.shield = 0.0 if index!=attacker else fighter.shield
		fighter.balance = 100.0
		fighter.ko = false
		fighter.dead = false
		fighter.broken = broken if index!=attacker else false
		fighter.durability = 1000.0
		fighter.wounds = []
		fighter.lance_stability = 1.0
		fighter.gait_phase = phase
		fighter.gait_moving = true
		fighter.boost = true
		fighter.acceleration = 0.0
		fighter.accel_command = 0.0
		fighter.motion_drive = 0.0
	model.fighters[attacker].aim = target_aim(model,attacker,zone)
	for fighter in model.fighters:
		model._cache_pose(fighter)

func step_model(model, attacker: int, zone: String) -> Array:
	var aim = target_aim(model,attacker,zone)
	for index in range(2):
		model.set_controls(index,aim if index==attacker else .58,0.0,true,PHYSICS_DT,.43)
	model.step(PHYSICS_DT)
	return model.drain_events()

func find_fixture(battle, attacker: int, zone: String, broken: bool) -> Dictionary:
	# Select a genuine deterministic swept hit. No event is fabricated or
	# replayed into the scene: the selected initial state is simulated again.
	for phase in [0.0,.55,1.2,2.2,3.4,4.5]:
		var model = Model.new(battle.mode,battle.match_model.fighters[0].stats,battle.match_model.fighters[1].stats,50051)
		prepare_model(model,attacker,zone,broken,phase)
		for tick in range(360):
			var pending = step_model(model,attacker,zone)
			for event in pending:
				if event.type=="hit":
					if int(event.attacker)==attacker and event.zone==zone and bool(event.ko):
						return {"phase":phase,"steps":tick+1,"preview_event":event.duplicate(true)}
			if model.phase=="ended":
				break
	return {}

func weapon_rect(actor) -> Rect2:
	if is_instance_valid(actor.loose_lance):
		var body: RigidBody2D = actor.loose_lance
		for child in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var half: Vector2 = child.shape.size*.5
				var result = Rect2(body.to_global(-half),Vector2.ZERO)
				for corner in [Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
					result = result.expand(body.to_global(corner))
				return result.grow(3.0)
	var grip = actor.to_global(Vector2(actor.visual.detached_pose.right.hand))
	var facing = int(actor.fighter.direction)
	var ray = Vector2(cos(float(actor.fighter.aim))*facing,sin(float(actor.fighter.aim))).rotated(float(actor.rotation))
	var result = Rect2(grip-ray*67.0,Vector2.ZERO)
	return result.expand(grip+ray*Model.lance_length(actor.fighter)).grow(5.0)

func fit_actor_camera(battle, actor) -> Rect2:
	# Use the production actor's own live bounds, plus its actual held/loose
	# weapon. This prevents the former fixture's clipped head/boots without
	# claiming the production camera has passed a framing test.
	var bounds: Rect2 = actor.world_body_rect().merge(weapon_rect(actor)).grow(28.0)
	var safe: Rect2 = battle.combat_safe_rect().grow(-20.0)
	var viewport_center = root.get_visible_rect().size*.5
	var zoom = minf(1.65,minf(safe.size.x/maxf(1.0,bounds.size.x),safe.size.y/maxf(1.0,bounds.size.y)))
	battle.camera.zoom = Vector2.ONE*zoom
	battle.camera.offset = Vector2.ZERO
	battle.camera.position = bounds.get_center()-(safe.get_center()-viewport_center)/zoom
	battle.camera.force_update_scroll()
	return bounds

func capture(battle, actor, name: String, stage: String) -> void:
	var restore_process = battle.is_processing()
	battle.set_process(false)
	var before_camera = {"position":str(battle.camera.position),"zoom":str(battle.camera.zoom),"offset":str(battle.camera.offset)}
	if is_instance_valid(actor):
		fit_actor_camera(battle,actor)
	await RenderingServer.frame_post_draw
	var record = {"case":name,"stage":stage,"wall_msec":Time.get_ticks_msec(),"engine_scale":Engine.time_scale,
		"phase":battle.match_model.phase,"camera_before_qa_fit":before_camera,"camera_qa_fit":is_instance_valid(actor)}
	if is_instance_valid(actor):
		var body_bounds: Rect2 = actor.world_body_rect()
		var transform = root.get_canvas_transform()
		var top_left: Vector2 = transform*body_bounds.position
		var bottom_right: Vector2 = transform*body_bounds.end
		var screen_bounds = Rect2(top_left,bottom_right-top_left)
		check(battle.combat_safe_rect().encloses(screen_bounds),"Fallen body must fit the captured combat safe area",{"case":name,"stage":stage,"screen":str(screen_bounds)})
		record.merge({"age":actor.age,"grounded":actor.grounded,"settled":actor.settled,"rotation":actor.rotation,
			"body_bounds":str(body_bounds),"body_screen_bounds":str(screen_bounds),"released":is_instance_valid(actor.loose_lance),
			"weapon_bounds":str(weapon_rect(actor)),"held_lance_visible":actor.visual.detached_lance_visible})
	if captures_enabled:
		var path = capture_dir+"/"+name+"_"+stage+".png"
		var error = root.get_texture().get_image().save_png(path)
		check(error==OK,"Fall scene screenshot saves",{"path":path,"error":error})
		record.path = path
	captures.append(record)
	battle.set_process(restore_process)
	print("FALL_SCENE_CAPTURE ",name," ",stage)

func assert_blood_off(battle, actor, name: String) -> void:
	check(not battle.effects.blood_enabled and not actor.visual.blood_enabled and not actor.far_leg.blood_enabled,"Blood-off reaches mounted effects and both fallen renderers",{"case":name})
	for view in battle.riders:
		check(not view.blood_enabled,"Blood-off reaches both mounted renderers",{"case":name})
	check(battle.effects.stains.is_empty(),"Blood-off cannot create ground stains",{"case":name})
	for particle in battle.effects.particles:
		check(not bool(particle.get("blood",false)),"Blood-off cannot create blood particles",{"case":name})

func find_button(parent: Node, label_text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text==label_text:
			return child
		var nested = find_button(child,label_text)
		if nested!=null:
			return nested
	return null

func injury_state(fighter: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["hp","ko","dead","wounds","shield","broken","durability","balance","damage_total","last_hit"]:
		result[key] = fighter.get(key)
	return result.duplicate(true)

func rule_state(model) -> Dictionary:
	var fighters: Array = []
	for fighter in model.fighters:
		fighters.append(injury_state(fighter))
	return {"fighters":fighters,"phase":model.phase,"mode":model.mode,"pass_number":model.pass_number,
		"result":model.result.duplicate(true),"rng_state":model.rng.state}

func blood_particle_count(battle) -> int:
	var count = 0
	for particle in battle.effects.particles:
		if bool(particle.get("blood",false)):
			count += 1
	return count

func blood_toggle_contract(battle, actor, defender: int, name: String) -> void:
	# Change the existing pause-menu CheckButton, allowing its real toggled
	# signal and production callback to run. This is engine UI automation,
	# not an OS mouse event or a direct call to effects.clear_blood().
	var failures_before = failures.size()
	var state = root.get_node("GameState")
	var rules_before = rule_state(battle.match_model)
	var injury_before = injury_state(actor.fighter)
	var blood_before = blood_particle_count(battle)
	var stains_before = battle.effects.stains.size()
	check(bool(state.profile.settings.blood) and battle.effects.blood_enabled and actor.visual.blood_enabled and actor.far_leg.blood_enabled,"Toggle fixture begins with blood enabled on both fallen renderers",{"case":name})
	check(not actor.fighter.wounds.is_empty() and actor.fighter.wounds==battle.match_model.fighters[defender].wounds,"Toggle fixture retains an actual contact wound on the detached rider",{"case":name})
	check(blood_before>0 and stains_before>0,"Real contact creates blood particles and stains before the UI toggle",{"case":name,"particles":blood_before,"stains":stains_before})
	await capture(battle,actor,name,"blood_on_before_toggle")
	var pause_button = find_button(battle.hud,"暂停 Esc")
	check(pause_button!=null,"Formal pause button exists for blood regression",{"case":name})
	if pause_button==null:
		return
	pause_button.pressed.emit()
	check(battle.paused and paused and is_instance_valid(battle.pause_panel),"Formal pause button opens a paused settings panel after a terminal hit",{"case":name})
	if not is_instance_valid(battle.pause_panel):
		return
	var blood_button = find_button(battle.pause_panel,"显示血腥表现")
	check(blood_button is CheckButton and blood_button.button_pressed,"Pause panel exposes the enabled blood CheckButton",{"case":name})
	if blood_button==null:
		battle._toggle_pause()
		return
	var toggle_count = [0]
	blood_button.toggled.connect(func(_value: bool): toggle_count[0] += 1)
	var actor_age = actor.age
	var nonblood_before = battle.effects.particles.size()-blood_particle_count(battle)
	blood_button.button_pressed = false
	check(toggle_count[0]==1,"Changing the actual blood CheckButton emits exactly one toggled signal",{"case":name,"signals":toggle_count[0]})
	check(not bool(state.profile.settings.blood) and not blood_button.button_pressed,"Pause callback persists blood-off in the isolated QA profile",{"case":name})
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	check(saved is Dictionary and not bool(saved.get("settings",{}).get("blood",true)),"The real pause callback writes blood-off to the QA save file",{"case":name,"save_path":state.save_path})
	assert_blood_off(battle,actor,name)
	check(rule_state(battle.match_model)==rules_before,"Blood toggle preserves HP, wounds, KO, death, result and rules RNG",{"case":name})
	check(injury_state(actor.fighter)==injury_before and injury_state(actor.visual.fighter)==injury_before and injury_state(actor.far_leg.fighter)==injury_before,"Blood toggle hides wound rendering without deleting the fallen injury snapshot",{"case":name})
	check(battle.effects.particles.size()==nonblood_before,"Blood toggle preserves existing nonblood contact particles",{"case":name})
	check(battle.paused and paused and is_equal_approx(actor.age,actor_age),"Blood toggle keeps the scene and fallen body paused",{"case":name})
	await capture(battle,actor,name,"blood_off_paused")
	var resume_button = find_button(battle.pause_panel,"继续对冲")
	check(resume_button!=null,"Formal resume button exists after blood toggle",{"case":name})
	if resume_button!=null:
		resume_button.pressed.emit()
	else:
		battle._toggle_pause()
	check(not battle.paused and not paused,"Formal resume restores the scene after blood toggle",{"case":name})
	assert_blood_off(battle,actor,name)
	check(rule_state(battle.match_model)==rules_before and injury_state(actor.fighter)==injury_before,"Resume preserves the terminal injury and outcome after blood toggle",{"case":name})
	blood_toggle_results.append({"case":name,"mode":battle.mode,"passed":failures.size()==failures_before,
		"blood_particles_before":blood_before,"stains_before":stains_before,"blood_particles_after":blood_particle_count(battle),
		"stains_after":battle.effects.stains.size(),"toggled_signal_count":toggle_count[0],"injury":injury_before,
		"evidence":"Existing pause/resume Button.pressed signals and existing blood CheckButton.button_pressed property emitting toggled; production callbacks execute. Scripted engine UI, not OS input."})

func assert_first_pose(battle, actor, defender: int, name: String) -> void:
	var fighter: Dictionary = battle.match_model.fighters[defender]
	var pose = Rider.arm_pose(fighter)
	var seated = Rider.seated_leg_pose(fighter)
	for side in ["left","right"]:
		for joint in ["shoulder","elbow","hand"]:
			check((actor.position+Vector2(actor.visual.detached_pose[side][joint])).distance_to(pose[side][joint])<.001,"Actual contact preserves the first detached arm pose",{"case":name,"side":side,"joint":joint})
	var mirror = Vector2(int(fighter.direction),1)
	var mounted_origin = Vector2(float(fighter.x),float(fighter.lane_y))
	for side in ["near","far"]:
		for joint in ["hip","knee","ankle","foot"]:
			var detached = actor.position+Vector2(actor.visual.detached_legs[side][joint])*mirror
			var mounted = mounted_origin+Vector2(seated[side][joint])*mirror
			check(detached.distance_to(mounted)<.001,"Actual contact preserves the first detached straddling legs",{"case":name,"side":side,"joint":joint,"distance":detached.distance_to(mounted)})
	check(actor.visual.fighter.stats==fighter.stats,"Actual fall retains equipped armor, heraldry and appearance",{"case":name})
	check(actor.visual.impact_velocity>0.0,"Same-frame terminal contact transfers impact velocity to the fallen renderer",{"case":name})
	check(is_equal_approx(actor.visual.impact_velocity,battle.riders[defender].impact_velocity),"Fallen renderer inherits the exact pending impact velocity",{"case":name})
	check(not actor.visual.detached_far_visible and actor.far_leg.detached_far_only,"Detached renderers draw the far leg only once",{"case":name})

func restart_contract(battle, actor, name: String) -> void:
	var old_battle = weakref(battle)
	var old_actor = weakref(actor)
	var old_lance = weakref(actor.loose_lance) if is_instance_valid(actor.loose_lance) else null
	battle.replay_requested.emit()
	var fresh = main.battle
	configure(fresh)
	await process_frame
	check(old_battle.get_ref()==null and old_actor.get_ref()==null,"Formal replay frees the previous scene and fallen rider",{"case":name})
	check(old_lance==null or old_lance.get_ref()==null,"Formal replay frees the released weapon",{"case":name})
	check(fresh.effects.bodies.is_empty() and fresh.effects.debris.is_empty(),"Formal replay begins without old falls or lance shards",{"case":name})
	check(is_equal_approx(Engine.time_scale,1.0),"Formal replay restores normal time scale",{"case":name})
	check(not fresh.effects.blood_enabled,"Formal replay retains blood-off",{"case":name})
	main._close_battle()
	await process_frame

func run_case(mode_name: String, attacker: int, zone: String, broken: bool, test_blood_toggle: bool = false) -> void:
	var defender = 1-attacker
	var name = "%s_%s_facing_%s_%s" % [mode_name,zone,"right" if defender==0 else "left","broken" if broken else "whole"]
	var battle = create_battle(mode_name,test_blood_toggle)
	var fixture = find_fixture(battle,attacker,zone,broken)
	check(not fixture.is_empty(),"A genuine swept terminal fixture exists",{"case":name})
	if fixture.is_empty():
		main._close_battle()
		await process_frame
		return
	prepare_model(battle.match_model,attacker,zone,broken,float(fixture.phase))
	var actual_hit: Dictionary = {}
	for tick in range(int(fixture.steps)):
		if tick==int(fixture.steps)-1:
			battle._update_views()
			for view in battle.riders:
				view._process(0.0)
			for settle_tick in range(60):
				battle._update_camera(1.0/60.0,Time.get_ticks_msec())
			battle._update_hud()
			await capture(battle,null,name,"pre_contact")
		var pending = step_model(battle.match_model,attacker,zone)
		if not pending.is_empty():
			battle._consume_events(pending)
			for event in pending:
				if event.type=="hit":
					actual_hit = event.duplicate(true)
		if not actual_hit.is_empty():
			break
		battle._update_views()
		for view in battle.riders:
			view._process(PHYSICS_DT)
	check(not actual_hit.is_empty() and actual_hit.get("zone","")==zone and int(actual_hit.get("defender",-1))==defender,"Formal Battle receives the requested real hit",{"case":name,"event":actual_hit})
	check(battle.effects.bodies.size()==1,"One real terminal event creates one complete fallen rider",{"case":name,"count":battle.effects.bodies.size()})
	if battle.effects.bodies.size()!=1:
		main._close_battle()
		await process_frame
		return
	var actor = battle.effects.bodies[0]
	actor.set_process(false)
	actor.visual.set_process(false)
	actor.far_leg.set_process(false)
	assert_first_pose(battle,actor,defender,name)
	check(bool(actual_hit.ko) and bool(actual_hit.dead)==(mode_name=="war"),"Arena remains nonfatal and war allows death independently of blood setting",{"case":name,"event":actual_hit})
	check(bool(actor.fighter.broken)==broken,"Fallen fighter preserves the fixture's whole/broken weapon state",{"case":name})
	if test_blood_toggle:
		await blood_toggle_contract(battle,actor,defender,name)
	assert_blood_off(battle,actor,name)
	battle._process(0.0)
	battle._update_views()
	await capture(battle,actor,name,"first_contact_detached")
	check(is_zero_approx(float(actor.age)),"First detached capture occurs before fall advancement",{"case":name,"age":actor.age})
	actor.set_process(true)
	actor.visual.set_process(true)
	actor.far_leg.set_process(true)
	for view in battle.riders:
		view.set_process(true)
	battle.set_process(true)
	var stages = {"first_contact":true}
	var max_recoil = 0.0
	var game_physics_time = 0.0
	var start_wall = Time.get_ticks_msec()
	for tick in range(1200):
		await physics_frame
		game_physics_time += float(Engine.time_scale)/float(Engine.physics_ticks_per_second)
		max_recoil = maxf(max_recoil,absf(float(actor.visual.impact_recoil)))
		check(actor.position.is_finite() and is_finite(actor.rotation),"Scene fall stays finite",{"case":name})
		check(actor.position.y+actor.lowest_body_point()<=actor.ground_y+.05,"Scene body and shield remain above their lane floor",{"case":name,"age":actor.age})
		assert_blood_off(battle,actor,name)
		if actor.age>=.06 and not stages.has("airborne"):
			stages.airborne = true
			await capture(battle,actor,name,"airborne")
		if actor.age>=.235 and not stages.has("released"):
			stages.released = true
			check(is_instance_valid(actor.loose_lance) and not actor.visual.detached_lance_visible,"The grip releases into a physical weapon by .235 game seconds",{"case":name,"age":actor.age})
			await capture(battle,actor,name,"released_023")
		if actor.grounded and not stages.has("landed"):
			stages.landed = true
			await capture(battle,actor,name,"landed")
		if actor.settled and game_physics_time>=2.8:
			stages.settled = true
			await capture(battle,actor,name,"settled")
			break
		if Time.get_ticks_msec()-start_wall>15000:
			break
	check(actor.settled and stages.has("settled") and stages.has("released") and stages.has("landed"),"Actual scene fall releases, lands and settles within the bounded observation",{"case":name,"stages":stages,"age":actor.age})
	check(max_recoil>.001,"A terminal hit produces visible nonzero inherited recoil",{"case":name,"max_recoil":max_recoil})
	if is_instance_valid(actor.loose_lance):
		var floor_global = battle.effects.to_global(Vector2(0,actor.ground_y)).y
		check(weapon_rect(actor).end.y<=floor_global+8.0,"Released weapon collides with its lane instead of remaining below ground",{"case":name,"bounds":str(weapon_rect(actor)),"ground_y":floor_global})
		check(actor.loose_lance.collision_mask==(32 if float(actor.fighter.lane_y)>=0 else 16),"Released weapon uses its actual lane collision mask",{"case":name})
	cases.append({"name":name,"mode":mode_name,"zone":zone,"defender":defender,"defender_weapon_broken":broken,
		"blood_toggle_exercised":test_blood_toggle,
		"fixture_phase":fixture.phase,"fixture_steps":fixture.steps,"actual_event":actual_hit,"stages":stages,
		"body_age":actor.age,"physics_game_seconds":game_physics_time,"wall_msec":Time.get_ticks_msec()-start_wall,
		"max_recoil":max_recoil,"grounded":actor.grounded,"settled":actor.settled,"released":is_instance_valid(actor.loose_lance)})
	await restart_contract(battle,actor,name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): report_path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--case-limit="): case_limit = maxi(0,int(arg.trim_prefix("--case-limit=")))
		if arg=="--no-captures": captures_enabled = false
		if arg=="--blood-toggle-only": blood_toggle_only = true
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Fall scene integration requires rendering and -- --test-profile")
		quit(1)
		return
	if FileAccess.file_exists(report_path):
		push_error("Choose a fresh fall scene report path")
		quit(2)
		return
	if captures_enabled and DirAccess.dir_exists_absolute(capture_dir):
		var existing = DirAccess.open(capture_dir)
		if existing!=null and not existing.get_files().is_empty():
			push_error("Choose a fresh fall scene capture directory")
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	if captures_enabled:
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
	main.set_process(false)
	var selected = 0
	for mode_name in ["arena","war"]:
		for attacker in [0,1]:
			for zone in ["head","body","flank"]:
				for broken in [false,true]:
					var test_blood_toggle = attacker==0 and zone=="head" and not broken
					if blood_toggle_only and not test_blood_toggle:
						continue
					if case_limit>0 and selected>=case_limit:
						continue
					selected += 1
					await run_case(mode_name,attacker,zone,broken,test_blood_toggle)
	main._close_battle()
	main.queue_free()
	await process_frame
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"cases":cases,"selected_cases":selected,"full_matrix_cases":24,
		"case_limit":case_limit,"blood_toggle_only":blood_toggle_only,"blood_toggle_results":blood_toggle_results,
		"captures":captures,"captures_enabled":captures_enabled,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),
		"evidence":"Actual Model.step swept hit replayed from selected initial state, formal Battle consumer and ordinary post-contact process/physics. Initial defender 1HP, no shield, no reciprocal attack, explicit whole/broken weapon state are contract fixtures, not natural AI balance. First selected head/left/whole case in each mode starts blood-on and switches it off through the existing pause-menu CheckButton toggled callback after a real wound and fall; other cases start blood-off. Every case invokes formal replay and checks freed rider/weapon. First contact freezes only for age0 evidence; subsequent fall and loose weapon use the real scene. Captures fit actual FallenRider.world_body_rect plus held/loose weapon with a QA camera override, so no claim that production camera framing or player feel passed. Scripted engine integration and UI signals, no OS input or human verdict."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Could not create fall scene report: "+report_path)
		quit(3)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FALL_SCENE_V050 passed=",report.passed," cases=",cases.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
