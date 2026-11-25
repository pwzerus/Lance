extends "test_rules115.gd"
## State separation and recoverable physical support. PHYS-115 replaces the
## old seat spring: displace the body, then advance the actual supports.
func _initialize() -> void:
	var folder = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")=="": quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	items=Catalogue.load_items()
	var records=[]
	var report_script=load("res://scripts/ui/combat_report.gd")
	check(report_script.summarize([{"attacker":1,"defender":0,"zone":"body","ko":true,"ko_reason":"health"}]).contains("累积伤势"),"Archived combined health/fall contact retains its cause without changing current physical rules")
	for mode in ["arena","war"]:
		var weak=prepare115(3,-1,5); weak.mode=mode
		weak.fighters[1].hp=1.0
		var before=Model.rider_origin(weak.fighters[1])
		var hit=physical_contact115(weak,"head",.5,0,.4)
		var f:Dictionary=weak.fighters[1]
		check(f.ko and f.unconscious and not f.unseated,"Health exhaustion is incapacitation without a launch: "+mode)
		check(f.dead==(mode=="war"),"Nonfatal arena / fatal war exhaustion")
		check(before.distance_to(Model.rider_origin(f))<.001,"Contact does not teleport pelvis")
		var old_aim=float(f.aim); var old_guard=float(f.guard)
		weak.set_controls(1,-.68,-1,true,1.0/120,1.0)
		check(f.aim==old_aim and f.guard==old_guard and not f.boost,"Incapacitated rider cannot be driven by controls")
		for tick in range(240):advance115(weak,1.0/120)
		check(weak.bodies115[1].body.tone==0.0,"Incapacity removes active muscle support")
		records.append({"case":"low_health_glance","mode":mode,"event":hit,"state":f.duplicate(true)})
		check(not report_script.summarize([hit],mode).contains("落马"),"Mounted incapacity is not described as unhorsing")
	for start_offset in [0.0,-19.5,19.5,-44.0,44.0]:
		var m=prepare115(3,-1,5)
		var f:Dictionary=m.fighters[1]
		f.unconscious=true;f.ko=true;f.consciousness=0.0
		var body=m.bodies115[1].body
		body.translate(Vector2(start_offset,0))
		var extra=Vector2(signf(start_offset)*24.0,0)
		body.v+=extra;body.pelvis_v+=extra
		for i in range(Body115.COUNT):body.vel[i]=body.vel[i]+extra
		m._finish("terminal")
		var end_events=0;var seat_events=0
		for tick in range(240):
			m.advance_terminal_pose113(1.0/120)
			for e in m.drain_events():
				if e.type=="end":end_events+=1
				if e.type=="unseat":
					seat_events+=1
					check(e.attacker==-1 and e.ko_reason=="slip","Passive loss of support does not invent an attacker or strike")
		check(end_events==1,"Passive movement after incapacity never repeats match settlement")
		if start_offset==0.0:check(seat_events==0,"A centred limp body can retain saddle support")
		if absf(start_offset)>=44.0:check(seat_events==1,"Outward momentum beyond the finite saddle slips once")
		check(seat_events<=1,"Near-edge limp motion never emits repeated release events")
		records.append({"case":"limp_support","start_offset":start_offset,"end_offset":f.seat_offset,"end_events":end_events,"seat_events":seat_events})
	for start_offset in [-15.0,15.0]:
		var m=prepare115(0,-1,0)
		var f:Dictionary=m.fighters[1]
		var body=m.bodies115[1].body
		# Apply a recoverable disturbance through momentum. Translating every
		# limb sideways put both feet outside their irons while overlapping one
		# curved saddle corner, an imposed collision rather than a lost balance.
		m.bodies115[1].queue_hit({"zone":"body","position":body.x,"direction":signf(start_offset),"impulse":12.0})
		var peak_offset=0.0
		for tick in range(480):
			advance115(m,1.0/120)
			peak_offset=maxf(peak_offset,absf(float(f.seat_offset)))
		check(not f.unseated and absf(float(f.seat_offset))<8.0,"A conscious rider recovers within the usable saddle area")
		records.append({"case":"recover_impulse","direction":signf(start_offset),"peak_offset":peak_offset,"end_offset":f.seat_offset,"detached":f.unseated,"body_velocity":str(body.pelvis_v),"support":body.support_contacts115.keys()})
	var strong=prepare115(0,-1,0)
	var event=physical_contact115(strong,"shield",1,0,1)
	for tick in range(360):advance115(strong,1.0/120)
	check(strong.fighters[1].unseated and strong.fighters[1].hp>80,"Healthy rider can be unhorsed by a sufficiently strong shield impact")
	records.append({"case":"high_health_force","event":event})
	var injured=prepare115(0,-1,0); injured.mode="war"
	for number in range(2):
		physical_contact115(injured,"flank",.5,0,1)
		injured.fighters[0].broken=false
	var wounded:Dictionary=injured.fighters[1]
	check(wounded.injury>.50 and Model.RiderCondition.control_factor(wounded)<.85,"Two unabsorbed torso blows leave a persistent functional injury")
	for tick in range(120):Model.advance_reaction(wounded,1.0/120)
	check(wounded.injury_pose>.12,"Abdominal injury remains visible after the immediate recoil")
	records.append({"case":"two_abdominal_hits","state":wounded.duplicate(true)})
	for hz in [30,60,120]:
		for scenario in ["calm","one_lean","recover","flail","deep_flail","slow_flail"]:
			var m=prepare(0,"eng_shield_0"); var f:Dictionary=m.fighters[0]
			# Keep fixtures within the normal world-coordinate precision. A
			# million-pixel offset quantizes physics positions to 1/16 pixel.
			f.x=-10000.0; m.fighters[1].x=10000.0
			for member in m.fighters:member.gait_moving=true
			var peak=0.0; var support_min=1.0; var exit_time=-1.0
			for tick in range(hz*12):
				var time=float(tick)/hz; var lean=0.0; var aim=-.08; var guard=.43
				if scenario=="one_lean":lean=1.0 if time>1 and time<2 else 0.0
				if scenario in ["flail","deep_flail","slow_flail"] or (scenario=="recover" and time<2):
					lean=1.0 if int(time/(.8 if scenario=="deep_flail" else .30))%2==0 else -1.0
					aim=-.6 if int(time/.24)%2==0 else .5
					guard=1.0 if int(time/.29)%2==0 else 0.0
				f.stamina=100.0
				m.set_controls(0,aim,lean,scenario!="slow_flail",1.0/hz,guard)
				m.step(1.0/hz)
				peak=maxf(peak,absf(float(f.seat_offset)))
				support_min=minf(support_min,float(f.seat_support))
				check(is_finite(float(f.seat_offset)),"Finite saddle offset")
				if f.unseated:exit_time=time;break
			if scenario in ["calm","one_lean","recover","slow_flail"]:check(not f.unseated,"Normal/recovered/slow control does not cause an unavoidable fall: "+scenario+str(hz))
			if scenario=="deep_flail":check(f.unseated and exit_time>2.5 and exit_time<7.0,"Sustained full body swings can exhaust support, with time to recover: "+str(hz))
			if scenario=="flail":check(f.seat_strain>.5 and (not f.unseated or exit_time>2.5),"Rapid requests cause fatigue but cannot bypass finite body movement: "+str(hz))
			if scenario=="recover":check(absf(float(f.seat_offset))<8.0 and f.seat_support>.75,"Recentring restores physical support")
			records.append({"case":scenario,"hz":hz,"peak_offset":peak,"minimum_support":support_min,"exit_time":exit_time,"final_offset":f.seat_offset,"fidget":f.fidget,"unsteady":f.unsteady})
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records,"scope":"Direct injury contacts, passive post-incapacity support, result wording and genuine finite-rate controls/Model.step at three display steps. No GPU or subjective acceptance."},"\t"))
	print("CONDITION113 ",failures);quit(0 if failures.is_empty() else 1)
