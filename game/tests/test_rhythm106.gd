extends SceneTree
## Continuous production acceleration/fatigue and rider geometry. Diagnostic
## derivatives locate discontinuities; numbers do not certify natural motion.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var items=Catalogue.load_items();var rows=[]
	for horse in ["horse_bay","horse_courser","horse_steady"]:
		for facing in [1,-1]:
			var kit=Catalogue.stats(items,{"armor":"eng_armor_2","helmet":"eng_helmet_2","shield":"eng_shield_2","lance":"eng_lance_long_2","horse":horse})
			var m=Model.new("arena",kit,kit,10629);m.phase="charge"
			var index=0 if facing==1 else 1;var f=m.fighters[index]
			m.fighters[0].x=-50000.0;m.fighters[1].x=50000.0
			for member in m.fighters:member.acted=true
			f.speed=0.0;f.guard=.43;f.guard_target=.43
			var rider=Rider.new();rider.fighter=f;rider.moving=true;root.add_child(rider);rider.set_process(false)
			var csv="time,boost,speed,stamina,acceleration,drive,inertia,phase,body_y,body_pitch,rider_y,rider_pitch,head_y,unsteady,support,hoof0_x,hoof0_y,hoof1_x,hoof1_y,hoof2_x,hoof2_y,hoof3_x,hoof3_y\n"
			var minimum_stamina=100.0;var maximum_speed=0.0;var maximum_unsteady=0.0
			for tick in range(1800):
				var time=tick/120.0;var held=time<4.0 or (time>=7.0 and time<11.0)
				m.set_controls(index,-.08,.15,held,1.0/120,.43);m.step(1.0/120)
				rider.position=Vector2(f.x,0);rider._process(1.0/120)
				var body=rider.visual_pose;var gait=Model.gait_pose(f);var rider_y=Model.rider_origin(f).y
				var support=0;var feet=[]
				for leg in rider.leg_poses:
					if leg.contact:support+=1
					feet.append(leg.foot.x);feet.append(leg.foot.y)
				var fields=[time,int(held),f.speed,f.stamina,f.acceleration,f.motion_drive,Model.seat_inertia(f),f.gait_phase,body.offset.y,body.pitch,rider_y,Model.pose_angle(f),Model.head_position(f).y,f.unsteady,support]
				fields.append_array(feet)
				csv+=",".join(PackedStringArray(fields.map(func(v):return str(v))))+"\n"
				minimum_stamina=minf(minimum_stamina,f.stamina);maximum_speed=maxf(maximum_speed,f.speed);maximum_unsteady=maxf(maximum_unsteady,f.unsteady)
				if not Vector2(gait.offset).is_finite():failures.append("Non-finite gait")
			var name="%s_%d"%[horse,facing]
			FileAccess.open(folder+"/"+name+".csv",FileAccess.WRITE).store_string(csv)
			rows.append({"case":name,"minimum_stamina":minimum_stamina,"maximum_speed":maximum_speed,"maximum_unsteady":maximum_unsteady})
			rider.queue_free();await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"120Hz production model/renderer geometry, natural fatigue, no GPU or manual approval."},"\t"))
	print("RHYTHM106 ",JSON.stringify(rows));quit(0 if failures.is_empty() else 1)
