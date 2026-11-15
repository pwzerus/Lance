extends SceneTree
## FEEL-097 evidence. Three parts, selected with --part=:
##   matrix  staged grids (GPU): mounted reaction by zone x force, and falls by
##           zone/reason x speed asymmetry (equal, defender fast, defender slow).
##   battle  production Battle scene (GPU): genuine Model swept contacts with the
##           real camera, cinematic clock and shake; timeline + filmstrip frames.
##   timing  ExchangeDirector wall-clock stages for light/medium/heavy/KO events.
## Grids use direct Model contacts and fixed speeds; they are presentation
## fixtures, not balance evidence, OS input or a player verdict.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Fallen = preload("res://scripts/visual/fallen_rider.gd")
const Exchange = preload("res://scripts/visual/exchange_director.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")

const ZONES = ["head","body","flank","shield"]
const FORCES = {"light":320.0,"medium":640.0,"heavy":960.0}
const SPEED_CASES = [
	{"name":"equal","def":480.0,"att":480.0},
	{"name":"def_fast","def":480.0,"att":150.0},
	{"name":"def_slow","def":150.0,"att":480.0}]
const FALL_KINDS = ["head","body","flank","balance"]

var part = "matrix"
var report_path = ""
var capture_dir = ""
var failures: Array[String] = []
var report: Dictionary = {}
var main: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func save_frame(name: String) -> String:
	var path = capture_dir+"/"+name+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Capture saves")
	return path

func label(parent: Node, text: String, at: Vector2, size: int = 14) -> void:
	var l = Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size",size)
	parent.add_child(l)

func cell(origin: Vector2, size: Vector2, anchor: Vector2, scale_value: float) -> Node2D:
	var clip = Control.new()
	clip.position = origin
	clip.size = size
	clip.clip_contents = true
	root.add_child(clip)
	var frame = ColorRect.new()
	frame.color = Color(0,0,0,.18)
	frame.size = size-Vector2(4,4)
	frame.position = Vector2(2,2)
	clip.add_child(frame)
	var stage = Node2D.new()
	stage.position = anchor
	stage.scale = Vector2.ONE*scale_value
	clip.add_child(stage)
	var ground = Line2D.new()
	ground.points = PackedVector2Array([Vector2(-2000,12),Vector2(2000,12)])
	ground.width = 2
	ground.default_color = Color("a99664")
	stage.add_child(ground)
	return stage

# ---------------------------------------------------------------- matrix ----

func zone_point(fighter: Dictionary, zone: String) -> Vector2:
	match zone:
		"head": return Model.head_position(fighter)
		"flank": return Model.flank_position(fighter)
		"shield": return Model.shield_position(fighter)
	return Model.body_position(fighter)

func mounted_fixture(zone: String, force: String) -> Dictionary:
	var model = Model.new("arena",{"stability":3.0},{"stability":3.0},97)
	var defender: Dictionary = model.fighters[0]
	var attacker: Dictionary = model.fighters[1]
	defender.x = 0.0
	defender.lane_y = 0.0
	defender.direction = 1
	defender.speed = 400.0
	defender.gait_moving = true
	defender.gait_phase = .6
	defender.aim = .12
	defender.lean = 0.0
	defender.guard = .43 if zone=="shield" else .10
	defender.balance = 1000.0
	attacker.speed = 400.0
	var event = {"type":"hit","attacker":1,"defender":0,"zone":zone,"speed":float(FORCES[force]),"position":zone_point(defender,zone),
		"attacker_speed":float(FORCES[force])*.5,"defender_speed":float(FORCES[force])*.5}
	model._apply_contact(event)
	return {"model":model,"event":event,"defender":defender}

