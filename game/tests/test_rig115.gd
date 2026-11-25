extends SceneTree
## Registration gate before moving geometry into the shared rider rig.
## --record writes a fresh reference artifact from the pre-factor renderer;
## normal runs compare against that checked-in artifact, not another wrapper.
const Rig = preload("res://scripts/core/rider_rig115.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Fallen = preload("res://scripts/visual/fallen_rider.gd")
const Body = preload("res://scripts/visual/rider_body114.gd")
const REFERENCE = "res://tests/rig_reference115.json"
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func landmarks(pose: Dictionary, legs: Dictionary, value: Dictionary, head: Transform2D) -> Array:
	var points=[]
	for side in ["left","right"]:
		for key in ["shoulder","elbow","hand"]: points.append(pose[side][key])
	points.append(pose.torso_transform.origin)
	points.append(pose.shield_center)
	points.append(head*Vector2.ZERO)
	points.append(head*Vector2(0,-111))
	var origin=Vector2(float(value.x),float(value.lane_y))
	var mirror=Vector2(int(value.direction),1)
	for side in ["near","far"]:
		for key in ["hip","knee","ankle","foot","bar","stirrup"]: points.append(origin+Vector2(legs[side][key])*mirror)
	var result=[]
	for point in points: result.append([point.x,point.y])
	return result

func run() -> void:
	var path=""
	var record=false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
		if argument=="--record":record=true
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():
		quit(2);return
	if record and FileAccess.file_exists(REFERENCE):
		push_error("Never overwrite the original registration reference")
		quit(2);return
	var expected=JSON.parse_string(FileAccess.get_file_as_string(REFERENCE)) if not record else []
	var rows=[]
	var maximum=0.0
	var capture_error=0.0
	var index=0
	for facing in [1,-1]:
		for lean in [-1.0,0.0,1.0]:
			for guard in [0.0,.43,1.0]:
				var model=Model.new()
				var f:Dictionary=model.fighters[0]
				f.x=117.0;f.lane_y=-32.0;f.direction=facing;f.lean=lean;f.guard=guard;f.aim=-.08+lean*.35
				f.speed=430.0;f.gait_moving=true;f.gait_phase=.73;f.motion_drive=.4;f.seat_drive=.15
				var gait=Model.gait_pose(f)
				var pose=Rig.arms(f,Transform2D(Model.pose_angle(f)*facing,Model.rider_origin(f)),Model.hand_position(f),Model.shield_grip(f),Model.shield_position(f))
				var legs=Rig.seated_legs(f,gait,Model.HIP+Model.saddle_offset(f),Model.HIP+Vector2(gait.offset),Model.seat_inertia(f),Model.seat_lift(f))
				var points=landmarks(pose,legs,f,Rig.head_transform(pose,f,float(gait.rider_pitch)))
				var original=landmarks(Rider.arm_pose(f),Rider.seated_leg_pose(f),f,Rider.head_transform(Rider.arm_pose(f),f)) if record else expected[index].points
				for i in range(points.size()):maximum=maxf(maximum,Vector2(points[i][0],points[i][1]).distance_to(Vector2(original[i][0],original[i][1])))
				var actor=Fallen.new()
				root.add_child(actor)
				actor.setup(f,{"zone":"body","impulse":60.0,"direction":-facing})
				actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
				var body=Body.new()
				body.build(Rig.capture_data(f,pose,Rig.world_legs(f,legs),float(gait.rider_pitch)))
				capture_error=maxf(capture_error,body.x.distance_to(actor.body.x))
				for i in range(Body.COUNT):capture_error=maxf(capture_error,body.p[i].distance_to(actor.body.p[i]))
				for key in body.extensions:
					for i in range(body.extensions[key].offsets.size()):
						capture_error=maxf(capture_error,Vector2(body.extensions[key].offsets[i]).distance_to(Vector2(actor.body.extensions[key].offsets[i])))
				actor.free()
				rows.append({"facing":facing,"lean":lean,"guard":guard,"points":original if record else points})
				index+=1
	if maximum>.001:failures.append("Shared rig differs from the original mounted registration")
	if capture_error>.001:failures.append("Shared capture changes a bone, boot, shield or helmet")
	if record and failures.is_empty():FileAccess.open(REFERENCE,FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"maximum_landmark_error":maximum,"maximum_capture_error":capture_error,"cases":index,"recorded":record},"\t"))
	print("RIG115 ",maximum," capture=",capture_error," ",failures)
	quit(0 if failures.is_empty() else 1)
