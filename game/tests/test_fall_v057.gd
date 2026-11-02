extends SceneTree
## Production articulated fall, deterministic clock fixtures and GPU frames.
## No scoring substitution, OS input or subjective quality verdict.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Fallen = preload("res://scripts/visual/fallen_rider.gd")

class Probe extends Fallen:
	var release_record: Dictionary = {}
	func _release_lance() -> void:
		var facing = int(fighter.direction)
		var held_ray = Vector2(cos(float(fighter.aim))*facing,sin(float(fighter.aim))).rotated(rotation)
		var held_grip = position+Vector2(visual.detached_pose.right.hand).rotated(rotation)
		var center_offset = (Model.lance_length(fighter)-67.0)*.5
		super._release_lance()
		var released_ray = Vector2.from_angle(loose_lance.rotation)
		var released_grip = loose_lance.position-released_ray*center_offset
		release_record = {"age":age,"grip_error":held_grip.distance_to(released_grip),"ray_error":absf(held_ray.angle_to(released_ray)),"held_hidden":not visual.detached_lance_visible,"far_hidden":not far_leg.detached_lance_visible,"broken":fighter.broken}

var failures: Array[String] = []
var examples: Array = []
var cases: Array = []
var report_path = ""
var capture_dir = ""
var captures: Array = []
var baseline: Dictionary = {}
var maximum_blood_pose_error = 0.0
var maximum_rate_pose_error = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	if ok: return
	if message not in failures: failures.append(message)
	if examples.size()<30: examples.append({"message":message,"context":context})
	push_error(message)

func vector_rows(points: PackedVector2Array) -> Array:
	var rows: Array = []
	for point in points: rows.append([point.x,point.y])
	return rows

