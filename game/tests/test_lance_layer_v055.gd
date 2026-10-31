extends "test_head_wear_v053.gd"
## GPU regression for the rear-lance/face overlap found during DEV-055 OS QA.
## Fixtures use the production renderer; images still require visual review.
const Fallen = preload("res://scripts/visual/fallen_rider.gd")
var anchor_rows: Array = []
var fixture_count = 0

func xy(point: Vector2) -> Array:
	return [point.x,point.y]

func held_fixture(viewport: SubViewport, id: String, fighter: Dictionary) -> Dictionary:
	var before_hand: Vector2 = Model.hand_position(fighter)
	var before_tip: Vector2 = Model.tip_position(fighter)
	var view = frozen_rider(viewport,fighter,2.2,Vector2(203,112))
	# The inherited head-wear helper deliberately hides lances. Enable the actual
	# held production draw here, including its rear/front depth split.
	view.detached_lance_visible = true
	view.queue_redraw()
	fixture_count += 1
	return {"id":id,"view":view,"hand":before_hand,"tip":before_tip}

func record_held(entry: Dictionary) -> void:
	var view = entry.view
	var hand: Vector2 = Model.hand_position(view.fighter)
	var tip: Vector2 = Model.tip_position(view.fighter)
	var pose: Dictionary = Rider.arm_pose(view.fighter)
	check(hand.distance_to(entry.hand)<.0001,entry.id+": drawing preserves model hand")
	check(tip.distance_to(entry.tip)<.0001,entry.id+": drawing preserves model tip")
	check(Vector2(pose.right.hand).distance_to(hand)<.0001,entry.id+": renderer hand matches model grip")
	anchor_rows.append({"id":entry.id,"kind":"held","helmet":view.fighter.stats.get("helmet_id",""),"direction":view.fighter.direction,"lean":view.fighter.lean,"aim":view.fighter.aim,"broken":view.fighter.broken,"length":Model.lance_length(view.fighter),"hand_before":xy(entry.hand),"tip_before":xy(entry.tip),"hand_after":xy(hand),"tip_after":xy(tip),"renderer_hand":xy(pose.right.hand)})

func held_sheet(name_value: String, broken: bool, use_aim_extremes: bool) -> void:
	var page = sheet(Vector2i(1640,1090))
	UI.label(page,"DEV-055 · "+name_value+" · 生产骑手近景 / 固定姿态 / 非比赛输入",Vector2(12,7),18,UI.GOLD,1616)
	var pending: Array = []
	var index = 0
	for sample in ([-.68,.12,.58] if use_aim_extremes else [0.0,-.5,-1.0]):
		var lean: float = -1.0 if use_aim_extremes else float(sample)
		var aim: float = float(sample) if use_aim_extremes else .12
		for helmet in HELMETS:
			for direction in [1,-1]:
				var id = "%s_%s_dir%d_lean%.2f_aim%.2f" % [name_value,helmet,direction,lean,aim]
				var viewport = cell(page,index,"%s · 朝向 %d\n俯仰 %.2f / 枪角 %.2f / %s" % [helmet,direction,lean,aim,"断枪" if broken else "完整枪"])
				var fighter = fighter_for(helmet,0,0,direction,lean)
				fighter.aim = aim
				fighter.broken = broken
				pending.append(held_fixture(viewport,id,fighter))
				index += 1
	await save_view(page,name_value)
	for entry in pending:
		record_held(entry)
	page.queue_free()
	await process_frame

