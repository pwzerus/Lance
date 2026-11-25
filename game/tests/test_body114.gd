extends SceneTree
## PHYS-114 whole-body fall: numeric checks of the production FallenRider
## with the RiderBody114 mechanism. Direct visual-event fixtures (not swept
## hits), headless rule-free physics only; pictures are a separate GPU test.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Fallen = preload("res://scripts/visual/fallen_rider.gd")
const Body = preload("res://scripts/visual/rider_body114.gd")

var failures: Array[String] = []
var examples: Array = []
var rows: Array = []
var report_path = ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	if ok: return
	if message not in failures: failures.append(message)
	if examples.size()<40: examples.append({"message":message,"context":context})

func make_actor(stage: Node2D, zone: String, facing: int, impulse: float, reason: String, conscious: bool, speeds: Vector2):
	var model = Model.new()
	var fighter: Dictionary = model.fighters[0].duplicate(true)
	fighter.x = 0.0
	fighter.lane_y = 0.0
	fighter.direction = facing
	fighter.speed = speeds.x
	fighter.lean = -.35
	fighter.aim = .12
	fighter.guard = .43
	fighter.gait_moving = true
	fighter.gait_phase = .60
	fighter.unconscious = not conscious
	if not conscious: fighter.consciousness = 0.0
	var source = Rider.new()
	source.fighter = fighter
	source.mode = "arena"
	var actor = Fallen.new()
	stage.add_child(actor)
	actor.setup(fighter,{"zone":zone,"impulse":impulse,"direction":-facing,"ko_reason":reason,"defender_speed":speeds.x,"attacker_speed":speeds.y},source)
	actor.set_process(false)
	actor.visual.set_process(false)
	actor.far_leg.set_process(false)
	source.free()
	return actor

func world(actor, local: Vector2) -> Vector2:
	return actor.position+local.rotated(actor.rotation)

func final_shape(actor) -> Dictionary:
	# World-space reading of the settled body: does any knee or boot stand
	# above its hip (legs in the air), are the hands still held up at chest
	# height, how flat is the trunk?
	var facing = int(actor.fighter.direction)
	var mirror = Vector2(facing,1)
	var result = {"trunk_angle":rad_to_deg(wrapf(actor.rotation+float(actor.initial_pose.torso_transform.get_rotation()),-PI,PI))}
	var raised_legs = 0.0
	for side in ["near","far"]:
		var leg: Dictionary = actor.visual.detached_legs[side]
		var hip = world(actor,leg.hip*mirror)
		var knee = world(actor,leg.knee*mirror)
		var foot = world(actor,leg.foot*mirror)
		var ankle = world(actor,leg.ankle*mirror)
		result[side+"_heights"]={"hip":hip.y,"knee":knee.y,"ankle":ankle.y,"toe_marker":foot.y}
		# Measure articulated joints, not the toe marker: a boot lying with
		# its heel on the floor can point its toe upward by ~24px. This is
		# distinct from the rejected unsupported knee, which remains checked.
		raised_legs = maxf(raised_legs,maxf(hip.y-knee.y,hip.y-ankle.y))
		var boot_low=-INF
		for point in Rider.boot_outline113(leg):
			boot_low=maxf(boot_low,world(actor,point*mirror).y)
		result[side+"_boot_gap"]=actor.ground_y-5.0-boot_low
		result[side+"_knee_flex"] = rad_to_deg(actor.body.flex(side+"_knee"))
		result[side+"_hip_flex"] = rad_to_deg(actor.body.flex(side+"_hip"))
	result.legs_above_hip = raised_legs
	# A hand may lie across the trunk in a side view, but not stand above it
	# as it did when the riding pose was kept (shield held up off the chest).
	var trunk_top = INF
	for point in actor.TORSO_OUTLINE114:
		trunk_top = minf(trunk_top,world(actor,actor.initial_pose.torso_transform*point).y)
	var hand_height = -INF
	for side in ["left","right"]:
		var hand = world(actor,actor.visual.detached_pose[side].hand)
		hand_height = maxf(hand_height,trunk_top-hand.y)
		result[side+"_elbow_flex"] = rad_to_deg(actor.body.flex(side+"_elbow"))
		result[side+"_shoulder_flex"] = rad_to_deg(actor.body.flex(side+"_upper"))
	result.highest_hand = hand_height
	return result

