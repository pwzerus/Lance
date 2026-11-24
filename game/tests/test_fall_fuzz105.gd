extends "test_fall_v057.gd"
## Reproducible captured-pose coverage beyond the old fixed aim/hoof phase.
## Inputs are synthetic extreme fixtures, not claims of in-match frequency.
var first_case=0
var count=128
var fuzz_folder=""
var broken_shield113=false
func run()->void:
	var path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
		if a.begins_with("--first="):first_case=int(a.trim_prefix("--first="))
		if a.begins_with("--count="):count=int(a.trim_prefix("--count="))
		if a.begins_with("--captures="):fuzz_folder=a.trim_prefix("--captures=")
		if a=="--broken-shield":broken_shield113=true
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	if not fuzz_folder.is_empty():
		if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(fuzz_folder):quit(2);return
		DirAccess.make_dir_recursive_absolute(fuzz_folder)
		root.size=Vector2i(1440,900);root.content_scale_size=root.size
		RenderingServer.set_default_clear_color(Color("21382f"))
	var catalogue_items=Catalogue.load_items();var Campaign=load("res://scripts/core/campaign.gd")
	var records=[]
	for case_id in range(first_case,first_case+count):
		var rng=RandomNumberGenerator.new();rng.seed=105000+case_id
		var level=Campaign.level(catalogue_items,1+(case_id*17)%80)
		var stats=Catalogue.stats(catalogue_items,level.equipment)
		var model=Model.new("arena",stats,stats,105000+case_id);var f:Dictionary=model.fighters[0]
		f.x=0.0;f.lane_y=0.0;f.direction=1 if case_id%2==0 else -1
		f.speed=rng.randf_range(100,520);f.gait_moving=true;f.gait_phase=rng.randf_range(0,TAU)
		f.lean=rng.randf_range(-1,1);f.guard=rng.randf_range(0,1);f.aim=rng.randf_range(-.68,.58)
		f.unsteady=rng.randf_range(0,1);f.sway=rng.randf_range(-.13,.13);f.broken=case_id%3==0
		if broken_shield113:f.shield=0.0
		var zone=["head","body","flank"][case_id%3]
		var event={"zone":zone,"direction":-f.direction,"impulse":rng.randf_range(40,125),"attacker_speed":rng.randf_range(100,520),"defender_speed":f.speed,"ko_reason":"balance" if case_id%5==0 else "impact"}
		var stage=Node2D.new();root.add_child(stage);stage.visible=not fuzz_folder.is_empty()
		var source=Rider.new();source.fighter=f
		var actor=Probe.new();stage.add_child(actor);actor.setup(f,event,source);source.free()
		actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
		var row={"id":case_id,"level":level.number if level.has("number") else 1+(case_id*17)%80,"equipment":level.equipment,"fixture":f.duplicate(true),"event":event,"maximum_penetration":0.0,"maximum_bone_error":0.0,"landing_joint_motion":0.0,"settled_at":-1.0,"samples":[]}
		if not fuzz_folder.is_empty():
			stage.scale=Vector2.ONE*1.4
			var floor_line=Line2D.new();floor_line.points=PackedVector2Array([Vector2(-3000,12),Vector2(3000,12)]);floor_line.width=2;floor_line.default_color=Color("a99664");stage.add_child(floor_line)
		for tick in range(480):
			actor.advance(1.0/120);inspect(actor,row)
			if actor.settled and row.settled_at<0:row.settled_at=actor.age
			if tick%30==29:
				var velocities={}
				for key in actor.joints:velocities[key]=actor.joints[key].velocity
				row.samples.append({"age":actor.age,"gap":actor.support_gap(),"rotation":actor.rotation,"root_velocity":actor.angular_velocity,"joint_velocity":velocities})
			if not fuzz_folder.is_empty() and tick in [0,20,50,100,200,479]:
				stage.position=Vector2(720-actor.position.x*1.4,650)
				await process_frame;await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(fuzz_folder+"/case%03d-%03d.png"%[case_id,tick])==OK,"Fuzz frame saves")
		row.settled=actor.settled;row.final_gap=actor.support_gap()
		row.final_joints=actor.joints.duplicate(true);row.final_targets=actor._joint_targets()
		row.final_support=support_parts(actor);row.final_rotation=actor.rotation;row.target_rotation=actor.target_rotation
		row.final_points=vector_rows(actor.body_points())
		var center:Vector2=actor.visual.detached_pose.torso_transform*Vector2(0,-38)
		row.final_center=[center.x,center.y]
		check(actor.settled,"Four-second synthetic pose rest: "+str(case_id))
		check(actor.support_gap()<14,"Synthetic pose torso support: "+str(case_id))
		records.append(row);remove_stage(stage)
		if (case_id-first_case)%16==15:
			FileAccess.open(path+".partial",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"cases":records},"\t"))
			print("FALL_FUZZ105 completed ",case_id+1)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records,"scope":"Deterministic synthetic captured poses: campaign gear, varied lean/guard/aim/hoof phase/unsteady, impact and speed ratios; production fall integration and constraints. Optional isolated GPU captures. Not human gameplay or probability evidence."},"\t"))
	print("FALL_FUZZ105 ",failures);quit(0 if failures.is_empty() else 1)