func released_fixture(viewport: SubViewport, id: String, direction: int, broken: bool, mode_value: String) -> void:
	var fighter = fighter_for("fr_helmet_0",0,0,direction,-1.0)
	fighter.aim = .12
	fighter.broken = broken
	var actor = Fallen.new()
	viewport.add_child(actor)
	actor.setup(fighter,{"zone":"head","impulse":90.0,"direction":-direction})
	actor.set_process(false)
	actor.visual.set_process(false)
	actor.far_leg.set_process(false)
	actor.visual.mode = mode_value
	# Stage exactly the production release boundary. No simulated key presses,
	# scored contact or claim about the natural fall/release timing is made.
	var expected_grip: Vector2 = actor.to_global(actor.visual.detached_pose.right.hand)
	var expected_tip: Vector2 = Model.tip_position(fighter)
	actor._release_lance()
	var body: RigidBody2D = actor.loose_lance
	check(is_instance_valid(body),id+": production release creates weapon body")
	if not is_instance_valid(body):
		return
	body.freeze = true
	var renderer: Node2D
	for child in body.get_children():
		if child is Rider:
			renderer = child
			break
	check(is_instance_valid(renderer),id+": released body retains production RiderView")
	if not is_instance_valid(renderer):
		return
	renderer.set_process(false)
	var actual_grip = renderer.to_global(Vector2.ZERO)
	var actual_tip = renderer.to_global(Vector2(Model.lance_length(fighter),0))
	check(actual_grip.distance_to(expected_grip)<.001,id+": released grip remains continuous")
	check(actual_tip.distance_to(expected_tip)<.001,id+": released tip remains continuous")
	check(renderer.lance_only,id+": released renderer uses complete lance path")
	check(not actor.visual.detached_lance_visible and not actor.far_leg.detached_lance_visible,id+": release hides held copy")
	anchor_rows.append({"id":id,"kind":"production_release_boundary","direction":direction,"broken":broken,"mode":mode_value,"length":Model.lance_length(fighter),"grip_before":xy(expected_grip),"grip_after":xy(actual_grip),"tip_before":xy(expected_tip),"tip_after":xy(actual_tip),"released_renderer":"RiderView.lance_only","physics_frozen":true})
	actor.hide()
	# Frame the complete weapon, including its rear end, at the same scale for
	# whole and broken cases. The held close-ups intentionally focus on the face.
	var camera = Camera2D.new()
	camera.position = body.position
	camera.zoom = Vector2(1.1,1.1)
	viewport.add_child(camera)
	camera.make_current()
	fixture_count += 1

func released_sheet() -> void:
	var page = sheet(Vector2i(1640,740))
	UI.label(page,"DEV-055 · 完整独立落枪绘制 · production 释放边界固定帧 / 非自由落体时序测试",Vector2(12,7),18,UI.GOLD,1616)
	var index = 0
	for mode_value in ["arena","war"]:
		for broken in [false,true]:
			for direction in [1,-1]:
				var id = "released_%s_%s_dir%d" % [mode_value,"broken" if broken else "whole",direction]
				var viewport = cell(page,index,"%s · %s · 朝向 %d\n完整独立武器路径（含后柄）" % [mode_value,"断枪" if broken else "完整枪",direction])
				released_fixture(viewport,id,direction,broken,mode_value)
				index += 1
	await save_view(page,"released_whole_and_broken")
	page.queue_free()
	await process_frame

func run() -> void:
	captures = ""
	report_path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	var state = root.get_node_or_null("GameState")
	if not OS.get_cmdline_user_args().has("--test-profile") or state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("LANCE_LAYER_V055 requires GPU display and isolated -- --test-profile")
		quit(2)
		return
	if captures.is_empty() or report_path.is_empty() or DirAccess.dir_exists_absolute(captures) or FileAccess.file_exists(report_path):
		push_error("Pass --captures=<new directory> --report=<new JSON>; never replace earlier evidence")
		quit(2)
		return
	items = Catalogue.load_items()
	check(not Catalogue.find(items,armor).is_empty(),"Fixture armor exists")
	for helmet in HELMETS:
		check(not Catalogue.find(items,helmet).is_empty(),"Fixture helmet exists: "+helmet)
	if not failures.is_empty():
		quit(2)
		return
	check(DirAccess.make_dir_recursive_absolute(captures)==OK,"Create new capture directory")
	check(DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())==OK,"Create report directory")
	await held_sheet("back_lean_whole",false,false)
	await held_sheet("back_lean_broken",true,false)
	await held_sheet("back_lean_aim_extremes",false,true)
	await released_sheet()
	var report = {"passed":failures.is_empty(),"failures":failures,"fixtures":fixture_count,"captures":rows,"anchors":anchor_rows,"scope":"GPU fixed production RiderView poses and staged production FallenRider._release_lance boundary. No injected or OS input, no live fight, no free-flight timing test, no profile mutation. Model/renderer anchor invariants checked; occlusion and continuity require image review.","visual_acceptance":"pending manual image review"}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Unable to write LANCE_LAYER_V055 report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LANCE_LAYER_V055 completed=",failures.is_empty()," fixtures=",fixture_count," captures=",rows.size()," visual_acceptance=pending")
	quit(0 if failures.is_empty() else 1)
