extends "test_fall_v057.gd"
## Recreate the actual failed fuzz inputs, retaining a longer trajectory and
## optional isolated frames. It does not disable physics or force a rest pose.
func run() -> void:
	var keep_simulating115=false
	var skeleton115=false
	var solver=""
	var input="";var folder="";var ids=[29,30];var passive=false;var iterations=5
	for arg in OS.get_cmdline_user_args():
		if arg=="--skeleton":skeleton115=true
		if arg=="--keep-simulating":keep_simulating115=true
		if arg.begins_with("--solver="):solver=arg.trim_prefix("--solver=")
		if arg.begins_with("--input="):input=arg.trim_prefix("--input=")
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--passive":passive=true
		if arg.begins_with("--iterations="):iterations=int(arg.trim_prefix("--iterations="))
		if arg.begins_with("--ids="):
			ids=[]
			for number in arg.trim_prefix("--ids=").split(","):ids.append(int(number))
	if input.is_empty() or not FileAccess.file_exists(input) or report_path.is_empty() or FileAccess.file_exists(report_path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	if not folder.is_empty() and (DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder)):quit(2);return
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		root.size=Vector2i(1440,960);root.content_scale_size=root.size
		RenderingServer.set_default_clear_color(Color("21382f"))
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(input))
	if not parsed is Dictionary or not parsed.has("cases"):quit(2);return
	var report115:Dictionary=parsed
	var actors=[];var stages=[];var rows=[]
	for record_index in range(report115.cases.size()):
		var record:Dictionary=report115.cases[record_index]
		var case_id=int(record.get("id",record_index))
		if case_id not in ids:continue
		var stage=Node2D.new();root.add_child(stage);stage.scale=Vector2.ONE*.95
		var actor
		if record.has("fixture"):
			var model=Model.new();var f:Dictionary=model.fighters[0]
			for key in record.fixture:
				if typeof(record.fixture[key]) in [TYPE_FLOAT,TYPE_INT,TYPE_BOOL]:f[key]=record.fixture[key]
			f.stats=record.fixture.stats
			var source=Rider.new();source.fighter=f
			actor=Probe.new();stage.add_child(actor);actor.setup(f,record.event,source);source.free()
		else:
			var equipment=root.get_node("GameState").default_profile().equipped.duplicate(true)
			equipment.merge({"helmet":"de_helmet_1","armor":"de_armor_1","shield":"de_shield_0"},true)
			stress_stats=Catalogue.stats(Catalogue.load_items(),equipment)
			stress_stats.shield_scale=float(record.scale)
			pose_config={"lean":record.lean,"guard":record.guard}
			actor=make_actor(stage,str(record.zone),int(record.facing),false,record.zone=="flank")
		if not solver.is_empty():actor.body=load("res://tests/test_solver_pair115.gd").clone_body115(actor.body,load(solver))
		if passive:actor.body.guide_strength=0.0
		actor.body.contact_iterations115=iterations
		actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
		var line=Line2D.new();line.points=PackedVector2Array([Vector2(-5000,12),Vector2(5000,12)]);line.width=1;line.default_color=Color("a99664");stage.add_child(line)
		actors.append(actor);stages.append(stage);rows.append({"id":case_id,"samples":[],"settled_at":-1.0,"peak_lift":0.0,"peak_raw_bone_error":0.0})
		rows[-1].registered_joints=actor.body.joints.duplicate(true)
		if not folder.is_empty():
			var label=Label.new();label.text="Case %d"%case_id;label.position=Vector2(20+((actors.size()-1)%3)*480,20+((actors.size()-1)/3)*480);root.add_child(label)
	for tick in range(961):
		for i in range(actors.size()):
			var actor=actors[i];var body=actor.body
			if keep_simulating115:actor.settled=false
			if tick>0:actor.advance(1.0/120.0)
			stages[i].position=Vector2(240+(i%3)*480-actor.position.x*.95,430+(i/3)*480)
			if actor.settled and rows[i].settled_at<0:rows[i].settled_at=actor.age
			rows[i].peak_lift=maxf(float(rows[i].peak_lift),actor.surface_correction115)
			for bone in body.bones:rows[i].peak_raw_bone_error=maxf(float(rows[i].peak_raw_bone_error),absf(body.end_position(bone[0]).distance_to(body.p[bone[1]])-float(bone[2])))
			if tick%30==0:rows[i].samples.append({"t":tick/120.0,"gap":actor.support_gap(),"angle":body.theta,"pelvis_angle":body.pelvis_theta,"hips":[body.flex("near_hip"),body.flex("far_hip")],"knees":[body.flex("near_knee"),body.flex("far_knee")],"contacts":body.contacts.keys(),"support_contacts":body.support_contacts115.keys(),"unsupported":actor._unsupported_leg115(),"lift":actor.surface_correction115,"rest":body.rest,"spin":body.omega,"vel":str(body.v),"tone":body.tone,"all_points":str(body.p),"hips_world":[str(body.anchor("hip_n")),str(body.anchor("hip_f"))],"knees_world":[str(actor.display114[body.KNEE_N]),str(actor.display114[body.KNEE_F])],"ankles_world":[str(actor.display114[body.ANKLE_N]),str(actor.display114[body.ANKLE_F])],"boots_lowest":[boot_floor115(body,"boot_n"),boot_floor115(body,"boot_f")]})
		if not folder.is_empty() and tick in [60,120,240,480,720,960]:
			if skeleton115:
				for index in range(actors.size()):
					var actor=actors[index]
					for child in stages[index].get_children():
						if child.get_meta("diagnostic115",false):child.free()
					for part in range(actor.body.COUNT):
						var label=Label.new();label.text=str(part);label.add_theme_color_override("font_color",Color.CYAN)
						label.position=actor.body.p[part];label.set_meta("diagnostic115",true);stages[index].add_child(label)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/t%03d.png"%tick)
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"diagnostic":true},"\t"))
	for stage in stages:stage.free()
	quit(0)

func boot_floor115(body, key:String) -> float:
	var lowest=-INF
	for offset in body.extensions[key].offsets:lowest=maxf(lowest,body._extension_point(body.extensions[key],false,offset).y)
	return body.ground-lowest
