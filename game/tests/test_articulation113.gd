extends "test_fall_v057.gd"
## Isolated GPU comparison of sequential body contact and angular follow-through.
## Synthetic captured impacts; never a claim of player feel acceptance.
func run() -> void:
	var folder = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder = arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless" or not "qa_" in root.get_node("GameState").save_path:
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,960)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color("21382f"))
	var actors = []; var stages = []; var rows = []
	for index in range(6):
		var stage = Node2D.new(); root.add_child(stage); stages.append(stage)
		stage.position = Vector2(240+(index%3)*480,415+(index/3)*465)
		stage.scale = Vector2.ONE*.92
		var floor_line = Line2D.new()
		floor_line.points = PackedVector2Array([Vector2(-3000,12),Vector2(3000,12)])
		floor_line.width = 2; floor_line.default_color = Color("a99664"); stage.add_child(floor_line)
		var zone = ["head","body","flank"][index%3]
		var facing = 1 if index<3 else -1
		var label = Label.new(); label.text = "%s / %d" % [zone,facing]
		label.position = Vector2(30+(index%3)*480,20+(index/3)*465); root.add_child(label)
		var actor = make_actor(stage,zone,facing,false,zone=="flank"); actors.append(actor)
		rows.append({"zone":zone,"facing":facing,"samples":[],"maximum_bone_error":0.0,"maximum_penetration":0.0,"landing_joint_motion":0.0})
	var frame_ticks = [0,12,30,48,66,84,102,120,150,180,240,360,480]
	for tick in range(481):
		for i in range(actors.size()):
			var actor = actors[i]
			inspect(actor,rows[i])
			if tick%3==0:
				rows[i].samples.append({"time":actor.age,"grounded":actor.grounded,"position":[actor.position.x,actor.position.y],"velocity":[actor.velocity.x,actor.velocity.y],"rotation":actor.rotation,"angular_velocity":actor.angular_velocity,"support_gap":actor.support_gap(),"support":support_parts(actor),"joints":actor.joints.duplicate(true)})
			stages[i].position.x = 240+(i%3)*480-actor.position.x*.92
		if tick in frame_ticks:
			await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/frame_%03d.png" % tick)==OK,"Articulation frame saves")
		if tick<480:
			for actor in actors: actor.advance(1.0/120)
	for i in range(actors.size()):
		var actor = actors[i]
		rows[i].settled = actor.settled
		rows[i].final_support_gap = actor.support_gap()
		if "contact_history113" in actor: rows[i].contacts = actor.contact_history113
		check(actor.settled and actor.support_gap()<14.0,"Articulated rest reaches stable body support",{"zone":actor.zone,"facing":actor.fighter.direction,"gap":actor.support_gap()})
		remove_stage(stages[i])
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"examples":examples,"cases":rows,"scope":"Six production captured falls, 120Hz integration and isolated GPU milestone frames. Bone lengths, ground support and angular/contact traces; not genuine battle hits, normal camera, OS input or subjective acceptance."},"\t"))
	print("ARTICULATION113 ",failures)
	quit(0 if failures.is_empty() else 1)