func run_case(zone: String, facing: int, impulse: float, reason: String, conscious: bool, speeds: Vector2) -> Dictionary:
	var stage = Node2D.new()
	root.add_child(stage)
	var actor = make_actor(stage,zone,facing,impulse,reason,conscious,speeds)
	var row = {"zone":zone,"facing":facing,"impulse":impulse,"reason":reason,"conscious":conscious,"speeds":[speeds.x,speeds.y],
		"max_bone_error":0.0,"max_penetration":0.0,"max_speed":0.0,"landing":-1.0,"settled":-1.0,"first_parts":[],"trajectory":[]}
	var lengths = {}
	for bone in actor.body.bones: lengths[str(bone[0])+">"+str(bone[1])] = float(bone[2])
	var spent = 0
	var steps = 0
	for frame in range(120*8):
		var started = Time.get_ticks_usec()
		actor.advance(1.0/120.0)
		spent += Time.get_ticks_usec()-started
		steps += 1
		row.us_per_step = float(spent)/steps
		var body = actor.body
		for bone in body.bones:
			row.max_bone_error = maxf(row.max_bone_error,absf(body.end_position(bone[0]).distance_to(body.p[bone[1]])-float(bone[2])))
		row.max_penetration = maxf(row.max_penetration,actor.position.y+actor.lowest_body_point()-actor.ground_y)
		if body.motion()>row.max_speed:
			row.max_speed = body.motion()
			var fastest = "torso"
			var top = body.v.length()+absf(body.omega)*60.0
			for i in range(Body.COUNT):
				if body.vel[i].length()>top:
					top = body.vel[i].length()
					fastest = Body.PARTICLE_NAMES[i]
			row.max_speed_at = [snappedf(actor.age,.001),fastest]
		if actor.grounded and float(row.landing)<0: row.landing = actor.age
		if actor.grounded and actor.age-float(row.landing)>1.5 and not row.has("fast_part"):
			var fastest = -1
			var speed = body.v.length()
			for i in range(Body.COUNT):
				if body.vel[i].length()>speed:
					speed = body.vel[i].length()
					fastest = i
			row.fast_part = [Body.PARTICLE_NAMES[fastest] if fastest>=0 else "torso",snappedf(speed,.1),snappedf(body.omega,.001),body.tone,body.contacts.keys()]
		if frame%12==0: row.trajectory.append([snappedf(actor.age,.01),snappedf(actor.position.x,.1),snappedf(actor.position.y,.1),snappedf(rad_to_deg(actor.rotation),.1)])
		for name in actor.joints:
			var joint: Dictionary = actor.joints[name]
			check(joint.angle>=joint.minimum-.001 and joint.angle<=joint.maximum+.001,"Joints stay inside anatomical range",{"joint":name,"angle":joint.angle,"min":joint.minimum,"max":joint.maximum,"zone":zone,"facing":facing,"age":actor.age})
		if actor.settled:
			row.settled = actor.age
			break
	for entry in actor.contact_history113: row.first_parts.append([entry.part,snappedf(float(entry.age),.001)])
	row.final = final_shape(actor)
	row.support_gap = actor.support_gap()
	row.travel = actor.position.x-actor.initial_position.x
	var context = {"zone":zone,"facing":facing,"reason":reason,"conscious":conscious,"impulse":impulse}
	check(float(row.settled)>0.0 and float(row.settled)<6.0,"Fall settles within six game seconds",context)
	# Drawn bones are exact (display skeleton); this bounds the solver residual.
	check(row.max_bone_error<8.0,"Solver bones stay within 8px of their captured length",context)
	check(row.max_penetration<.05,"Drawn body stays above its lane floor",context)
	check(row.max_speed<1700.0,"No part exceeds the speed clamp (no explosion)",context)
	check(row.support_gap<14.0,"Trunk or helmet rests on the floor",context)
	check(float(row.final.legs_above_hip)<22.0,"Settled legs are not raised in the air",context.merged({"legs_above_hip":row.final.legs_above_hip}))
	check(float(row.final.highest_hand)<14.0,"Settled hands are not held up above the trunk (riding pose)",context.merged({"hand_above_trunk":row.final.highest_hand}))
	root.remove_child(stage)
	stage.free()
	return row

func trajectory_of(zone: String, facing: int) -> PackedVector2Array:
	var stage = Node2D.new()
	root.add_child(stage)
	var actor = make_actor(stage,zone,facing,105.0,"impact",true,Vector2(480,480))
	var points = PackedVector2Array()
	for frame in range(240):
		actor.advance(1.0/60.0 if frame%3==0 else 1.0/120.0)
		points.append(actor.position)
		for i in range(Body.COUNT): points.append(actor.body.p[i])
	root.remove_child(stage)
	stage.free()
	return points

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
	if report_path.is_empty() or FileAccess.file_exists(report_path):
		push_error("Use a fresh --report path")
		quit(2)
		return
	for zone in ["head","body","flank"]:
		for facing in [1,-1]:
			for impulse in [60.0,105.0]:
				rows.append(run_case(zone,facing,impulse,"impact",true,Vector2(480,480)))
			rows.append(run_case(zone,facing,105.0,"impact",false,Vector2(480,480)))
			rows.append(run_case(zone,facing,105.0,"impact",true,Vector2(620,180)))
			rows.append(run_case(zone,facing,105.0,"impact",true,Vector2(180,620)))
	for facing in [1,-1]:
		rows.append(run_case("body",facing,40.0,"balance",true,Vector2(400,400)))
		rows.append(run_case("body",facing,40.0,"slip",false,Vector2(300,300)))
	# Determinism: identical inputs, different render-step cadence.
	var a = trajectory_of("body",1)
	var b = trajectory_of("body",1)
	var error = 0.0
	for i in range(mini(a.size(),b.size())): error = maxf(error,a[i].distance_to(b[i]))
	check(a.size()==b.size() and error<.0001,"Identical inputs give an identical body trajectory",{"error":error})
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"rows":rows,"determinism_error":error,
		"scope":"Headless production FallenRider + RiderBody114: three zones x two facings, weak/strong, conscious/unconscious, fast-vs-slow both ways, balance topple and unconscious slip. Bone length, floor, joint range, settle time, settled legs/hands height, determinism. No GPU picture, no swept hit, no player judgement."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("BODY114 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