func run_matrix_mounted() -> void:
	var back = ColorRect.new()
	back.color = Color("21382f")
	back.size = Vector2(1440,900)
	root.add_child(back)
	var rows: Array = []
	var views: Array = []
	var force_names = FORCES.keys()
	for zi in range(ZONES.size()):
		for fi in range(force_names.size()):
			var zone: String = ZONES[zi]
			var force: String = force_names[fi]
			var fixture = mounted_fixture(zone,force)
			var origin = Vector2(zi*360,30+fi*290)
			var stage = cell(origin,Vector2(360,290),Vector2(150,265),.62)
			var view = Rider.new()
			view.fighter = fixture.defender
			view.moving = true
			view.mode = "arena"
			view.set_process(false)
			stage.add_child(view)
			var event: Dictionary = fixture.event
			var strength = clampf(Exchange.contact_strength(event),.15,1.0)
			view.receive_impact(strength,zone=="shield")
			view.receive_contact(event)
			label(root,"%s / %s  冲量%d  强度%.2f" % [zone,force,roundi(float(event.impulse)),strength],origin+Vector2(8,4),13)
			views.append(view)
			rows.append({"zone":zone,"force":force,"impulse":float(event.impulse),"strength":strength,"ko":bool(event.ko),
				"peak":{},"fixture":fixture})
	label(root,"FEEL-097 骑乘受击：列=部位(头/胸/腰腹/盾)  行=力度(轻/中/重)",Vector2(8,8),13)
	var keys = ["reaction_angle","reaction_neck","reaction_shift","shield_compression","shield_twist","reaction_legs","reaction_horse"]
	var capture_frames = [0,3,6,10,16,26,40,60]
	var frames: Array = []
	for frame in range(61):
		if frame in capture_frames:
			for view in views: view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			frames.append({"frame":frame,"seconds":frame/60.0,"path":save_frame("mounted_%02d" % frame)})
		for i in range(views.size()):
			var fighter: Dictionary = rows[i].fixture.defender
			Model.advance_reaction(fighter,1.0/60.0)
			fighter.gait_phase = float(fighter.gait_phase)+TAU*Gait.frequency(float(fighter.speed))/60.0
			views[i]._process(1.0/60.0)
			for key in keys:
				if fighter.has(key):
					rows[i].peak[key] = maxf(float(rows[i].peak.get(key,0.0)),absf(float(fighter[key])))
			rows[i].peak["view_impact_recoil"] = maxf(float(rows[i].peak.get("view_impact_recoil",0.0)),absf(float(views[i].impact_recoil)))
	for row in rows: row.erase("fixture")
	report.mounted = {"rows":rows,"frames":frames}
	for child in root.get_children():
		if child is Control: child.queue_free()
	await process_frame

func fall_event(kind: String, speeds: Dictionary) -> Dictionary:
	var closing = float(speeds.def)+float(speeds.att)
	var zone = "body" if kind=="balance" else kind
	var factor = {"head":.86,"body":1.18,"flank":1.28}[zone]
	var impulse = 30.0 if kind=="balance" else closing*.085*factor
	return {"type":"hit","zone":zone,"impulse":impulse,"speed":closing,"direction":-1,"attacker":1,"defender":0,
		"attacker_speed":float(speeds.att),"defender_speed":float(speeds.def),"attacker_direction":-1,"defender_direction":1,
		"ko":true,"ko_reason":"balance" if kind=="balance" else "impact"}

