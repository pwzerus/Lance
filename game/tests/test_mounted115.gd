extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Rig=preload("res://scripts/core/rider_rig115.gd")
const Mounted=preload("res://scripts/core/mounted_body115.gd")
var failures=[]

func _initialize() -> void:call_deferred("run")

func targets(f: Dictionary) -> Dictionary:
	return Model.physical_targets115(f)

func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [1,-1]:
		for moving in [false,true]:
			var model=Model.new()
			var f:Dictionary=model.fighters[0]
			f.x=0.0;f.direction=facing;f.lane_y=0.0;f.speed=0.0;f.gait_moving=moving;f.lean=0.0;f.aim=0.0;f.guard=.5
			var rider=Mounted.new()
			rider.initialize(f,targets(f))
			var samples=[]
			var maximum=0.0
			var started=Time.get_ticks_usec()
			for tick in range(480):
				if moving:
					f.speed=minf(450.0,float(tick)*2.0)
					f.x+=float(f.speed)*facing/120.0
					f.gait_phase+=TAU*Model.Gait.frequency(float(f.speed))/120.0
				rider.advance(f,targets(f),1.0/120.0)
				var offset:Vector2=rider.snapshot.seat_offset
				maximum=maxf(maximum,offset.length())
				if tick in [0,30,60,120,240,479]:samples.append({"tick":tick,"pelvis":[rider.body.pelvis_x.x,rider.body.pelvis_x.y],"offset":[offset.x,offset.y],"chest_angle":rider.body.theta,"pelvis_angle":rider.body.pelvis_theta,"contacts":rider.body.support_contacts115.keys(),"detached":rider.detached})
			if rider.detached:failures.append("Uncommanded loss of saddle: %s/%s" % [facing,moving])
			if maximum>18.0:failures.append("Excess unforced seat drift: %s/%s %.2fpx" % [facing,moving,maximum])
			rows.append({"facing":facing,"moving":moving,"detached":rider.detached,"maximum_seat_drift":maximum,"us_per_step":float(Time.get_ticks_usec()-started)/480,"samples":samples})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows},"\t"))
	print("MOUNTED115 ",failures)
	quit(0 if failures.is_empty() else 1)
