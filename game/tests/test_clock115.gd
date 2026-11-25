extends SceneTree
## Identical game-time input at ordinary and bullet-time callback rates.
const Model=preload("res://scripts/core/joust_match.gd")
const Body=preload("res://scripts/visual/rider_body114.gd")
var failures=[]
func _initialize() -> void:call_deferred("run")

func sample(rate: int, facing: int) -> Dictionary:
	var model=Model.new()
	var f:Dictionary=model.fighters[0]
	f.x=0.0;f.direction=facing;f.speed=380.0;f.gait_moving=true;f.lane_y=0.0;f.guard=.5
	model._ensure_body115(0)
	var rows=[]
	var max_step=0.0
	var hand=Model.hand_position(f)
	var bone_error=0.0
	for tick in range(rate*3):
		var t=float(tick+1)/rate
		f.x=380.0*t*facing
		f.gait_phase=TAU*Model.Gait.frequency(380.0)*t
		if tick==rate:model.bodies115[0].queue_hit({"zone":"body","position":model.bodies115[0].body.x,"impulse":12.0,"direction":-facing})
		model._advance_body115(0,1.0/rate)
		var rider=model.bodies115[0]
		var body=rider.body
		var pose:Dictionary=f._body_pose115.pose
		for side in ["left","right"]:
			var index=0 if side=="left" else 2
			bone_error=maxf(bone_error,absf(Vector2(pose[side].shoulder).distance_to(pose[side].elbow)-float(body.bones[index][2])))
			bone_error=maxf(bone_error,absf(Vector2(pose[side].elbow).distance_to(pose[side].hand)-float(body.bones[index+1][2])))
		max_step=maxf(max_step,(Model.hand_position(f)-hand-Vector2(380.0*facing/rate,0)).length())
		hand=Model.hand_position(f)
		if (tick+1)%(rate/4)==0:rows.append({"t":t,"x":[body.x.x,body.x.y],"theta":body.theta,"pelvis":[body.pelvis_x.x,body.pelvis_x.y],"hand":[hand.x,hand.y],"detached":rider.detached})
	return {"rate":rate,"facing":facing,"max_hand_step":max_step,"bone_error":bone_error,"rows":rows}

func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var cases=[]
	for facing in [1,-1]:
		var baseline=sample(120,facing)
		cases.append(baseline)
		for rate in [60,240,1200]:
			var data=sample(rate,facing)
			var error=0.0
			var angle=0.0
			for i in range(data.rows.size()):
				var a:Dictionary=baseline.rows[i];var b:Dictionary=data.rows[i]
				for key in ["x","pelvis"]:error=maxf(error,Vector2(a[key][0],a[key][1]).distance_to(Vector2(b[key][0],b[key][1])))
				angle=maxf(angle,absf(wrapf(float(a.theta)-float(b.theta),-PI,PI)))
				if a.detached!=b.detached:failures.append("Callback cadence changed loss of support: %d/%d" % [facing,rate])
			data.position_error=error;data.angle_error=angle
			if error>2.0 or angle>.04:failures.append("Game-time trajectory differs: %d/%d %.3fpx %.3frad" % [facing,rate,error,angle])
			if data.bone_error>.002:failures.append("Interpolated bone stretches: %d/%d" % [facing,rate])
			cases.append(data)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":cases},"\t"))
	print("CLOCK115 ",failures)
	quit(0 if failures.is_empty() else 1)
