extends "test_exchange_v056.gd"
## GPU scene regression: actual finite-command swept contacts, not injected hits.
## Explicit high-stability / 1HP fixtures isolate mounted / fatal presentation.
## Pre-contact is staged at 120Hz, then ordinary Battle process/physics runs.
## Captured Image data is written only after the run; this is not an OS-input
## test, performance benchmark, or assertion that the game feels satisfying.
const Rider057 = preload("res://scripts/visual/rider_view.gd")
var case_limit = 0
var images: Array = []
var probe_rows: Array = []

func aim_for(model, attacker: int, zone: String) -> float:
	var defender: Dictionary = model.fighters[1-attacker]
	var target: Vector2 = Model.head_position(defender) if zone=="head" else (Model.shield_position(defender) if zone=="shield" else Model.body_position(defender))
	return asin(clampf((target.y-Model.hand_position(model.fighters[attacker]).y)/Model.lance_length(model.fighters[attacker]),-.629,.548))

func stage_model(model, attacker: int, zone: String, fatal: bool, phase: float, solid: bool = false, broken_fixture: bool = false) -> void:
	model.phase = "charge"
	model.rng.seed = 57051
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
		fighter.stats.stability = 1.5
		fighter.stats.reach = 247.0
		fighter.stats.armor = 0.0
		fighter.stats.helmet = 0.0
		fighter.stats.power = 1.0
		fighter.acted = index!=attacker
		fighter.guard = (0.0 if index==1 else 1.0) if solid and index!=attacker else .43
		fighter.guard_target = fighter.guard
		fighter.lean = 0.0
		fighter.lean_velocity = 0.0
		fighter.aim = .58
		fighter.hp = 1.0 if fatal and index!=attacker else 100.0
		fighter.shield = 100.0 if zone=="shield" else 0.0
		fighter.balance = 100.0
		fighter.ko = false
		fighter.dead = false
		fighter.broken = false
		fighter.durability = 1.0 if broken_fixture and index==attacker else 1000.0
		fighter.wounds = []
		fighter.lance_stability = 1.0
		fighter.gait_phase = phase
		fighter.gait_moving = true
		fighter.boost = true
		for key in ["acceleration","accel_command","motion_drive","reaction_angle","reaction_angular_velocity","reaction_shift","reaction_shift_velocity","shield_compression","shield_compression_velocity","lance_compression","lance_compression_velocity"]:
			fighter[key] = 0.0
	model.fighters[attacker].aim = aim_for(model,attacker,zone)
	for fighter in model.fighters: model._cache_pose(fighter)

func step_staged(model, attacker: int, zone: String) -> Array:
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		var before = float(fighter.aim)
		var target = aim_for(model,attacker,zone) if index==attacker else .58
		var committed = float(model.fighters[1].x)-float(model.fighters[0].x)<1100
		model.set_controls(index,target,0.0,true,PHYSICS_DT,float(fighter.guard_target))
		check(absf(float(fighter.aim)-before)<=(.95 if committed else 2.2)*PHYSICS_DT*float(fighter.stats.get("lance_handling",1.0))+.0001,"Staging bypassed finite lance travel")
	model.step(PHYSICS_DT)
	return model.drain_events()

func find_stage(battle, attacker: int, zone: String, fatal: bool, solid: bool = false, broken_fixture: bool = false) -> Dictionary:
	for phase in [0.0,.55,1.2,2.2,3.4,4.5]:
		var model = Model.new(battle.mode,battle.match_model.fighters[0].stats.duplicate(true),battle.match_model.fighters[1].stats.duplicate(true),57051)
		stage_model(model,attacker,zone,fatal,phase,solid,broken_fixture)
		for tick in range(360):
			for event in step_staged(model,attacker,zone):
				if event.type=="hit":
					if int(event.attacker)==attacker and str(event.zone)==zone and bool(event.ko)==fatal and (not solid or not bool(event.glanced)) and (not broken_fixture or bool(event.broke)):
						return {"gait_phase":phase,"ticks":tick+1,"preview":event.duplicate(true)}
			if model.phase=="ended": break
	return {}

func point_row(point: Vector2) -> Array:
	return [point.x,point.y]

