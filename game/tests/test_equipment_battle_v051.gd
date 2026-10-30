extends SceneTree
## Production Main/Battle consumers + genuine Model swept contacts. A compact
## rendered regression, not autonomous AI play, OS input or a balance test.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Lance = preload("res://scripts/visual/lance_art.gd")
const Shard = preload("res://scripts/visual/lance_shard.gd")
const DT = 1.0/120.0
const COUNTRIES = ["eng","fr","de","it"]
var main: Node
var state: Node
var items: Array = []
var failures: Array[String] = []
var examples: Array = []
var rows: Array = []
var shots: Array = []
var report_path = "E:/GALUMU/docs/development/logs/v051/equipment-battle01.json"
var capture_dir = "E:/GALUMU/docs/development/screenshots/v051/equipment-battle01"
var captures_enabled = true
var started = 0
var budget_ms = 55000
var original_profile: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	if ok: return
	if message not in failures: failures.append(message)
	if examples.size()<48: examples.append({"message":message,"context":context.duplicate(true)})
	push_error(message+" "+str(context))

func configure(battle) -> void:
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	for view in battle.riders: view.set_process(false)
	battle.effects.set_process(false)
	battle.sound.music.stop()
	battle.exchange_director.reset(1)
	battle.exchange_state = battle.exchange_director.sample()
	battle.contact_first_frame_pending = false
	battle.contact_audio.clear()

func prepare(model, attacker: int, terminal: bool, spent_lance: bool) -> void:
	model.phase = "charge"
	model.phase_time = 0.0
	model.rng.seed = 510517
	model.events.clear()
	model.result.clear()
	model.time_elapsed = 0.0
	model.time_effect_active = false
	for i in range(2):
		var f: Dictionary = model.fighters[i]
		f.x = -720.0 if i==0 else 720.0
		f.direction = 1 if i==0 else -1
		f.speed = 480.0
		f.stamina = 100.0
		f.acted = i!=attacker
		f.aim = .58
		f.lean = 0.0
		f.lean_velocity = 0.0
		f.guard = 1.0
		f.guard_target = 1.0
		f.shield = 0.0
		f.hp = 1.0 if terminal and i!=attacker else 100.0
		f.balance = 100.0
		f.ko = false
		f.dead = false
		f.broken = false
		f.durability = 1.0 if spent_lance and i==attacker else float(f.stats.get("durability",100.0))
		f.wounds = []
		f.lance_stability = 1.0
		f.gait_phase = 0.0 if i==0 else 1.1
		f.gait_moving = true
		f.acceleration = 0.0
		f.accel_command = 0.0
		f.motion_drive = 0.0
		model._cache_pose(f)

func target_aim(model, attacker: int, zone: String) -> float:
	var a: Dictionary = model.fighters[attacker]
	var b: Dictionary = model.fighters[1-attacker]
	var target = Model.head_position(b) if zone=="head" else Model.body_position(b)
	return asin(clampf((target.y-Model.hand_position(a).y)/Model.lance_length(a),-.629,.548))

func step_controls(model, attacker: int, zone: String) -> Dictionary:
	var maximum_aim_step = 0.0
	var maximum_guard_step = 0.0
	var target = target_aim(model,attacker,zone)
	for i in range(2):
		var f: Dictionary = model.fighters[i]
		var before_aim = float(f.aim)
		var before_guard = float(f.guard)
		model.set_controls(i,target if i==attacker else .58,0.0,true,DT,0.0)
		var aim_step = absf(float(f.aim)-before_aim)
		var guard_step = absf(float(f.guard)-before_guard)
		maximum_aim_step = maxf(maximum_aim_step,aim_step)
		maximum_guard_step = maxf(maximum_guard_step,guard_step)
		check(aim_step<=DT*2.2*float(f.stats.get("lance_handling",1.0))+.000001,"Fixture aims through production finite controls")
		check(guard_step<=DT*2.8*float(f.stats.get("shield_handling",1.0))+.000001,"Fixture guards through production finite controls")
	model.step(DT)
	return {"events":model.drain_events(),"aim_step":maximum_aim_step,"guard_step":maximum_guard_step}

func sync_views(battle) -> void:
	battle._update_views()
	for view in battle.riders:
		view._process(0.0)
		view.queue_redraw()
	for i in range(18): battle._update_camera(1.0/30.0,Time.get_ticks_msec())
	battle._update_hud()
	battle.camera.force_update_scroll()

