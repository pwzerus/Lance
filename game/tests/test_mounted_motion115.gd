extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Body=preload("res://scripts/visual/rider_body114.gd")
var failures=[]
func _initialize() -> void:call_deferred("run")

func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var cases=[]
	for facing in [1,-1]:
		for variant in ["controls","slump","slip"]:
			var model=Model.new()
			var f:Dictionary=model.fighters[0]
			f.x=0.0;f.direction=facing;f.speed=380.0;f.gait_moving=true;f.lane_y=0.0
			model._ensure_body115(0)
			var samples=[]
			var max_hand_step=0.0
			var max_angle_step=0.0
			var previous_hand=Model.hand_position(f)
			var previous_angle=Model.pose_angle(f)
			var detachment=-1
			for tick in range(960):
				if variant=="controls":
					var segment=int(tick/180)%4
					model.set_controls(0,[-.5,.35,.15,-.08][segment],[-1.0,1.0,0.0,0.0][segment],true,1.0/120.0,[1.0,.05,.5,.5][segment])
				elif tick==180:
					f.unconscious=true;f.ko=true;f.consciousness=0.0
					if variant=="slip":model.bodies115[0].queue_hit({"zone":"body","position":model.bodies115[0].body.x,"impulse":18.0,"direction":-facing})
				f.x+=float(f.speed)*facing/120.0
				f.gait_phase+=TAU*Model.Gait.frequency(float(f.speed))/120.0
				Model.advance_reaction(f,1.0/120.0)
				Model.advance_unsteady(f,1.0/120.0,true)
				model._advance_body115(0,1.0/120.0)
				var rider=model.bodies115[0]
				max_hand_step=maxf(max_hand_step,(Model.hand_position(f)-previous_hand-Vector2(380.0*facing/120.0,0)).length())
				max_angle_step=maxf(max_angle_step,absf(wrapf(Model.pose_angle(f)-previous_angle,-PI,PI)))
				previous_hand=Model.hand_position(f);previous_angle=Model.pose_angle(f)
				if rider.detached and detachment<0:detachment=tick
				if tick in [179,360,540,720,959]:samples.append({"tick":tick,"lean":f.lean,"angle":Model.pose_angle(f),"spine":rider.body.spine_flex(),"seat":[rider.snapshot.seat_offset.x,rider.snapshot.seat_offset.y],"supported":rider.body.support_contacts115.keys(),"detached":rider.detached,"tone":rider.body.tone})
			if variant=="controls" and detachment>=0:failures.append("Deliberate controls eject rider: %d" % facing)
			if variant=="controls" and max_hand_step>12.0:failures.append("Hand continuity exceeds 12px/120Hz: %d" % facing)
			cases.append({"facing":facing,"variant":variant,"detach_tick":detachment,"max_hand_step":max_hand_step,"max_angle_step":max_angle_step,"samples":samples})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":cases},"\t"))
	print("MOTION115 ",failures)
	quit(0 if failures.is_empty() else 1)
