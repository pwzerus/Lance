extends SceneTree
## Check the recovery direction as well as the initial impact amplitude.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures=[]
var rows=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message);push_error(message)
func ankle_at(f:Dictionary,phase:float,side:String)->Vector2:
	f.gait_phase=phase
	return Rider.seated_leg_pose(f)[side].ankle
func run()->void:
	var path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	# A negative spring displacement is recovery past neutral, not a second
	# forward kick. Check the drawn, constrained ankle instead of the formula.
	for facing in [1,-1]:
		var f=Model.new().fighters[0];f.direction=facing;f.speed=0;f.gait_moving=false
		var neutral=Rider.seated_leg_pose(f)
		f.reaction_legs=.2;var forward=Rider.seated_leg_pose(f)
		f.reaction_legs=-.2;var recovery=Rider.seated_leg_pose(f)
		for side in ["near","far"]:
			var ahead=Vector2(forward[side].ankle)-Vector2(neutral[side].ankle)
			var behind=Vector2(recovery[side].ankle)-Vector2(neutral[side].ankle)
			check(ahead.x>1.0 and behind.x<-.5,"Impact foot swings forward then back across neutral: "+str([facing,side]))
			rows.append({"kind":"recovery_direction","facing":facing,"side":side,"forward":str(ahead),"recovery":str(behind)})
	for speed in [220.0,440.0]:
		for boundary in [0.0,PI]:
			for side in ["near","far"]:
				var f=Model.new().fighters[0];f.gait_moving=true;f.speed=speed;f.unsteady=1.0
				var e=.0005;var omega=TAU*Gait.frequency(speed)
				var a=ankle_at(f,boundary-.4-e,side);var b=ankle_at(f,boundary-.4,side);var c=ankle_at(f,boundary-.4+e,side)
				var jump=((c-b)-(b-a)).length()/e*omega
				check(jump<5.0,"Loose leg has no abrupt vertical flap reversal: "+str([speed,boundary,side]))
				rows.append({"kind":"flap_boundary","speed":speed,"phase":boundary,"side":side,"velocity_jump":jump})
	# Actual contact now acts on the unified body, not reaction_legs/angle
	# springs. Require a continuous response followed by recovery toward the
	# current injured posture; do not demand an artificial spring overshoot.
	for zone in ["head","body","flank","shield"]:
		var m=Model.new("arena",{"stability":3.0},{"stability":3.0},105)
		var f=m.fighters[0];f.balance=1000;f.speed=0;f.gait_moving=false
		m._ensure_body115(0)
		for tick in range(120):m._advance_body115(0,1.0/120)
		var before=Model.rider_origin(f)
		var point=Model.head_position(f) if zone=="head" else Model.flank_position(f) if zone=="flank" else Model.shield_position(f) if zone=="shield" else Model.body_position(f)
		var contact={"type":"hit","attacker":1,"defender":0,"zone":zone,"speed":360.0,"position":point}
		m._apply_contact(contact)
		check(Model.rider_origin(f).distance_to(before)<.001,"Contact changes momentum, not body position")
		var peak=0.0;var final_error=0.0;var curve=[];var max_step=0.0;var previous=before
		for tick in range(480):
			Model.advance_reaction(f,1.0/120)
			m._advance_body115(0,1.0/120)
			var wanted=Model.physical_targets115(f).pose.torso_transform.get_rotation()*int(f.direction)
			final_error=absf(wrapf(Model.pose_angle(f)-wanted,-PI,PI))
			peak=maxf(peak,final_error)
			var now=Model.rider_origin(f);max_step=maxf(max_step,now.distance_to(previous));previous=now
			if tick%12==0:curve.append([tick/120.0,final_error,float(f.seat_offset)])
		check(not f.unseated,"Low-drive contact allows active recovery: "+zone)
		check(peak>.005 and final_error<peak*.5+.03,"Regional physical contact has damped follow-through: "+zone)
		check(max_step<8.0,"Regional body response is continuous: "+zone)
		rows.append({"kind":"contact_recovery","zone":zone,"peak":peak,"final":final_error,"max_step":max_step,"curve":curve})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Legacy desired-leg continuity plus PHYS-115 actual low-drive regional impulses and finite support recovery. Direct rule fixtures; no human play or full Battle camera."},"\t"))
	print("REACTION105 ",failures);quit(0 if failures.is_empty() else 1)
