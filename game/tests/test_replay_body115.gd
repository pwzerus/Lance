extends "test_body114.gd"
## Reproduce a captured full-game failure without rerolling a match seed.
func run() -> void:
	var input=""
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):input=arg.trim_prefix("--input=")
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if input.is_empty() or report_path.is_empty() or FileAccess.file_exists(report_path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	if not folder.is_empty() and (DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder)):quit(2);return
	if not folder.is_empty():DirAccess.make_dir_recursive_absolute(folder)
	var saved:Dictionary=FileAccess.open(input,FileAccess.READ).get_var()
	var body=Body.new()
	for key in saved.body:body.set(key,saved.body[key])
	if not saved.body.has("shield_theta115"):
		body.shield_theta115=(body.p[Body.HAND_L]-body.p[Body.ELBOW_L]).angle()-float(body.extensions.shield.angle0)
		body.shield_previous115=body.shield_theta115
		body.shield_omega115=body.segment_spin(Body.ELBOW_L,Body.HAND_L)
		body.configure_shield115(float(saved.fighter.stats.get("shield_kg",3.0)))
	var stage=Node2D.new();root.add_child(stage)
	var actor=Fallen.new();stage.add_child(actor)
	actor.setup(saved.fighter,{"zone":saved.zone,"direction":saved.direction,"impulse":saved.strength*110,"ko_reason":"impact"},null,
		{"body":body,"captured":saved.captured,"snapshot":saved.snapshot,"previous_snapshot":saved.snapshot,"current_snapshot":saved.snapshot})
	actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
	actor.age=saved.age;actor.ground_age=saved.ground_age;actor.grounded=saved.body_grounded
	if not folder.is_empty():
		root.size=Vector2i(1100,700);root.content_scale_size=root.size
		RenderingServer.set_default_clear_color(Color("21382f"))
		stage.scale=Vector2.ONE*1.7
		var line=Line2D.new();line.points=PackedVector2Array([Vector2(-20000,body.ground),Vector2(20000,body.ground)]);line.width=1;line.default_color=Color("a99664");stage.add_child(line)
	var rows=[]
	for tick in range(721):
		if not folder.is_empty() and tick in [0,30,120,300,720]:
			stage.position=Vector2(550-actor.position.x*1.7,600-body.ground*1.7)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/t%03d.png" % tick)
		if tick%30==0:rows.append({"t":actor.age,"shape":final_shape(actor),"settled":actor.settled,
			"theta":body.theta,"pelvis_theta":body.pelvis_theta,"spine":body.spine_flex(),"tone":body.tone,"rest":body.rest,
			"hip":[body.flex("near_hip"),body.flex("far_hip")],"knee":[body.flex("near_knee"),body.flex("far_knee")],"contacts":body.contacts.keys(),"lift":actor.surface_correction115})
		# Diagnostic only: observe whether the underlying contacts can relax the
		# bad pose beyond the former visual rest detector's premature freeze.
		actor.settled=false
		actor.advance(1.0/120.0)
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows},"\t"))
	actor.free()
	quit(0)