func run_matrix_falls() -> void:
	var back = ColorRect.new()
	back.color = Color("21382f")
	back.size = Vector2(1440,900)
	root.add_child(back)
	var actors: Array = []
	var horses: Array = []
	var rows: Array = []
	for ki in range(FALL_KINDS.size()):
		for si in range(SPEED_CASES.size()):
			var kind: String = FALL_KINDS[ki]
			var speeds: Dictionary = SPEED_CASES[si]
			var origin = Vector2(si*480,24+ki*219)
			var stage = cell(origin,Vector2(480,219),Vector2(240,190),.40)
			var marker = Line2D.new()
			marker.points = PackedVector2Array([Vector2(0,-380),Vector2(0,12)])
			marker.width = 3
			marker.default_color = Color(1,.85,.3,.55)
			stage.add_child(marker)
			var model = Model.new("arena",{},{},97)
			var fighter: Dictionary = model.fighters[0]
			fighter.x = 0.0
			fighter.lane_y = 0.0
			fighter.direction = 1
			fighter.speed = float(speeds.def)
			fighter.gait_moving = true
			fighter.gait_phase = .6
			fighter.aim = .12
			fighter.guard = .43
			fighter.lean = 0.0
			var event = fall_event(kind,speeds)
			var horse_fighter: Dictionary = fighter.duplicate(true)
			horse_fighter.ko = true
			var horse = Rider.new()
			horse.fighter = horse_fighter
			horse.moving = true
			horse.set_process(false)
			# The pixel shader cuts low alpha; dim the riderless horse instead.
			horse.modulate = Color(.62,.62,.62,1.0)
			stage.add_child(horse)
			horses.append(horse)
			var source = Rider.new()
			source.fighter = fighter
			source.mode = "arena"
			var actor = Fallen.new()
			stage.add_child(actor)
			actor.setup(fighter,event,source)
			actor.set_process(false)
			actor.visual.set_process(false)
			actor.far_leg.set_process(false)
			source.free()
			actors.append(actor)
			label(root,"%s  防%d/攻%d  冲量%d" % [kind,roundi(float(speeds.def)),roundi(float(speeds.att)),roundi(float(event.impulse))],origin+Vector2(8,2),13)
			rows.append({"kind":kind,"speeds":speeds,"impulse":float(event.impulse),"start_velocity":[actor.velocity.x,actor.velocity.y],"start_angular":actor.angular_velocity,
				"landing_time":-1.0,"landing_x":0.0,"settled_time":-1.0,"x_at":{},"peak_rotation":0.0})
	label(root,"FEEL-097 落马：列=速度(相等/防守快攻方慢/防守慢攻方快)  行=头/胸/腰腹/失衡  黄线=接触点  灰马=无人马",Vector2(8,4),12)
	var capture_frames = [0,5,11,18,27,39,54,78,120,180]
	var frames: Array = []
	for frame in range(181):
		if frame in capture_frames:
			await process_frame
			await RenderingServer.frame_post_draw
			frames.append({"frame":frame,"seconds":frame/60.0,"path":save_frame("falls_%03d" % frame)})
		else:
			await process_frame
		for i in range(actors.size()):
			var actor = actors[i]
			actor.advance(1.0/60.0)
			var horse = horses[i]
			horse.fighter.x = float(horse.fighter.x)+float(horse.fighter.speed)/60.0
			horse.fighter.gait_phase = float(horse.fighter.gait_phase)+TAU*Gait.frequency(float(horse.fighter.speed))/60.0
			horse.position.x = float(horse.fighter.x)
			horse._process(1.0/60.0)
			var row: Dictionary = rows[i]
			row.peak_rotation = maxf(float(row.peak_rotation),absf(actor.rotation))
			if actor.grounded and float(row.landing_time)<0:
				row.landing_time = actor.age
				row.landing_x = actor.position.x
			if actor.settled and float(row.settled_time)<0:
				row.settled_time = actor.age
			if frame in [18,36,60,120]:
				row.x_at[str(frame/60.0)] = actor.position.x
	for i in range(actors.size()):
		rows[i].final_x = actors[i].position.x
		check(actors[i].grounded,"Every fall lands within three game seconds")
	report.falls = {"rows":rows,"frames":frames}
	for child in root.get_children():
		if child is Control: child.queue_free()
	await process_frame

# ---------------------------------------------------------------- timing ----

func run_timing() -> void:
	var rows: Array = []
	var cases = [
		{"name":"shield_glance_light","event":{"zone":"shield","impulse":12.0,"speed":420.0,"glanced":true,"attacker_speed":210.0,"defender_speed":210.0}},
		{"name":"shield_solid_medium","event":{"zone":"shield","impulse":40.0,"speed":690.0,"attacker_speed":480.0,"defender_speed":210.0}},
		{"name":"body_heavy","event":{"zone":"body","impulse":90.0,"speed":960.0,"attacker_speed":480.0,"defender_speed":480.0}},
		{"name":"head_heavy","event":{"zone":"head","impulse":70.0,"speed":960.0,"attacker_speed":480.0,"defender_speed":480.0}},
		{"name":"body_ko","event":{"zone":"body","impulse":96.0,"speed":960.0,"ko":true,"attacker_speed":480.0,"defender_speed":480.0}},
		{"name":"body_ko_def_slow","event":{"zone":"body","impulse":63.0,"speed":630.0,"ko":true,"attacker_speed":480.0,"defender_speed":150.0}}]
	for slow in [true,false]:
		for case in cases:
			var director = Exchange.new()
			director.reset(1)
			var context = {"phase":"charge","pass_id":1,"gap":-50.0,"closing_speed":900.0,"reach":280.0,"slow_motion":slow}
			director.advance(1.0/60.0,context)
			var event: Dictionary = case.event.duplicate(true)
			event.type = "hit"
			event.attacker = 0
			event.defender = 1
			event.position = Vector2(10,-90)
			event.attacker_direction = 1
			event.defender_direction = -1
			director.notify_contacts([event])
			director.advance(0.0,context)
			var stages: Dictionary = {}
			var wall = 0.0
			var game = 0.0
			var minimum = 1.0
			for tick in range(600):
				var sample = director.advance(1.0/60.0,context)
				var state = str(sample.state)
				stages[state] = float(stages.get(state,0.0))+1.0/60.0
				wall += 1.0/60.0
				game += float(sample.scale)/60.0
				minimum = minf(minimum,float(sample.scale))
				if state=="runup":
					break
			rows.append({"case":case.name,"slow_motion":slow,"wall_seconds":wall,"game_seconds":game,"minimum_scale":minimum,"stages":stages})
	report.timing = rows

