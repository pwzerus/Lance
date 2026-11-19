extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message)
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var reference=[];var rows=[]
	for rate in [120,60,30]:
		var f=Model.new().fighters[0];var samples=[];var maximum=0.0;var minimum=0.0
		for n in range(rate*4):
			var time=n/float(rate)
			var target=1.0 if time<1.0 else (-.6666666667 if time<2.0 else (1.0 if time<2.5 else 0.0))
			Model.advance_drive(f,target,1.0/rate)
			maximum=maxf(maximum,f.motion_drive);minimum=minf(minimum,f.motion_drive)
			check(is_finite(f.motion_drive) and is_finite(f.motion_drive_velocity),"Drive finite")
			if (n+1)%maxi(1,int(rate/30))==0:samples.append([f.motion_drive,f.motion_drive_velocity])
		var error=0.0
		if rate==120:reference=samples
		else:
			for n in range(samples.size()):
				error=maxf(error,maxf(absf(samples[n][0]-reference[n][0]),absf(samples[n][1]-reference[n][1])))
		check(error<.00001,"Drive changes with sample rate")
		check(maximum<=1.000001 and minimum>=-.666667,"No overshoot beyond acceleration envelope")
		check(absf(f.motion_drive)<.00001 and absf(f.motion_drive_velocity)<.0001,"Coast settles")
		var snapshot=f.duplicate(true);Model.advance_drive(f,1.0,0.0)
		check(f==snapshot,"Paused drive moved")
		rows.append({"rate":rate,"maximum":maximum,"minimum":minimum,"rate_error":error})
	# Completed passes retain travel while releasing weight-transfer posture.
	for facing in [1,-1]:
		var m=Model.new();m.phase="turn";m.phase_time=10.0
		var f=m.fighters[0];f.direction=facing;f.speed=400.0;f.gait_moving=true;f.motion_drive=1.0;f.seat_drive=-.5
		var initial_x=float(f.x);var initial_phase=float(f.gait_phase)
		var previous=Model.head_position(f);var maximum_step=0.0
		for tick in range(240):
			m.step(1.0/120)
			var head=Model.head_position(f)
			maximum_step=maxf(maximum_step,(head-previous-Vector2(facing*400.0/120,0)).length())
			previous=head
		check(absf(f.motion_drive)<.00001 and absf(f.seat_drive)<.001,"Turn must release acceleration posture and settle seat")
		check(absf(f.x-initial_x-facing*800.0)<.01 and f.gait_phase>initial_phase,"Settling posture must not freeze travel/gait")
		check(maximum_step<5.0,"Exit posture must not jump the head anchor")
		rows.append({"kind":"turn_release","facing":facing,"maximum_head_step":maximum_step,"final_drive":f.motion_drive,"final_seat":f.seat_drive})
	# The neutral pose must have matching one-sided derivatives, including
	# launch/stop offsets. Test the production visual layer, not a new curve.
	var epsilon=.00001;var slopes=[]
	for phase in [0.0,1.2,3.0,5.5]:
		var values=[]
		for drive in [-epsilon,0.0,epsilon]:
			values.append(Gait.visual(Gait.body(phase,360,true,1.0,drive),phase,360,true,drive))
		for key in ["pitch","neck","head","tail"]:
			var left=(float(values[1][key])-float(values[0][key]))/epsilon
			var right=(float(values[2][key])-float(values[1][key]))/epsilon
			check(absf(left-right)<.001,"Neutral weight transfer has a slope kink: "+key)
		var left=(Vector2(values[1].offset)-Vector2(values[0].offset))/epsilon
		var right=(Vector2(values[2].offset)-Vector2(values[1].offset))/epsilon
		check(left.distance_to(right)<.03,"Neutral body height has a slope kink")
		slopes.append({"phase":phase,"offset_slope_difference":left.distance_to(right)})
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"slopes":slopes,"scope":"Analytic drive time-step convergence and neutral curve continuity; no visual naturalness verdict."},"\t"))
	print("DRIVE106 ",failures);quit(0 if failures.is_empty() else 1)