func freeze_children(battle) -> void:
	# Do not freeze RigidBody2D fragments: unfreezing can discard their initial
	# launch velocities. The real hitstop already bounds first-frame motion.
	for actor in battle.effects.bodies:
		actor.set_process(false)
		actor.visual.set_process(false)
		actor.far_leg.set_process(false)

func snapshot(name: String, battle, save_png: bool) -> void:
	sync_views(battle)
	await process_frame
	await RenderingServer.frame_post_draw
	if save_png and captures_enabled:
		var path = capture_dir.path_join(name+".png")
		var image = root.get_texture().get_image()
		var error = image.save_png(path) if image!=null else ERR_UNAVAILABLE
		check(error==OK,"Actual battle render saves",{"name":name,"error":error})
		shots.append({"name":name,"path":path,"saved":error==OK,"phase":battle.match_model.phase,"scale":Engine.time_scale,"camera_qa_settle":true})

func verify_renderer(view, helmet_id: String, armor_id: String, name: String) -> void:
	check(str(view.fighter.stats.get("helmet_art",""))==helmet_id and str(view.fighter.stats.get("armor_art",""))==armor_id,"Mounted renderer retains exact equipped IDs",{"case":name})
	check(view.head_texture!=null and view.head_texture==Art.equipment_texture(view.fighter.stats,"helmet"),"Mounted helmet uses the imported authored texture",{"case":name})
	check(view.torso_texture!=null and view.torso_texture==Art.equipment_texture(view.fighter.stats,"armor"),"Mounted torso uses the imported authored texture",{"case":name})

func shard_records(battle, expected: Dictionary, event: Dictionary) -> Array:
	var result: Array = []
	var cursor = 66.0
	check(battle.effects.debris.size()==2,"Real broken hit creates two physical fragments")
	for body in battle.effects.debris:
		for child in body.get_children():
			if child.get_script()!=Shard: continue
			check(child.equipment==expected,"Fragment keeps actual authored lance stats")
			check(is_equal_approx(child.source_start,cursor) and is_equal_approx(child.full_length,float(event.break_reach)),"Fragment retains source segment coordinates")
			var midpoint = float(child.source_start)+float(child.length)*.5
			var radius = Lance.radius(expected,midpoint,float(child.full_length))
			result.append({"source_start":child.source_start,"length":child.length,"full_length":child.full_length,"radius_mid":radius,"pointed":child.pointed,"mode_tip":"war" if child.war_tip else "arena","position":str(body.position),"rotation":body.rotation,"collision_layer":body.collision_layer,"collision_mask":body.collision_mask})
			cursor += float(child.length)
	check(is_equal_approx(cursor,float(event.break_reach)),"Fragment segments cover the original broken forward shaft")
	return result

func verify_fallen(actor, expected: Dictionary, battle, name: String) -> void:
	for renderer in [actor.visual,actor.far_leg]:
		check(str(renderer.fighter.stats.get("helmet_art",""))==str(expected.get("helmet_art","")) and str(renderer.fighter.stats.get("armor_art",""))==str(expected.get("armor_art","")),"Fallen renderers retain the exact helmet and body art IDs",{"case":name})
		check(renderer.mode==battle.mode,"Fallen renderer keeps actual battle mode",{"case":name})
	check(actor.fighter.stats==expected,"Fall snapshots retain material, stats, decoration and appearance",{"case":name})
	check(not actor.visual.detached_pose.is_empty() and not actor.visual.detached_legs.is_empty(),"Fallen rider uses actual captured arm/leg skeleton",{"case":name})

