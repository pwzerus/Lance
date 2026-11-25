extends "test_motion105.gd"
## Composite visual review: moving mount + moderate live regional contact.
## Finite physical support must recover; no artificial KO threshold override.
func composite(kit:Dictionary,kit_name:String,facing:int,zone:String)->void:
	var model=Model.new("arena",kit,kit,10571)
	model.phase="charge";model.fighters[0].x=-2000;model.fighters[1].x=2000
	for member in model.fighters:member.acted=true
	var index=0 if facing==1 else 1
	var f=model.fighters[index]
	f.speed=420.0;f.gait_moving=true;f.gait_phase=1.3
	f.aim=-.08;f.guard=.43;f.guard_target=.43
	model.fighters[1-index].speed=420.0
	model.fighters[1-index].gait_moving=true
	for tick in range(120):
		model.set_controls(index,-.08,0,true,1.0/120,.43)
		model.step(1.0/120)
	var rider=Rider.new();rider.fighter=f;root.add_child(rider);rider.set_process(false)
	var event={"type":"hit","attacker":1-index,"defender":index,"zone":zone,"speed":180.0,"position":Model.shield_position(f) if zone=="shield" else Model.head_position(f) if zone=="head" else Model.flank_position(f) if zone=="flank" else Model.body_position(f)}
	var before=Model.body_position(f)
	model._apply_contact(event)
	check(Model.body_position(f).distance_to(before)<.001,"Contact must not teleport the mounted torso")
	check(not f.ko,"Composite fixture must stay mounted")
	var samples=[];var stamps=[0.0,.06,.14,.30,.70,1.4]
	var maximum_anchor_error=0.0;var maximum_error=0.0;var max_angle=0.0;var minimum_leg=0.0;var maximum_leg=0.0
	for tick in range(181):
		var time=tick/120.0
		if tick>0:
			# Drive uses production fatigue, velocity, reaction and seat updates.
			model.set_controls(index,-.08,0,true,1.0/120,.43)
			model.step(1.0/120)
			rider.position=Vector2(f.x,0);rider.moving=true;rider._process(1.0/120)
		else:
			rider.position=Vector2(f.x,0);rider.moving=true;rider._process(0)
		var pose=Rider.arm_pose(f)
		for side in ["left","right"]:
			var arm=pose[side];var projection=float(arm.projection)
			maximum_error=maxf(maximum_error,maxf(absf(arm.shoulder.distance_to(arm.elbow)-44*projection),absf(arm.elbow.distance_to(arm.hand)-46*projection)))
			var target=Model.hand_position(f) if side=="right" else Model.shield_grip(f)
			maximum_anchor_error=maxf(maximum_anchor_error,Vector2(arm.hand).distance_to(target))
			check(Vector2(arm.hand).distance_to(target)<.002,"Combined reaction must preserve the weapon anchor")
		var wanted=Model.physical_targets115(f).pose.torso_transform.get_rotation()*int(f.direction)
		max_angle=maxf(max_angle,absf(wrapf(Model.pose_angle(f)-wanted,-PI,PI)))
		minimum_leg=minf(minimum_leg,f.seat_offset);maximum_leg=maxf(maximum_leg,f.seat_offset)
		if samples.size()<stamps.size() and time>=stamps[samples.size()]:samples.append({"time":time,"fighter":f.duplicate(true),"body":rider.visual_pose.duplicate(true),"legs":rider.leg_poses.duplicate(true),"moving":true})
	check(maximum_error<.05,"Combined mounted reaction disconnected a bone")
	check(max_angle>.005,"Composite contact produced no torso response")
	check(not f.unseated,"Moderate physical contact recovers without losing support")
	records.append({"kit":kit_name,"facing":facing,"zone":zone,"maximum_bone_error":maximum_error,"maximum_anchor_error":maximum_anchor_error,"peak_torso_radians":max_angle,"minimum_leg":minimum_leg,"maximum_leg":maximum_leg,"remaining_reaction":f.reaction_angle,"remaining_speed":f.speed,"remaining_stamina":f.stamina})
	rider.queue_free();await process_frame
	await render_study(samples,kit_name+"_"+zone+"_"+str(facing))
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or DisplayServer.get_name()=="headless" or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var kits={"level2":Campaign.level(state.items,2).equipment,"plate":{"armor":"it_armor_5","helmet":"it_helmet_5","lance":"it_lance_long_5","shield":"it_shield_5","horse":"horse_courser","caparison":"caparison_velvet"}}
	for name_value in kits:
		var kit=Catalogue.stats(state.items,kits[name_value])
		for zone in ["head","body","shield","flank"]:
			for facing in [1,-1]:await composite(kit,name_value,facing,zone)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"records":records,"version":ProjectSettings.get_setting("application/config/version"),"scope":"Isolated GPU, production body/control/gait with synthetic moderate direct contacts (closing-speed input 180), no health or support-threshold override. Not CCD/KO rates or human motion approval."},"\t"))
	print("MOUNTED_CONTACT105 ",failures);quit(0 if failures.is_empty() else 1)
