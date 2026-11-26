extends "test_fall_fuzz105.gd"
## PHYS-116: regenerate the original inputs before any JSON serialization.
## Extended trajectories diagnose the unchanged four-second failure gate.
func original_actor116(case_id: int):
	var catalogue_items=Catalogue.load_items();var Campaign=load("res://scripts/core/campaign.gd")
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
	var stage=Node2D.new();root.add_child(stage);stage.visible=true
	var source=Rider.new();source.fighter=f
	var actor=Probe.new();stage.add_child(actor);actor.setup(f,event,source);source.free()
	actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
	return actor

func run() -> void:
	var path="";var folder="";var solver="";var ids=[41,44,79,115,1002,1003]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--solver="):solver=arg.trim_prefix("--solver=")
		if arg.begins_with("--ids="):
			ids=[]
			for value in arg.trim_prefix("--ids=").split(","):ids.append(int(value))
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	if not folder.is_empty():
		if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):quit(2);return
		DirAccess.make_dir_recursive_absolute(folder)
		root.size=Vector2i(1440,480*ceili(ids.size()/3.0));root.content_scale_size=root.size
		RenderingServer.set_default_clear_color(Color("21382f"))
	var rows=[];var actors=[];var stages=[]
	for id in ids:
		var actor
		if id<1000:actor=original_actor116(id)
		else:
			var stage=Node2D.new();root.add_child(stage)
			var equipment=root.get_node("GameState").default_profile().equipped.duplicate(true)
			equipment.merge({"helmet":"de_helmet_1","armor":"de_armor_1","shield":"de_shield_0"},true)
			stress_stats=Catalogue.stats(Catalogue.load_items(),equipment);stress_stats.shield_scale=.85 if id==1004 else 1.0 if id==1005 else 1.18
			pose_config={"lean":1.0,"guard":0.0}
			actor=make_actor(stage,"flank" if id in [1002,1004] else "head",1,false,id in [1002,1004])
		if not solver.is_empty():
			actor.body=load("res://tests/test_solver_pair115.gd").clone_body115(actor.body,load(solver))
			if actor.body.has_method("configure_volume116"):actor.body.configure_volume116()
		var stage=actor.get_parent();stages.append(stage);actors.append(actor)
		stage.scale=Vector2.ONE*.95
		var line=Line2D.new();line.points=PackedVector2Array([Vector2(-5000,12),Vector2(5000,12)]);line.width=1;line.default_color=Color("a99664");stage.add_child(line)
		rows.append({"id":id,"settled_at":-1.0,"samples":[],"at_four":{}})
		if not folder.is_empty():
			var label=Label.new();label.text="Original case %d"%id;label.position=Vector2(20+(actors.size()-1)%3*480,20+(actors.size()-1)/3*480);root.add_child(label)
	for tick in range(961):
		for i in range(actors.size()):
			var actor=actors[i];var body=actor.body
			if tick>0:actor.advance(1.0/120.0)
			stages[i].position=Vector2(240+(i%3)*480-actor.position.x*.95,430+(i/3)*480)
			if actor.settled and rows[i].settled_at<0:rows[i].settled_at=actor.age
			if tick%12==0:
				var speed=0.0
				for v in body.vel:speed=maxf(speed,v.length())
				var angles={}
				for joint in body.fast_joints115:angles[joint.name]=body._fast_flex115(joint)
				var sample={"t":tick/120.0,"settled":actor.settled,"gap":actor.support_gap(),"unsupported":actor._unsupported_leg115(),"angles":angles,"contacts":body.contacts.keys(),"solver_metrics":body.solver_metrics116().duplicate() if body.has_method("solver_metrics116") else {},"volume":str(body.get("thigh_clearance116")),"spine":body.spine_flex(),"theta":body.theta,"pelvis_theta":body.pelvis_theta,"chest_v":str(body.v),"pelvis_v":str(body.pelvis_v),"omega":body.omega,"shield_omega":body.shield_omega115,"max_point_speed":speed,"rest":body.rest,"tone":body.tone,"points":str(body.p),"chest":str(body.x),"pelvis":str(body.pelvis_x)}
				rows[i].samples.append(sample)
				if tick==480:rows[i].at_four=sample
		if not folder.is_empty() and tick in [60,120,240,480,720,960]:
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/t%03d.png"%tick)
	for row in rows:
		if not row.at_four.settled:failures.append("Four-second original input: "+str(row.id))
		if row.at_four.unsupported or row.at_four.gap>14.0:failures.append("Supported rest: "+str(row.id))
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"diagnostic":true,"scope":"Original test constructors, extended eight seconds. at_four preserves original gate result; no forced rest or relaxed thresholds."},"\t"))
	for stage in stages:stage.free()
	quit(0 if failures.is_empty() else 1)