func observe_release(battle, name: String, actor = null) -> Dictionary:
	# Fast-forward the pure presentation director AFTER its real first-contact
	# frame. This is not a wall-clock timing test; existing timing tests own it.
	battle._advance_exchange(1.0)
	var fragment_start: Array = []
	for body in battle.effects.debris:
		fragment_start.append({"position":body.position,"rotation":body.rotation,"velocity":body.linear_velocity,"angular_velocity":body.angular_velocity})
	if is_instance_valid(actor):
		actor.set_process(true)
		actor.visual.set_process(true)
		actor.far_leg.set_process(true)
	var start_wall = Time.get_ticks_msec()
	var physics_ticks = 0
	while physics_ticks<90 and Time.get_ticks_msec()-start_wall<1800:
		await physics_frame
		physics_ticks += 1
		if is_instance_valid(actor):
			if actor.age>=.28: break
		elif physics_ticks>=22:
			break
	var record = {"wall_msec":Time.get_ticks_msec()-start_wall,"physics_ticks":physics_ticks,"presentation_director_fast_forwarded":true}
	if is_instance_valid(actor):
		check(actor.age>=.22 and is_instance_valid(actor.loose_lance),"Actual scene fall releases a physical weapon within bounded observation",{"case":name,"age":actor.age})
		check(not actor.visual.detached_lance_visible,"Released weapon replaces held weapon without duplicate draw",{"case":name})
		if is_instance_valid(actor.loose_lance):
			for child in actor.loose_lance.get_children():
				if child is RiderView:
					check(child.fighter.stats==actor.fighter.stats and child.mode==battle.mode,"Released fallen weapon preserves actual art/stat snapshot",{"case":name})
		var bounds: Rect2 = actor.world_body_rect().grow(35.0)
		var safe: Rect2 = battle.combat_safe_rect().grow(-20.0)
		var zoom = minf(1.5,minf(safe.size.x/maxf(1,bounds.size.x),safe.size.y/maxf(1,bounds.size.y)))
		battle.camera.zoom = Vector2.ONE*zoom
		battle.camera.position = bounds.get_center()-(safe.get_center()-root.get_visible_rect().size*.5)/zoom
		battle.camera.offset = Vector2.ZERO
		battle.camera.force_update_scroll()
		record.fall_age = actor.age
		record.weapon_released = is_instance_valid(actor.loose_lance)
		record.camera_qa_fit = true
		# Freeze before PNG readback; it is a staged live-physics pose, not a
		# claim that PNG encoding itself measures a real-time fall duration.
		actor.set_process(false)
		await RenderingServer.frame_post_draw
		if captures_enabled:
			var path = capture_dir.path_join(name+"_released.png")
			var error = root.get_texture().get_image().save_png(path)
			check(error==OK,"Released fall battle render saves",{"case":name})
			shots.append({"name":name+"_released","path":path,"saved":error==OK,"camera_qa_fit":true})
	else:
		var positions: Array = []
		var advanced = false
		for i in range(battle.effects.debris.size()):
			var body = battle.effects.debris[i]
			positions.append(str(body.position))
			advanced = advanced or absf(body.position.x-fragment_start[i].position.x)>1.0 or absf(body.rotation-fragment_start[i].rotation)>.01
		check(advanced,"Broken fragments retain physical launch velocity and tumble; not only gravity")
		record.fragment_initial_physics = fragment_start
		record.fragment_positions_after_physics = positions
		await snapshot(name+"_flying",battle,true)
	return record

func teardown(battle, name: String) -> void:
	var old = weakref(battle)
	var nodes: Array = []
	for actor in battle.effects.bodies:
		nodes.append(weakref(actor))
		if is_instance_valid(actor.loose_lance): nodes.append(weakref(actor.loose_lance))
	for body in battle.effects.debris: nodes.append(weakref(body))
	main._close_battle()
	check(is_equal_approx(Engine.time_scale,1.0) and not paused,"Formal scene exit restores normal time and unpauses",{"case":name})
	await process_frame
	await process_frame
	check(old.get_ref()==null,"Formal scene exit frees old Battle",{"case":name})
	for node in nodes: check(node.get_ref()==null,"Formal scene exit frees fallen bodies and physical weapons",{"case":name})