# ---------------------------------------------------------------- battle ----

func prepare(model, attacker: int, zone: String, case: Dictionary) -> void:
	model.phase = "charge"
	model.rng.seed = 97097
	model.events.clear()
	model.result.clear()
	model.time_elapsed = 0.0
	model.time_effect_active = false
	var defender = 1-attacker
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		var own = float(case.att) if index==attacker else float(case.def)
		fighter.x = -float(case.gap)*.5 if index==0 else float(case.gap)*.5
		fighter.direction = 1 if index==0 else -1
		fighter.speed = own
		fighter.stamina = 100.0
		fighter.boost = own>=400.0
		fighter.stats.speed = 1.0 if own>=400.0 else own/Model.TROT_SPEED
		# Stability also sets the horse's carrying capacity (and so its speed);
		# keep it normal and unseat KO fixtures through 1 HP instead.
		fighter.stats.stability = float(case.get("stability",1.0)) if index==defender else 3.0
		fighter.stats.reach = 247.0
		fighter.stats.armor = 0.0
		fighter.stats.helmet = 0.0
		fighter.acted = index!=attacker
		fighter.guard = .43
		fighter.guard_target = .43
		fighter.lean = 0.0
		fighter.lean_velocity = 0.0
		fighter.aim = .58
		fighter.hp = 1.0 if index==defender and bool(case.get("ko",false)) else 100.0
		fighter.shield = 100.0 if index==attacker or zone=="shield" else 0.0
		fighter.balance = 100.0
		fighter.ko = false
		fighter.dead = false
		fighter.broken = false
		fighter.durability = 1000.0
		fighter.wounds = []
		fighter.lance_stability = 1.0
		fighter.gait_phase = 0.0
		fighter.gait_moving = true
		fighter.acceleration = 0.0
		fighter.accel_command = 0.0
		fighter.motion_drive = 0.0
	model.fighters[attacker].aim = aim_at(model,attacker,zone)
	for fighter in model.fighters:
		model._cache_pose(fighter)

func aim_at(model, attacker: int, zone: String) -> float:
	var defender: Dictionary = model.fighters[1-attacker]
	return asin(clampf((zone_point(defender,zone).y-Model.hand_position(model.fighters[attacker]).y)/Model.lance_length(model.fighters[attacker]),-.629,.548))

