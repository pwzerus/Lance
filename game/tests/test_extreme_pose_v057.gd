extends "test_reaction_v057.gd"
## Production Rider sheets for human image review. The head-angle extremes
## are explicit detached fixtures, not a claim that a gameplay fall reached them.
const Appearance = preload("res://scripts/core/character_appearance.gd")

func _initialize() -> void:
	call_deferred("run")

func contact_pose(stats: Dictionary, facing: int, lean: float) -> Dictionary:
	var model = Model.new("arena",stats,stats,5781)
	var index = 0 if facing==1 else 1
	var fighter: Dictionary = model.fighters[index]
	fighter.x = 0.0
	fighter.lane_y = 0.0
	fighter.lean = lean
	fighter.guard = .43
	fighter.guard_target = .43
	# This positive angle reproduced the former butt-through-face issue at
	# maximum back lean. The actual rear/front layer drawing remains intact.
	fighter.aim = .12
	var event = {"type":"hit","zone":"body","speed":960.0,"attacker":1-index,"defender":index,"position":Model.body_position(fighter)}
	model._apply_contact(event)
	for tick in range(15):
		Model.advance_reaction(fighter,1.0/240.0)
	validate_pose(fighter,{"scope":"extreme screenshot fixture","facing":facing,"lean":lean})
	return {"fighter":fighter.duplicate(true),"contact":event.duplicate(true)}

func render_sheet(kind: String, helmet_id: String, items: Array) -> void:
	var equipment = {"armor":"armor_e2","helmet":helmet_id,"shield":"shield_basic","lance":"lance_ash","horse":"horse_bay","crest":"crest_bend"}
	for slot in equipment:
		check(not Catalogue.find(items,equipment[slot]).is_empty(),"Extreme sheet uses existing equipment",{"slot":slot,"id":equipment[slot]})
	var stats = Catalogue.stats(items,equipment)
	stats.stability = 2.0
	stats.durability = 10000.0
	stats.appearance = Appearance.defaults()
	stats.appearance.beard = 0
	stats.appearance.face_shape = 1
	var fit = Rider.HeadFit.layout(stats)
	check(bool(fit.open)==(kind=="open"),"Helmet actually exposes the requested open/closed face",{"kind":kind,"id":helmet_id,"fit":fit})
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1800,1480)
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var page = Node2D.new()
	viewport.add_child(page)
	var background = ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color("333b3d")
	page.add_child(background)
	label(page,"DEV-057 / "+kind+" helmet / actual contact +62.5ms / detached neck extremes",Vector2(24,12))
	label(page,"Same production bones, grips and rear/front lance layers. Inspect neck seam and butt occlusion; geometric PASS is not visual acceptance.",Vector2(24,38))
	var row_index = 0
	for facing in [1,-1]:
		for lean in [-1.0,1.0]:
			var fixture = contact_pose(stats,facing,lean)
			var fighter: Dictionary = fixture.fighter
			var base_pose = Rider.arm_pose(fighter)
			var base_neck = Rider.neck_geometry(base_pose,fighter)
			for column in range(3):
				var angle: float = [-.2,0.0,.2][column]
				var pose = base_pose.duplicate(true)
				pose.head_rotation = angle
				var neck = Rider.neck_geometry(pose,fighter)
				check(Vector2(neck.base).distance_to(base_neck.base)<.001,"Extreme neck rotation leaves the collar root attached")
				for side in ["left","right"]:
					for joint in ["shoulder","elbow","hand"]:
						check(Vector2(pose[side][joint]).distance_to(base_pose[side][joint])<.001,"Head-only extreme fixture preserves the same arm bones and grips")
				var view = Rider.new()
				view.fighter = fighter.duplicate(true)
				view.detached_pose = pose
				view.detached_legs = Rider.seated_leg_pose(fighter)
				view.position = Vector2(column*600+(190 if facing==1 else 410),row_index*350+385)
				page.add_child(view)
				view.set_process(false)
				label(page,"face %d / %s / head %+0.2f" % [facing,"BACK -45" if lean<0 else "FORWARD +25",angle],Vector2(column*600+24,row_index*350+72))
				var head_transform = Rider.head_transform(pose,fighter)
				rows.append({"kind":kind,"helmet":helmet_id,"armor":"armor_e2","facing":facing,"lean":lean,"head_rotation":angle,"reaction_seconds":.0625,
					"reaction_angle":fighter.reaction_angle,"reaction_shift":fighter.reaction_shift,"aim":fighter.aim,"actual_contact":fixture.contact,
					"neck_base":neck.base,"neck_top":neck.top,"head_origin":head_transform.origin,"right_hand":pose.right.hand,"shield_center":pose.shield_center,
					"cell":Rect2(column*600,row_index*350+70,600,350)})
			row_index += 1
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path = run_dir.path_join("extreme_"+kind+".png")
	check(not FileAccess.file_exists(path),"Extreme sheet never overwrites an existing image",{"path":path})
	var image = viewport.get_texture().get_image()
	check(image.get_size()==viewport.size,"Offscreen extreme sheet renders at the requested review resolution")
	check(image.save_png(path)==OK,"Extreme pose sheet saves",{"path":path})
	captures.append(path)
	viewport.queue_free()
	await process_frame

func run() -> void:
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Extreme pose sheets require GPU and isolated -- --test-profile")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="): run_dir = arg.trim_prefix("--run-dir=")
	if run_dir.is_empty() or not run_dir.is_absolute_path() or DirAccess.dir_exists_absolute(run_dir) or FileAccess.file_exists(run_dir):
		push_error("Use a fresh absolute --run-dir for the two sheets and report")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(run_dir)!=OK:
		push_error("Cannot create extreme pose output directory")
		quit(2)
		return
	var items = Catalogue.load_items()
	await render_sheet("open","helm_nasal",items)
	await render_sheet("closed","helm_e2",items)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"rows":rows,"captures":captures,
		"max_anchor_error":max_anchor_error,"max_arm_error":max_arm_error,"visual_review":"Pending original PNG inspection; no pixel-based naturalness assertion.",
		"scope":"Two actual production Rider SubViewport renders: open/closed helmets, both facings, maximum input back/forward lean plus actual body-contact reaction at62.5ms, detached head_rotation -0.2/0/+0.2 with identical bones. Explicit pose/contact fixtures; no full-fall, swept-hit, OS-input or human-feel claim. Player profile unchanged."}
	var file = FileAccess.open(run_dir.path_join("report.json"),FileAccess.WRITE)
	if not file:
		push_error("Cannot save extreme pose report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("EXTREME_POSE_V057 ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"run_dir":run_dir}))
	quit(0 if failures.is_empty() else 1)
