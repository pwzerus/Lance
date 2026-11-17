extends "test_arms_v047.gd"
const Campaign104 = preload("res://scripts/core/campaign.gd")
const Catalogue104 = preload("res://scripts/core/catalogue.gd")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
	var state=root.get_node("GameState")
	if not str(state.save_path).contains("qa_") or capture_dir.is_empty() or DisplayServer.get_name()=="headless":
		quit(2);return
	root.size=Vector2i(1440,810)
	root.content_scale_size=Vector2i(1440,810)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var kit=Catalogue104.stats(state.items,Campaign104.level(state.items,2).equipment)
	var model=Model.new("arena",kit,kit)
	var cases=[]
	for facing in [1,-1]:
		for lean_value in [0.0,-1.0,1.0]:
			var f=model.fighters[0].duplicate(true)
			f.x=0.0;f.lane_y=0.0;f.direction=facing;f.lean=lean_value;f.guard=.43;f.aim=-.08
			f.speed=320.0;f.gait_phase=1.2
			cases.append({"fighter":f,"label":"第2关 / 朝%s / 俯仰 %.1f"%["右" if facing==1 else "左",lean_value]})
	await render_page("第二关实际装备：枪手、盾手与肩口",cases,"level2_arms",3)
	var fade_rows=[]
	for opacity in [1.0,.55,.45,.20]:
		var r=Rider.new();r.fighter=cases[3].fighter;r.position=Vector2(720,650);r.scale=Vector2.ONE*1.7
		r.modulate.a=opacity;root.add_child(r);r.set_process(false);r._process(0)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var img=root.get_texture().get_image()
		var non_background=0
		var background=img.get_pixel(10,10)
		for y in range(120,650,2):
			for x in range(400,1040,2):
				if img.get_pixel(x,y)!=background: non_background+=1
		print("FADE104 ",opacity," visible_pixels=",non_background)
		check(non_background>30000,"Fade preserves opaque source silhouette",{"opacity":opacity,"pixels":non_background})
		fade_rows.append({"opacity":opacity,"visible_pixels":non_background})
		img.save_png(capture_dir+"/fade_"+str(opacity)+".png")
		r.queue_free();await process_frame
	# Couched right elbow stays above the belt for the left-facing opponent.
	var pose=Rider.arm_pose(cases[3].fighter)
	var local_elbow=Transform2D(pose.torso_transform).affine_inverse()*Vector2(pose.right.elbow)
	check(local_elbow.y < -35.0,"Lance elbow no longer hangs at the abdomen",{"elbow":str(local_elbow)})
	var output=FileAccess.open(capture_dir+"/report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"fade":fade_rows,"elbow":str(local_elbow)},"\t"))
	print("POSE104 rendered ",failures)
	quit(0 if failures.is_empty() else 1)