func run_battle_case(case: Dictionary) -> void:
	var state = root.get_node("GameState")
	state.profile.settings.slow_motion = true
	state.profile.settings.shake = true
	main._start_match("arena",true)
	var battle = main.battle
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	# The battle assembles over several frames; fixtures start once it is ready.
	var ready_wait = 0
	while not battle.presentation_ready and ready_wait<600:
		await process_frame
		ready_wait += 1
	check(battle.presentation_ready,"Battle presentation became ready: "+str(case.name))
	var attacker = int(case.get("attacker",0))
	var zone = str(case.zone)
	prepare(battle.match_model,attacker,zone,case)
	battle._update_views()
	var hits: Array = []
	var timeline: Array = []
	var frames: Array = []
	var contact_ms = -1
	# PNG saves stall the wall clock; the timing pass runs with --captures=none.
	var capture_ms = [] if capture_dir=="none" else [0,110,280,620,1000,1600]
	var next_capture = 0
	var started = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<16000:
		await physics_frame
		if battle.match_model.phase=="charge":
			var remaining = Engine.time_scale/maxf(1.0,Engine.physics_ticks_per_second)
			while remaining>.0000001 and battle.match_model.phase=="charge":
				var dt = minf(remaining,1.0/120.0)
				battle.match_model.time_effect_active = bool(battle.exchange_state.impact_active)
				for index in range(2):
					var fighter: Dictionary = battle.match_model.fighters[index]
					var aim = aim_at(battle.match_model,index,zone) if index==attacker and not bool(fighter.acted) else float(fighter.aim)
					battle.match_model.set_controls(index,aim,0.0,bool(fighter.boost),dt,.43)
				battle.match_model.step(dt)
				var events = battle.match_model.drain_events()
				battle._consume_events(events)
				for event in events:
					if event.type=="hit":
						hits.append(event.duplicate(true))
						if contact_ms<0: contact_ms = Time.get_ticks_msec()
				remaining -= dt
			battle._update_views()
		await process_frame
		if contact_ms>=0:
			var since = Time.get_ticks_msec()-contact_ms
			timeline.append({"ms":since,"time_scale":Engine.time_scale,"state":str(battle.exchange_state.state),"offset":[battle.camera.offset.x,battle.camera.offset.y],
				"impact_elapsed":float(battle.exchange_state.get("impact_elapsed",0.0)),"strength":float(battle.exchange_state.get("strength",0.0)),
				"zoom":battle.camera.zoom.x,"camera_x":battle.camera.position.x,"bodies":battle.effects.bodies.map(func(b): return [b.position.x,b.position.y,b.rotation,b.grounded])})
			if next_capture<capture_ms.size() and since>=int(capture_ms[next_capture]):
				await RenderingServer.frame_post_draw
				frames.append({"target_ms":capture_ms[next_capture],"ms":since,"path":save_frame("%s_%04d" % [case.name,int(capture_ms[next_capture])])})
				next_capture += 1
			if since>2600:
				break
	check(not hits.is_empty(),"Battle case produced an actual contact: "+str(case.name))
	report.battle.append({"case":case,"hits":hits,"timeline":timeline,"frames":frames,"restored_time_scale":Engine.time_scale})
	main._close_battle()
	Engine.time_scale = 1.0
	await process_frame

func run_battle() -> void:
	var state = root.get_node("GameState")
	state.profile = state.default_profile()
	state.profile.settings.blood = false
	state.profile.settings.sound = true
	AudioServer.set_bus_volume_db(0,-60.0)
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	report.battle = []
	var cases = [
		# KO fixtures: 1 HP unseats on contact (a slow attacker's lance carries
		# little drive by rule, so impact alone would not unhorse in deffast).
		{"name":"equal_body_ko","zone":"body","att":480.0,"def":480.0,"gap":2600.0,"ko":true},
		{"name":"deffast_body_ko","zone":"body","att":150.0,"def":480.0,"gap":2600.0,"ko":true},
		{"name":"defslow_body_ko","zone":"body","att":480.0,"def":150.0,"gap":2600.0,"ko":true},
		{"name":"equal_head_stay","zone":"head","att":480.0,"def":480.0,"gap":2600.0,"stability":3.0},
		{"name":"slow_shield_light","zone":"shield","att":210.0,"def":210.0,"gap":1800.0,"stability":3.0}]
	for case in cases:
		await run_battle_case(case)
	main.queue_free()
	await process_frame

# ------------------------------------------------------------------- run ----

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--part="): part = argument.trim_prefix("--part=")
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		if argument.begins_with("--captures="): capture_dir = argument.trim_prefix("--captures=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_"):
		push_error("FEEL-097 checks require -- --test-profile")
		quit(2)
		return
	if report_path.is_empty() or FileAccess.file_exists(report_path):
		push_error("Use a fresh --report path")
		quit(2)
		return
	if part!="timing":
		if DisplayServer.get_name()=="headless" or capture_dir.is_empty() or (capture_dir=="none" and part!="battle") or (capture_dir!="none" and DirAccess.dir_exists_absolute(capture_dir)):
			push_error("Matrix/battle parts need rendering and a fresh --captures directory (battle also accepts none)")
			quit(2)
			return
		if capture_dir!="none":
			DirAccess.make_dir_recursive_absolute(capture_dir)
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	report = {"part":part,"version":ProjectSettings.get_setting("application/config/version","unknown")}
	match part:
		"matrix":
			root.size = Vector2i(1440,900)
			root.content_scale_size = Vector2i(1440,900)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			await run_matrix_mounted()
			await run_matrix_falls()
		"battle":
			await run_battle()
		"timing":
			run_timing()
	report.passed = failures.is_empty()
	report.failures = failures
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write FEEL-097 report")
		quit(3)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("IMPACT097 ",part," ",report.passed," ",failures)
	quit(0 if failures.is_empty() else 1)
