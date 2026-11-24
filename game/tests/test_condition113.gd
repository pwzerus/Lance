extends "test_rules098.gd"
## State separation and recoverable seat support. No rendering assertions.
func _initialize() -> void:
	var folder = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")=="": quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	items=Catalogue.load_items()
	var records=[]
	var report_script=load("res://scripts/ui/combat_report.gd")
	for mode in ["arena","war"]:
		var weak=prepare(3,"eng_shield_5",.5); weak.mode=mode
		weak.fighters[1].hp=1.0
		var before=Model.rider_origin(weak.fighters[1])
		var hit=contact(weak,"head",.5,0,0,.4)
		var f:Dictionary=weak.fighters[1]
		check(f.ko and f.unconscious and not f.unseated,"Health exhaustion is incapacitation without a launch: "+mode)
		check(f.dead==(mode=="war"),"Nonfatal arena / fatal war exhaustion")
		check(before.distance_to(Model.rider_origin(f))<.001,"Contact does not teleport pelvis")
		var old_aim=float(f.aim); var old_guard=float(f.guard)
		weak.set_controls(1,-.68,-1,true,1.0/120,1.0)
		check(f.aim==old_aim and f.guard==old_guard and not f.boost,"Incapacitated rider cannot be driven by controls")
		for tick in range(240): Model.advance_reaction(f,1.0/120)
		check(float(f.slump)>.98 and float(f.slump)<=1.0,"Mounted incapacity settles continuously into a slumped pose")
		records.append({"case":"low_health_glance","mode":mode,"event":hit,"state":f.duplicate(true)})
		check(not report_script.summarize([hit],mode).contains("落马"),"Mounted incapacity is not described as unhorsing")
	for start_offset in [0.0,-19.5,19.5,-22.8,22.8]:
		var m=prepare(3,"eng_shield_5",.5)
		m.fighters[1].hp=1.0
		contact(m,"head",.5,0,0,.4)
		var f:Dictionary=m.fighters[1]
		f.seat_offset=start_offset;f.seat_velocity=signf(start_offset)*24.0
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
		check(seat_events==(1 if absf(start_offset)>=22.8 else 0),"Centred body retains support; outward momentum at an edge slips once")
		records.append({"case":"limp_support","start_offset":start_offset,"end_offset":f.seat_offset,"end_events":end_events,"seat_events":seat_events})
	for start_offset in [-15.0,15.0]:
		var m=prepare(0,"eng_shield_0")
		var f:Dictionary=m.fighters[0]
		f.seat_offset=start_offset;f.seat_velocity=signf(start_offset)*12.0
		for tick in range(240): Model.RiderCondition.advance_support(f,1.0/120,true)
		check(not f.unseated and absf(float(f.seat_offset))<.1,"A conscious rider can recover from near-edge displacement")
	var strong=prepare(0,"eng_shield_0")
	var event=contact(strong,"shield",1,0,0,1)
	check(strong.fighters[1].unseated and strong.fighters[1].hp>80,"Healthy rider can be unhorsed by a sufficiently strong shield impact")
	records.append({"case":"high_health_force","event":event})
	var injured=prepare(0,"eng_shield_0",.5); injured.mode="war"
	for number in range(2):
		contact(injured,"flank",.5,0,0,1)
		injured.fighters[0].broken=false
	var wounded:Dictionary=injured.fighters[1]
	check(wounded.injury>.50 and Model.RiderCondition.control_factor(wounded)<.85,"Two unabsorbed torso blows leave a persistent functional injury")
	for tick in range(120):Model.advance_reaction(wounded,1.0/120)
	check(wounded.injury_pose>.12,"Abdominal injury remains visible after the immediate recoil")
	records.append({"case":"two_abdominal_hits","state":wounded.duplicate(true)})
	for hz in [30,60,120]:
		for scenario in ["calm","one_lean","recover","flail","deep_flail","slow_flail"]:
			var m=prepare(0,"eng_shield_0"); var f:Dictionary=m.fighters[0]
			f.x=-999999.0; m.fighters[1].x=999999.0
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
			if scenario in ["flail","deep_flail"]:check(f.unseated and exit_time>2.5 and exit_time<7.0,"Sustained violent movement can exhaust support without a hit, with time to recover: "+scenario+str(hz))
			if scenario=="recover":check(absf(float(f.seat_offset))<1.0 and f.seat_support>.95,"Recentring restores physical support")
			records.append({"case":scenario,"hz":hz,"peak_offset":peak,"minimum_support":support_min,"exit_time":exit_time,"final_offset":f.seat_offset,"fidget":f.fidget,"unsteady":f.unsteady})
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records,"scope":"Direct injury contacts, passive post-incapacity support, result wording and genuine finite-rate controls/Model.step at three display steps. No GPU or subjective acceptance."},"\t"))
	print("CONDITION113 ",failures);quit(0 if failures.is_empty() else 1)
