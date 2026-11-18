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
	# Actual contact impulse must pass through both the impact and recovery
	# halves, then decay. No direct position kick or artificial extra reaction.
	for zone in ["head","body","flank","shield"]:
		var m=Model.new("arena",{"stability":3.0},{"stability":3.0},105)
		var f=m.fighters[0];f.balance=1000;f.speed=0;f.gait_moving=false
		var contact={"type":"hit","attacker":1,"defender":0,"zone":zone,"speed":900.0,"position":Model.body_position(f),"attacker_speed":450.0,"defender_speed":450.0}
		m._apply_contact(contact)
		check(float(f.reaction_legs)==0,"Contact changes leg velocity, not leg position")
		var peak=0.0;var trough=0.0;var curve=[]
		for tick in range(360):
			Model.advance_reaction(f,1.0/120)
			peak=maxf(peak,f.reaction_legs);trough=minf(trough,f.reaction_legs)
			if tick%12==0:curve.append([tick/120.0,float(f.reaction_legs),float(f.reaction_angle)])
		check(peak>.01 and trough<-.001 and absf(f.reaction_legs)<.001,"Regional contact has damped follow-through: "+zone)
		rows.append({"kind":"contact_recovery","zone":zone,"peak":peak,"trough":trough,"final":f.reaction_legs,"curve":curve})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Production constrained ankle, one-sided velocity at flap boundaries, real contact reaction spring. Direct rule fixtures; no human play or full Battle camera."},"\t"))
	print("REACTION105 ",failures);quit(0 if failures.is_empty() else 1)