func run_case(country: String, tier: int, mode_name: String, attacker: int, kind: String = "catalogue") -> void:
	var name = "%s_%d_%s_attack%d_%s" % [country,tier,mode_name,attacker,kind]
	var helmet_id = "%s_helmet_%d" % [country,tier]
	var armor_id = "%s_armor_%d" % [country,tier]
	var weapon_type = "stout" if kind=="break" else ["light","long","stout"][tier%3]
	state.profile.equipped.helmet = helmet_id
	state.profile.equipped.armor = armor_id
	state.profile.equipped.lance = "%s_lance_%s_%d" % [country,weapon_type,tier]
	check(not Catalogue.find(items,str(state.profile.equipped.lance)).is_empty(),"Actual regional lance ID exists",{"case":name,"id":state.profile.equipped.lance})
	var stats = state.player_stats().duplicate(true)
	var plain = stats.duplicate(true)
	plain.leg_decoration = 0
	state.profile.settings.slow_motion = true
	main._start_match(mode_name,true)
	var battle = main.battle
	configure(battle)
	# Keep the production Main-created Model and all scene bindings. Assign
	# the same catalogue gear to the opponent for symmetric art fixtures.
	for f in battle.match_model.fighters: f.stats = stats.duplicate(true)
	var terminal = kind=="fall"
	var spent = kind=="break"
	prepare(battle.match_model,attacker,terminal,spent)
	var comparison = Model.new(mode_name,plain,plain,510517)
	prepare(comparison,attacker,terminal,spent)
	var zone = "head" if terminal else "body"
	var hit: Dictionary = {}
	var steps = 0
	var source_saved = false
	var max_aim_step = 0.0
	var max_guard_step = 0.0
	for tick in range(420):
		if not source_saved and absf(float(battle.match_model.fighters[1].x)-float(battle.match_model.fighters[0].x))<500:
			await snapshot(name+"_source",battle,spent)
			for view in battle.riders: verify_renderer(view,helmet_id,armor_id,name)
			source_saved = true
		var actual = step_controls(battle.match_model,attacker,zone)
		var without_trim = step_controls(comparison,attacker,zone)
		max_aim_step = maxf(max_aim_step,float(actual.aim_step))
		max_guard_step = maxf(max_guard_step,float(actual.guard_step))
		check(actual.events==without_trim.events,"Leg decoration changes neither swept contact nor injury outcome",{"case":name,"tick":tick})
		for event in actual.events:
			if event.type=="hit": hit = event.duplicate(true)
		if not actual.events.is_empty(): battle._consume_events(actual.events)
		steps = tick+1
		if not hit.is_empty(): break
		if battle.match_model.phase!="charge": break
	check(not hit.is_empty() and int(hit.get("attacker",-1))==attacker and str(hit.get("zone",""))==zone,"Actual finite-control swept contact reaches the intended equipment zone",{"case":name,"hit":hit,"steps":steps})
	check(battle.exchange_log.size()==1,"Formal Battle consumes the genuine contact exactly once",{"case":name})
	for i in range(2):
		var f: Dictionary = battle.match_model.fighters[i]
		check(is_equal_approx(float(f.stats.armor),float(stats.armor)) and is_equal_approx(float(f.stats.helmet),float(stats.helmet)),"Equipment and leg trim never add numerical armor",{"case":name})
		for anchor in ["head","body","flank","shield"]:
			var a = Model.head_position(f) if anchor=="head" else (Model.body_position(f) if anchor=="body" else (Model.flank_position(f) if anchor=="flank" else Model.shield_position(f)))
			var g: Dictionary = comparison.fighters[i]
			var b = Model.head_position(g) if anchor=="head" else (Model.body_position(g) if anchor=="body" else (Model.flank_position(g) if anchor=="flank" else Model.shield_position(g)))
			check(a.distance_to(b)<.000001,"Leg decoration does not move actual hit-zone anchors",{"case":name,"zone":anchor})
	freeze_children(battle)
	battle._process(0.0)
	await snapshot(name+"_contact",battle,tier==5 or kind!="catalogue")
	for view in battle.riders: verify_renderer(view,helmet_id,armor_id,name)
	check(source_saved,"Each set has an actual mounted pre-contact render",{"case":name})
	var row = {"case":name,"country":country,"tier":tier,"mode":mode_name,"attacker":attacker,"direction":1 if attacker==0 else -1,"kind":kind,"helmet_art":helmet_id,"armor_art":armor_id,"lance_id":state.profile.equipped.lance,"actual_hit":hit,"steps":steps,"simulation_seconds":steps*DT,"max_aim_step":max_aim_step,"max_guard_step":max_guard_step,"presentation_scale_at_contact":Engine.time_scale,"same_events_without_leg_trim":true,"mounted_source_rendered":source_saved,"fixture":{"initial_x":[-720,720],"initial_speed":480,"opponent_already_acted":true,"shields_disabled":true,"initial_defender_hp":1 if terminal else 100,"initial_attacker_durability":1 if spent else stats.get("durability",100),"armor_values_are_original_catalogue":true}}
	if spent and not hit.is_empty():
		check(bool(hit.broke),"Spent-lance state causes a real rule-generated break",{"case":name})
		row.fragments = shard_records(battle,stats,hit)
		row.release_observation = await observe_release(battle,name)
	if terminal and not hit.is_empty():
		check(bool(hit.ko) and bool(hit.dead) and mode_name=="war","Initial1HP war fixture produces actual fatal KO",{"case":name,"hit":hit})
		check(battle.effects.bodies.size()==1,"Actual KO creates one production fallen rider",{"case":name})
		if battle.effects.bodies.size()==1:
			var actor = battle.effects.bodies[0]
			verify_fallen(actor,stats,battle,name)
			row.fallen_ids = {"helmet":actor.visual.fighter.stats.get("helmet_art"),"armor":actor.visual.fighter.stats.get("armor_art")}
			row.release_observation = await observe_release(battle,name,actor)
			verify_fallen(actor,stats,battle,name)
			check(actor.visual.head_texture==Art.equipment_texture(stats,"helmet") and actor.visual.torso_texture==Art.equipment_texture(stats,"armor"),"Actual fallen draw uses the same imported equipment textures",{"case":name})
	rows.append(row)
	print("EQUIPMENT_BATTLE_V051 case=",name," hit=",hit.get("zone","missing")," broke=",hit.get("broke",false)," ko=",hit.get("ko",false))
	await teardown(battle,name)