func reaction_row(fighter: Dictionary) -> Dictionary:
	var neutral: Dictionary = fighter.duplicate(true)
	for key in ["reaction_angle","reaction_shift","shield_compression","lance_compression"]: neutral[key] = 0.0
	var pose: Dictionary = Rider057.arm_pose(fighter)
	var head_delta: Vector2 = Model.head_position(fighter)-Model.head_position(neutral)
	var hand_delta: Vector2 = Model.hand_position(fighter)-Model.hand_position(neutral)
	var shield_delta: Vector2 = Model.shield_position(fighter)-Model.shield_position(neutral)
	check(Vector2(pose.right.hand).distance_to(Model.hand_position(fighter))<.001,"Shared recoil separated right grip from rule hand")
	check(Vector2(pose.shield_center).distance_to(Model.shield_position(fighter))<.001,"Shared recoil separated shield art from rule shield")
	return {"head_delta":point_row(head_delta),"head_delta_length":head_delta.length(),"hand_delta":point_row(hand_delta),"shield_delta":point_row(shield_delta),"shield_delta_length":shield_delta.length(),"angle":fighter.get("reaction_angle",0),"shift":fighter.get("reaction_shift",0),"shield_compression":fighter.get("shield_compression",0),"lance_compression":fighter.get("lance_compression",0),"angular_velocity":fighter.get("reaction_angular_velocity",0),"aim":fighter.aim,"guard":fighter.guard,"hp":fighter.hp,"balance":fighter.balance,"x":fighter.x,"gait":fighter.gait_phase,"ko":fighter.ko,"dead":fighter.dead}

func actor_row(actor) -> Dictionary:
	if not is_instance_valid(actor): return {}
	var joints: Dictionary = {}
	for key in actor.joints:
		joints[key] = {"angle":actor.joints[key].angle,"velocity":actor.joints[key].velocity}
	return {"age":actor.age,"position":point_row(actor.position),"rotation":actor.rotation,"grounded":actor.grounded,"ground_age":actor.ground_age,"settled":actor.settled,"landing_speed":actor.landing_speed,"weapon_released":is_instance_valid(actor.loose_lance),"head_rotation":actor.visual.detached_pose.get("head_rotation",0),"joints":joints}

func observe(battle, actor, elapsed: float) -> Dictionary:
	var row = frame_record(battle,elapsed)
	row["response"] = [reaction_row(battle.match_model.fighters[0]),reaction_row(battle.match_model.fighters[1])]
	row["fallen"] = actor_row(actor)
	return row

func snapshot(battle, actor, name: String, stage: String, elapsed: float) -> void:
	battle._update_hud()
	battle.queue_redraw()
	for view in battle.riders: view.queue_redraw()
	if is_instance_valid(actor):
		actor.visual.queue_redraw()
		actor.far_leg.queue_redraw()
	await RenderingServer.frame_post_draw
	var row = observe(battle,actor,elapsed)
	row.merge({"case":name,"tag":stage,"path":capture_dir+"/"+name+"_"+stage+".png"})
	if captures_enabled: images.append({"image":root.get_texture().get_image(),"path":row.path})
	captures.append(row)

