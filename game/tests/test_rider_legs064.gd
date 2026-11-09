extends SceneTree
## RIDER-064 geometry: seated legs and mounted head stabilisation.
## Headless engine checks through Start-MemoryBound; not a render or playtest.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const REST = {"far":{"hip":Vector2(14,-8),"knee":Vector2(35,16),"ankle":Vector2(24,70)},
	"near":{"hip":Vector2(-11,3),"knee":Vector2(12,32),"ankle":Vector2(-4,85)}}
var failures: Array[String] = []
var stats = {"max_bone_error":0.0,"knee_flex_range":{},"ankle_travel":{},"max_head_anchor_error":0.0,"max_joint_step":0.0}

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): path = arg.trim_prefix("--report-path=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or path.is_empty() or FileAccess.file_exists(path):
		quit(2)
		return
	for facing in [1,-1]:
		var model = Model.new("arena",{"stability":1.0},{"stability":1.0},5001)
		var fighter: Dictionary = model.fighters[0 if facing==1 else 1]
		fighter.lane_y = 0.0
		# Rest: identical to the former fixed seat.
		fighter.speed = 0.0
		fighter.gait_moving = false
		fighter.lean = 0.0
		fighter.gait_phase = 0.0
		var rest = Rider.seated_leg_pose(fighter)
		for side in REST:
			for joint in REST[side]:
				var expected: Vector2 = Model.HIP+Model.saddle_offset(fighter)+REST[side][joint]
				check(Vector2(rest[side][joint]).distance_to(expected)<.01,"Rest %s %s moved from the measured seat"%[side,joint])
		check(Rider._head_hinge(Rider.arm_pose(fighter),fighter).is_equal_approx(Transform2D.IDENTITY),"Neutral mounted head must keep the former registration")
		var previous = {}
		for speed in [110.0,210.0,340.0,480.0]:
			for lean in [-1.0,-.5,0.0,.5,1.0]:
				for tick in range(120):
					fighter.speed = speed
					fighter.gait_moving = true
					fighter.lean = lean
					fighter.gait_phase = tick*TAU/60.0
					var legs = Rider.seated_leg_pose(fighter)
					for side in ["far","near"]:
						var leg: Dictionary = legs[side]
						var thigh = Vector2(REST[side].knee-REST[side].hip).length()
						var shin = Vector2(REST[side].ankle-REST[side].knee).length()
						for joint in ["hip","knee","ankle","foot","bar"]:
							check(Vector2(leg[joint]).is_finite(),"Non-finite "+joint)
						var error = maxf(absf(Vector2(leg.knee).distance_to(leg.hip)-thigh),absf(Vector2(leg.ankle).distance_to(leg.knee)-shin))
						stats.max_bone_error = maxf(stats.max_bone_error,error)
						# Knee stays in front of the hip-ankle line (rest branch).
						var line: Vector2 = leg.ankle-leg.hip
						check(line.cross(leg.knee-leg.hip)<0.0,"Knee bent backwards on "+side)
						var flex = rad_to_deg(absf((leg.knee-leg.hip).angle_to(leg.ankle-leg.knee)))
						var key = side+"%d"%int(speed)
						var span: Array = stats.knee_flex_range.get(key,[INF,-INF])
						stats.knee_flex_range[key] = [minf(span[0],flex),maxf(span[1],flex)]
						var travel: Array = stats.ankle_travel.get(key,[INF,-INF,INF,-INF])
						var ankle_rel: Vector2 = leg.ankle-leg.hip
						stats.ankle_travel[key] = [minf(travel[0],ankle_rel.x),maxf(travel[1],ankle_rel.x),minf(travel[2],ankle_rel.y),maxf(travel[3],ankle_rel.y)]
						if lean==0.0 and previous.has(side) and tick>0:
							for joint in ["knee","ankle"]:
								stats.max_joint_step = maxf(stats.max_joint_step,Vector2(leg[joint]).distance_to(previous[side][joint]))
					previous = legs
					# Visible helmet anchor equals the model's head hit point.
					var pose = Rider.arm_pose(fighter)
					var head_world: Vector2 = Transform2D(pose.torso_transform)*Rider._head_hinge(pose,fighter)*Vector2(0,-111)
					var anchor_error = head_world.distance_to(Model.head_position(fighter))
					stats.max_head_anchor_error = maxf(stats.max_head_anchor_error,anchor_error)
	check(stats.max_bone_error<.01,"Thigh or shin length changed")
	check(stats.max_head_anchor_error<.01,"Visible head left the head hit anchor")
	check(stats.max_joint_step<6.0,"Knee or ankle jumped between 60Hz frames")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"stats":stats},"\t"))
	file.close()
	print("RIDER_LEGS_064 "+str(failures.is_empty())+" "+str(failures)+" "+JSON.stringify(stats))
	quit(0 if failures.is_empty() else 1)