func points_error(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.size()!=b.size(): return INF
	var error = 0.0
	for i in range(a.size()): error = maxf(error,a[i].distance_to(b[i]))
	return error

func global_points(actor) -> PackedVector2Array:
	var points = PackedVector2Array()
	for point in actor.body_points(): points.append(actor.position+point.rotated(actor.rotation))
	return points

func make_actor(stage: Node2D, zone: String, facing: int, blood: bool, broken: bool):
	var model = Model.new()
	var fighter: Dictionary = model.fighters[0].duplicate(true)
	fighter.x = 0.0
	fighter.lane_y = 0.0
	fighter.direction = facing
	fighter.speed = 480.0
	fighter.lean = -.35
	fighter.aim = .12
	fighter.guard = .43
	fighter.gait_moving = true
	fighter.gait_phase = .60
	fighter.broken = broken
	var source = Rider.new()
	source.fighter = fighter
	source.blood_enabled = blood
	source.mode = "war"
	var actor = Probe.new()
	stage.add_child(actor)
	actor.setup(fighter,{"zone":zone,"impulse":105.0,"direction":-facing},source)
	actor.set_process(false)
	actor.visual.set_process(false)
	actor.far_leg.set_process(false)
	source.free()
	var original = Rider.arm_pose(fighter)
	var seated = Rider.seated_leg_pose(fighter)
	for side in ["left","right"]:
		for key in ["shoulder","elbow","hand"]:
			check((actor.position+actor.visual.detached_pose[side][key]).distance_to(original[side][key])<.002,"First fall frame preserves all mounted arm anchors")
	for side in ["near","far"]:
		for key in ["hip","knee","ankle","foot"]:
			check((actor.position+actor.visual.detached_legs[side][key]*Vector2(facing,1)).distance_to(seated[side][key]*Vector2(facing,1))<.002,"First fall frame preserves straddling leg anchors")
	return actor

func inspect(actor, row: Dictionary) -> void:
	check(actor.position.is_finite() and is_finite(actor.rotation),"Fall body remains finite")
	var penetration = maxf(0.0,actor.position.y+actor.lowest_body_point()-actor.ground_y)
	row.maximum_penetration = maxf(row.maximum_penetration,penetration)
	check(penetration<.03,"Fallen rider stays above its lane floor")
	for name in actor.joints:
		var joint: Dictionary = actor.joints[name]
		check(is_finite(float(joint.angle)) and is_finite(float(joint.velocity)),"Fall joint remains finite")
		check(joint.angle>=joint.minimum-.0001 and joint.angle<=joint.maximum+.0001,"Anatomical hinge remains inside its allowed bend")
		if actor.grounded and actor.ground_age<.25:
			row.landing_joint_motion = maxf(row.landing_joint_motion,absf(float(joint.velocity)))
	for side in ["left","right"]:
		var now: Dictionary = actor.visual.detached_pose[side]
		var initial: Dictionary = actor.initial_pose[side]
		for pair in [["shoulder","elbow"],["elbow","hand"]]:
			var error = absf(now[pair[0]].distance_to(now[pair[1]])-initial[pair[0]].distance_to(initial[pair[1]]))
			row.maximum_bone_error = maxf(row.maximum_bone_error,error)
	for side in ["near","far"]:
		var now: Dictionary = actor.visual.detached_legs[side]
		var initial: Dictionary = actor.initial_legs[side]
		var initial_shin: Vector2 = initial.ankle-initial.knee
		var current_shin: Vector2 = now.ankle-now.knee
		var visible_boot_end: Vector2 = now.ankle+(initial.foot-initial.ankle).rotated(initial_shin.angle_to(current_shin))
		check(now.foot.distance_to(visible_boot_end)<.002,"Foot envelope uses the visible knee-to-ankle boot rotation")
		for pair in [["hip","knee"],["knee","ankle"],["ankle","foot"]]:
			var error = absf(now[pair[0]].distance_to(now[pair[1]])-initial[pair[0]].distance_to(initial[pair[1]]))
			row.maximum_bone_error = maxf(row.maximum_bone_error,error)
	check(row.maximum_bone_error<.002,"Arms and legs retain their captured bone lengths")
	check(absf(float(actor.visual.detached_pose.get("head_rotation",0.0)))<=.2001,"Head motion stays inside neck articulation range")

func remove_stage(stage: Node2D) -> void:
	root.remove_child(stage)
	stage.free()

func run_case(zone: String, facing: int, hz: int, blood: bool) -> void:
	var stage = Node2D.new()
	stage.visible = false
	root.add_child(stage)
	var actor = make_actor(stage,zone,facing,blood,zone=="flank")
	var row = {"zone":zone,"facing":facing,"hz":hz,"blood":blood,"maximum_bone_error":0.0,"maximum_penetration":0.0,"landing_joint_motion":0.0,"landing_time":-1.0,"settled_time":-1.0,"peak_head_angle":0.0,"peak_spine_angle":0.0}
	var previous_aim = float(actor.fighter.aim)
	var at_half_second = PackedVector2Array()
	for frame in range(hz*4):
		actor.advance(1.0/hz)
		inspect(actor,row)
		var aim_step = absf(float(actor.fighter.aim)-previous_aim)
		check(aim_step<11.0/hz+.001,"Held lance follows a finite wrist rotation before release")
		previous_aim = float(actor.fighter.aim)
		row.peak_head_angle = maxf(row.peak_head_angle,absf(float(actor.joints.head.angle)))
		row.peak_spine_angle = maxf(row.peak_spine_angle,absf(float(actor.joints.spine.angle)))
		if actor.grounded and float(row.landing_time)<0: row.landing_time = actor.age
		if actor.settled and float(row.settled_time)<0: row.settled_time = actor.age
		if frame+1==hz/2: at_half_second = global_points(actor)
	check(actor.grounded and actor.settled,"All regional falls land and damp to rest within four game seconds",row)
	row.final_support_gap = actor.support_gap()
	check(actor.support_gap()<14.0,"Settled torso or helmet reaches floor support instead of balancing on one boot",row)
	check(actor.landing_count==1,"One fall emits one landing event",row)
	check(row.landing_joint_motion>.10,"Landing carries into attached joints rather than freezing the limbs",row)
	check(not actor.release_record.is_empty(),"Fall releases one independent lance",row)
	if not actor.release_record.is_empty():
		check(actor.release_record.grip_error<.002 and actor.release_record.ray_error<.0001,"Released lance begins on the exact held hand and ray",actor.release_record)
		check(actor.release_record.held_hidden and actor.release_record.far_hidden,"Release removes both held weapon layers")
	row.release = actor.release_record
	row.half_second_body = vector_rows(at_half_second)
	var key = zone+"/"+str(facing)
	if hz==120 and not blood:
		baseline[key] = at_half_second
	elif baseline.has(key):
		var error = points_error(at_half_second,baseline[key])
		if blood:
			maximum_blood_pose_error = maxf(maximum_blood_pose_error,error)
		else:
			maximum_rate_pose_error = maxf(maximum_rate_pose_error,error)
		check(error<.05,"Blood setting and render step rate cannot change the deterministic fall trajectory",{"key":key,"blood":blood,"hz":hz,"error":error})
	cases.append(row)
	remove_stage(stage)

func render_sequence() -> void:
	var back = ColorRect.new()
	back.color = Color("21382f")
	back.size = Vector2(1440,900)
	root.add_child(back)
	var actors: Array = []
	var stages: Array = []
	for index in range(6):
		var stage = Node2D.new()
		stage.position = Vector2(240+(index%3)*480,370+(index/3)*430)
		stage.scale = Vector2.ONE*.82
		root.add_child(stage)
		stages.append(stage)
		var line = Line2D.new()
		line.points = PackedVector2Array([Vector2(-260,12),Vector2(260,12)])
		line.width = 2
		line.default_color = Color("a99664")
		stage.add_child(line)
		var zone = ["head","body","flank"][index%3]
		var facing = 1 if index<3 else -1
		var label = Label.new()
		label.text = "DEV-057  %s / 朝向 %d" % [zone,facing]
		label.position = Vector2(-225,-400)
		stage.add_child(label)
		actors.append(make_actor(stage,zone,facing,false,index%2==0))
	for frame in range(211):
		await process_frame
		if frame in [0,3,10,18,30,45,65,95,150,210]:
			await RenderingServer.frame_post_draw
			var path = capture_dir+"/frame_%03d.png" % frame
			check(root.get_texture().get_image().save_png(path)==OK,"Regional fall render saves")
			var record = {"frame":frame,"seconds":frame/60.0,"path":path,"actors":[]}
			for actor in actors:
				record.actors.append({"zone":actor.zone,"facing":actor.fighter.direction,"age":actor.age,"grounded":actor.grounded,"settled":actor.settled,"support_gap":actor.support_gap(),"position":[actor.position.x,actor.position.y],"rotation":actor.rotation,"joints":actor.joints.duplicate(true)})
			captures.append(record)
		for actor in actors: actor.advance(1.0/60.0)
	for stage in stages: remove_stage(stage)
	back.queue_free()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		if argument.begins_with("--captures="): capture_dir = argument.trim_prefix("--captures=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Fall QA requires GPU and -- --test-profile")
		quit(2)
		return
	if report_path.is_empty() or capture_dir.is_empty() or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(capture_dir):
		push_error("Use fresh --report and --captures evidence paths")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for zone in ["head","body","flank"]:
		for facing in [1,-1]:
			for hz in [120,60,30]:
				for blood in [false,true]: run_case(zone,facing,hz,blood)
	await render_sequence()
	await process_frame
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"cases":cases,"captures":captures,"maximum_blood_pose_error":maximum_blood_pose_error,"maximum_rate_pose_error":maximum_rate_pose_error,"scope":"Actual FallenRider setup/advance/weapon release and Rider drawing, three zones and two directions at 30/60/120 steps with blood on/off. Geometric initial handover, bone lengths, neck range, finite held wrist, exact release boundary, ground/rest and postlanding joint motion. GPU 60-step sequence, camera-free staged grid. Direct visual-event fixtures, not genuine swept hits, normal Battle camera, OS input, full loose-weapon flight physics or player quality approval."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write fall QA report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FALL_V057 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
