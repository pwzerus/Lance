extends "test_support115.gd"
## Compare full mounted trajectories, including actual jaw/horse contact.
const Pair115=preload("test_solver_pair115.gd")
func run() -> void:
	var path="";var reference="";var candidate=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--reference="):reference=arg.trim_prefix("--reference=")
		if arg.begins_with("--candidate="):candidate=arg.trim_prefix("--candidate=")
	if path.is_empty() or FileAccess.file_exists(path) or reference.is_empty() or candidate.is_empty() or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for scenario in ["controls","slump","impact"]:
			var models=[Model.new(),Model.new()]
			for index in range(2):
				var m=models[index];var f:Dictionary=m.fighters[0]
				f.direction=facing;f.x=1000.0*facing;f.lane_y=0.0;f.speed=300;f.gait_moving=true
				m._ensure_body115(0)
				m.bodies115[0].body=Pair115.clone_body115(m.bodies115[0].body,load(reference if index==0 else candidate))
			var timings=[0,0];var error=0.0;var neck_contacts=0
			for tick in range(600):
				for index in ([0,1] if tick%2==0 else [1,0]):
					var m=models[index];var f:Dictionary=m.fighters[0]
					if scenario=="controls":f.lean=sin(tick/130.0)*.8;f.guard=.5+.45*sin(tick/80.0)
					if tick==150 and scenario=="slump":f.unconscious=true;f.ko=true
					if tick==150 and scenario=="impact":m.bodies115[0].queue_hit({"zone":"body","position":m.bodies115[0].body.x,"impulse":55.0,"direction":-facing})
					f.x+=300.0*facing/120.0;f.gait_phase+=TAU*Model.Gait.frequency(300.0)/120.0
					var started=Time.get_ticks_usec();m._advance_body115(0,1.0/120.0);timings[index]+=Time.get_ticks_usec()-started
					if index==1 and m.bodies115[0].body.support_contacts115.has("head"):neck_contacts+=1
				var a=models[0].bodies115[0].body;var b=models[1].bodies115[0].body
				error=maxf(error,maxf(a.x.distance_to(b.x),a.pelvis_x.distance_to(b.pelvis_x)))
				for i in range(Body.COUNT):error=maxf(error,a.p[i].distance_to(b.p[i]))
			if error!=0.0:failures.append("Broad phase changed mounted trajectory "+str([facing,scenario]))
			rows.append({"facing":facing,"scenario":scenario,"error":error,"old_us":timings[0],"new_us":timings[1],"head_contact_ticks":neck_contacts})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	quit(0 if failures.is_empty() else 1)