func live_case(attacker: int, zone: String, fatal: bool, slow: bool, solid: bool = false, broken_fixture: bool = false) -> void:
	var name = ("war_fatal" if fatal else "arena_mounted")+"_"+str(attacker)+"_"+zone+("_slow" if slow else "_off")+("_solid" if solid else "")+("_break" if broken_fixture else "")
	var battle = create_battle("war" if fatal else "arena",slow)
	var fixture = find_stage(battle,attacker,zone,fatal,solid,broken_fixture)
	check(not fixture.is_empty(),"Could not stage genuine swept "+name)
	if fixture.is_empty():
		main._close_battle()
		await process_frame
		return
	var model = battle.match_model
	stage_model(model,attacker,zone,fatal,float(fixture.gait_phase),solid,broken_fixture)
	if solid and attacker==1:
		battle.guard_slot = 0
	for tick in range(int(fixture.ticks)-1):
		var early = step_staged(model,attacker,zone)
		check(early.is_empty(),"Contact staging changed its deterministic boundary",{"case":name,"tick":tick})
	battle.pointer_aim = float(model.fighters[0].aim)
	battle._update_views()
	for view in battle.riders: view._process(0.0)
	for frame in range(90): battle._update_camera(1.0/60.0,Time.get_ticks_msec())
	await snapshot(battle,null,name,"before",0)
	var pending = step_staged(model,attacker,zone)
	var hits: Array = []
	for event in pending:
		if event.type=="hit": hits.append(event.duplicate(true))
	check(hits.size()==1 and str(hits[0].zone)==zone,"Live rule sweep missed selected zone",{"case":name,"events":pending})
	if solid and not hits.is_empty():
		check(not bool(hits[0].glanced),"Solid shield fixture actually glanced",{"case":name,"event":hits[0]})
		check(float(hits[0].speed)>700.0,"Solid shield fixture lost its real closing speed",{"case":name,"event":hits[0]})
	if broken_fixture and not hits.is_empty(): check(bool(hits[0].broke),"Low initial durability did not produce a genuine broken-lance event")
	battle._consume_events(pending)
	var fragments: Array = []
	for debris in battle.effects.debris:
		fragments.append({"position":point_row(debris.position),"rotation":debris.rotation,"linear_velocity":point_row(debris.linear_velocity),"angular_velocity":debris.angular_velocity})
	if broken_fixture:
		check(fragments.size()==2,"Broken contact did not preserve its two physical shaft sections",{"case":name,"fragments":fragments})
		if fragments.size()==2 and not hits.is_empty():
			var distal = battle.effects.debris[-1]
			var length = -1.0
			for child in distal.get_children():
				if child.get_script()==load("res://scripts/visual/lance_shard.gd"): length = float(child.length)
			var fragment_tip_global: Vector2 = distal.to_global(Vector2(length*.5,0))
			var fragment_tip_world: Vector2 = battle.world.to_local(fragment_tip_global)
			var original_tip: Vector2 = hits[0].break_tip
			check(length>0 and fragment_tip_world.distance_to(original_tip)<.01,"Breaking moved the distal shaft tip before physical flight",{"case":name,"length":length,"fragment_tip_global":point_row(fragment_tip_global),"fragment_tip_world_local":point_row(fragment_tip_world),"event_break_tip_world_local":point_row(original_tip),"error":fragment_tip_world.distance_to(original_tip)})
	battle.last_visual_time = Time.get_ticks_msec()-150
	battle._process(0.0)
	battle._update_views()
	for view in battle.riders: view._process(0.0)
	var actor = null
	if fatal and not battle.effects.bodies.is_empty():
		actor = battle.effects.bodies[-1]
		actor.set_process(false)
		actor.visual.set_process(false)
		actor.far_leg.set_process(false)
	check(battle.exchange_state.state=="contact" and battle.exchange_state.get("contact_loading",false),"Actual first-contact frame did not preserve loading stage",{"case":name,"state":battle.exchange_state})
	for fighter in model.fighters:
		var row = reaction_row(fighter)
		check(float(row.head_delta_length)<.001 and is_zero_approx(float(row.lance_compression)) and is_zero_approx(float(row.shield_compression)),"Contact injected a position teleport instead of response velocity",{"case":name,"response":row})
	if fatal:
		check(is_instance_valid(actor),"Fatal real contact did not create a continuous rider actor")
		if is_instance_valid(actor):
			for key in actor.joints:
				check(is_zero_approx(float(actor.joints[key].angle)),"Age-zero fall snapped an articulated joint",{"case":name,"joint":key})
			var mounted_pose: Dictionary = Rider057.arm_pose(model.fighters[1-attacker])
			for side in ["left","right"]:
				for joint in ["shoulder","elbow","hand"]:
					check((actor.position+Vector2(actor.visual.detached_pose[side][joint])).distance_to(mounted_pose[side][joint])<.001,"Actual fatal conversion separated a limb at contact",{"case":name,"side":side,"joint":joint})
	await snapshot(battle,actor,name,"first_contact",0)
	# Staged boundary snapshots are excluded from measured live time. From
	# here normal engine delta and production Battle processing own the run.
	battle.last_visual_time = Time.get_ticks_msec()
	for view in battle.riders: view.set_process(true)
	if is_instance_valid(actor):
		actor.set_process(true)
		actor.visual.set_process(true)
		actor.far_leg.set_process(true)
	battle.set_process(true)
	battle.set_physics_process(true)
	var start = Time.get_ticks_msec()
	var timeline: Array = []
	var seen: Dictionary = {}
	var max_loading_displacement = 0.0
	var max_shield_compression = 0.0
	var max_lance_compression = 0.0
	var previous_joint_angles: Dictionary = {}
	var airborne_joint_motion = 0.0
	var grounded_joint_motion = 0.0
	while Time.get_ticks_msec()-start<5000:
		await process_frame
		await RenderingServer.frame_post_draw
		var elapsed = float(Time.get_ticks_msec()-start)/1000.0
		var row = observe(battle,actor,elapsed)
		timeline.append(row)
		var defender: Dictionary = row.response[1-attacker]
		max_shield_compression = maxf(max_shield_compression,float(defender.shield_compression))
		max_lance_compression = maxf(max_lance_compression,float(row.response[attacker].lance_compression))
		if row.state.state=="contact": max_loading_displacement = maxf(max_loading_displacement,float(defender.head_delta_length))
		if not slow: check(row.state.state not in ["approach","read"],"Slow-motion disabled entered optional read stage")
		var tag = ""
		if row.state.hitstop and not seen.has("loaded_hold"): tag = "loaded_hold"
		elif row.state.state=="read" and not seen.has("read"): tag = "read"
		elif row.state.state=="release" and not seen.has("release"): tag = "release"
		if is_instance_valid(actor):
			if actor.age>.13 and not seen.has("airborne"): tag = "airborne"
			if is_instance_valid(actor.loose_lance) and not seen.has("weapon_release"): tag = "weapon_release"
			if actor.grounded and not seen.has("landed"): tag = "landed"
			if actor.settled and not seen.has("settled"): tag = "settled"
			for key in actor.joints:
				var angle = float(actor.joints[key].angle)
				if previous_joint_angles.has(key):
					var change = absf(angle-float(previous_joint_angles[key]))
					if actor.grounded: grounded_joint_motion += change
					else: airborne_joint_motion += change
				previous_joint_angles[key] = angle
		if not tag.is_empty():
			seen[tag] = true
			if captures_enabled: images.append({"image":root.get_texture().get_image(),"path":capture_dir+"/"+name+"_"+tag+".png"})
			var capture_row: Dictionary = row.duplicate(true)
			capture_row.merge({"case":name,"tag":tag,"path":capture_dir+"/"+name+"_"+tag+".png"})
			captures.append(capture_row)
		if not fatal and elapsed>.95: break
		if fatal and is_instance_valid(actor) and actor.settled:
			seen["settled"] = true
			break
	check(seen.has("loaded_hold"),"Rendered contact missed its short loaded hold",{"case":name,"seen":seen})
	if not fatal: check(max_loading_displacement>1.0,"Body response remained frozen throughout contact load/hold",{"case":name,"max_head_response":max_loading_displacement})
	check(max_lance_compression>.2,"Actual striking grip never accepted force from the lance",{"case":name,"compression":max_lance_compression})
	if zone=="shield": check(max_shield_compression>1.0,"Actual shield impact never displaced the shield and arm",{"case":name,"compression":max_shield_compression})
	if fatal:
		check(seen.has("weapon_release") and seen.has("landed") and seen.has("settled"),"Actual fallen rider did not release, land and settle",{"case":name,"seen":seen})
		check(airborne_joint_motion>.01 and grounded_joint_motion>.001,"Articulated fall locked joints in flight or at landing",{"case":name,"airborne_motion":airborne_joint_motion,"landing_motion":grounded_joint_motion})
	var summary = {"name":name,"attacker":attacker,"zone":zone,"fatal_fixture":fatal,"solid_shield_fixture":solid,"low_durability_break_fixture":broken_fixture,"slow_motion":slow,"fixture":fixture,"actual_events":hits,"break_fragments_at_event":fragments,"seen":seen,"contact_max_head_response_px":max_loading_displacement,"max_shield_compression":max_shield_compression,"max_lance_compression":max_lance_compression,"airborne_joint_travel_rad":airborne_joint_motion,"grounded_joint_travel_rad":grounded_joint_motion,"timeline":timeline}
	cases.append(summary)
	main._close_battle()
	await process_frame
	check(is_equal_approx(Engine.time_scale,1.0),"Closing a tested contact left non-unit global time scale")