func finish() -> void:
	var covered: Dictionary = {}
	var combinations: Dictionary = {}
	for row in rows:
		if row.kind=="catalogue":
			covered[str(row.country)+"/"+str(row.tier)] = true
			combinations[str(row.mode)+"/"+str(row.direction)] = true
	check(covered.size()==24 and combinations.size()==4,"All24 gear pairs and both modes/directions are sampled")
	if is_instance_valid(main):
		main._close_battle()
		main.queue_free()
		await process_frame
		await process_frame
	if state and not original_profile.is_empty(): state.profile = original_profile
	check(is_equal_approx(Engine.time_scale,1.0) and not paused,"Final teardown restores global time/paused state")
	var result = {"passed":failures.is_empty() and rows.size()==26,"failures":failures,"examples":examples,"rows":rows,"captures":shots,"wall_msec":Time.get_ticks_msec()-started,"scope":"24 catalogue helmet/body pairs, each with one genuine body swept contact through finite Model controls and production Main/Battle consumers. Modes and attack directions sampled, not full Cartesian coverage. Additional spent-durability arena break and initial1HP war head KO/fallen release. All scene contact states rendered; selected PNGs. Engine fixtures, not OS input, autonomous AI, human play, real-time presentation timing or a full-match soak.","fixture_limits":"Same actual catalogue stats assigned to both riders; shields disabled and other rider already acted. Initial speed480/x±720. Special break starts durability1 and fall defender1HP. Model stepped at120Hz; camera manually settled for captures; presentation director fast-forwarded after first frame only in release observations. No player profile written."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	else:
		push_error("Cannot write equipment battle report")
		quit(2)
		return
	print("EQUIPMENT_BATTLE_V051 passed=",result.passed," cases=",rows.size()," wall_msec=",result.wall_msec)
	quit(0 if result.passed else 1)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg = str(args[i])
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg=="--report" and i+1<args.size(): report_path = str(args[i+1])
		elif arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
		elif arg=="--captures" and i+1<args.size(): capture_dir = str(args[i+1])
		elif arg=="--no-captures": captures_enabled = false
		elif arg.begins_with("--budget-ms="): budget_ms = clampi(int(arg.trim_prefix("--budget-ms=")),10000,120000)
	started = Time.get_ticks_msec()
	state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Equipment battle needs a renderer and -- --test-profile")
		quit(2)
		return
	if FileAccess.file_exists(report_path):
		push_error("Use a fresh equipment battle report path")
		quit(2)
		return
	if captures_enabled and DirAccess.dir_exists_absolute(capture_dir):
		var folder = DirAccess.open(capture_dir)
		if folder!=null and not folder.get_files().is_empty():
			push_error("Use a fresh equipment battle capture directory")
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	original_profile = state.profile.duplicate(true)
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.settings.blood = false
	state.profile.settings.shake = false
	state.profile.settings.aim_cues = false
	items = Catalogue.load_items()
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	for country_index in range(COUNTRIES.size()):
		for tier in range(6):
			if Time.get_ticks_msec()-started>budget_ms:
				check(false,"Compact regression exceeded its wall budget; remaining cases not claimed")
				await finish()
				return
			await run_case(COUNTRIES[country_index],tier,"arena" if (country_index+tier)%2==0 else "war",tier%2)
	await run_case("de",5,"arena",0,"break")
	await run_case("it",5,"war",1,"fall")
	await finish()