func run() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v057/impact01.json"
	capture_dir = "E:/GALUMU/docs/development/screenshots/v057/impact01"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
		if arg.begins_with("--cases="): case_limit = int(arg.trim_prefix("--cases="))
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
		if arg=="--no-captures": captures_enabled = false
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("V057 impact requires actual GPU scene and isolated --test-profile")
		quit(2)
		return
	if FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(capture_dir):
		push_error("Use fresh report/capture paths for V057")
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
	var jobs: Array = []
	if suite=="solid":
		jobs = [[0,"shield",false,true,true,false],[1,"shield",false,true,true,true]]
	elif suite=="fatal":
		for attacker in range(2):
			for zone in ["head","body"]: jobs.append([attacker,zone,true,true,false,false])
	else:
		for attacker in range(2):
			for zone in ["shield","head","body"]: jobs.append([attacker,zone,false,true,false,false])
		for attacker in range(2):
			for zone in ["head","body"]: jobs.append([attacker,zone,true,true,false,false])
		jobs.append([0,"shield",false,false,false,false])
	for job in jobs:
		if case_limit>0 and cases.size()>=case_limit: break
		await live_case(job[0],job[1],job[2],job[3],job[4],job[5])
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main._close_battle()
	main.queue_free()
	await process_frame
	for item in images:
		var error = item.image.save_png(item.path)
		check(error==OK,"Failed to save rendered impact evidence",{"path":item.path,"error":error})
	images.clear()
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"suite":suite,"cases":cases,"captures":captures,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"scope":"Real Model 120Hz finite-command sweeps staged at contact; actual Battle normal process/physics afterwards. Default: six left/right helmet/chest/shield nonterminal and four left/right head/chest fatal 1HP fixtures, plus slow-off shield. Optional fatal suite runs only the four left/right head/chest fatal fixtures and captures the actual first settled frame. Optional solid suite: two genuine non-glancing high-speed shield sweeps in opposite directions, one initial 1-durability lance; neither glanced nor broke event is forced. GPU snapshots saved after live timing avoid PNG stalls. High stability, 1HP and low durability are explicit presentation fixtures, not balance or manual/OS play. Numerical checks verify continuous force transfer; human screenshot/motion/audio review remains required."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("IMPACT_V057 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
