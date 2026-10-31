extends SceneTree
## Real GPU captures of production menu / RiderView. This checks only that the
## intended fixtures render and save. Fit and proportions require image review.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Appearance = preload("res://scripts/core/character_appearance.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const HELMETS = ["fr_helmet_0","eng_helmet_0"]
const BEARDS = [0,2,4]
var captures = "E:/GALUMU/docs/development/screenshots/v053/wear01"
var report_path = "E:/GALUMU/docs/development/logs/v053/wear01.json"
var armor = "eng_armor_0"
var menu_armors = ["eng_armor_0","fr_armor_0"]
var items: Array = []
var failures: Array = []
var rows: Array = []
var main: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func wait_draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func save_view(viewport: Viewport, name_value: String) -> void:
	await wait_draw()
	var pixels: Image = viewport.get_texture().get_image()
	var path = captures.path_join(name_value+".png")
	var result = pixels.save_png(path)
	check(result==OK,"Capture saved: "+path)
	rows.append({"capture":name_value,"width":pixels.get_width(),"height":pixels.get_height(),"saved":result==OK})
	print("HEAD_WEAR_V053 capture=",name_value," saved=",result==OK)

func fighter_for(helmet: String, shape: int, beard: int, direction: int = 1, lean: float = 0.0) -> Dictionary:
	var equipment = {"helmet":helmet,"armor":armor,"horse":"horse_bay","lance":"lance_ash","shield":"shield_basic"}
	var stats = Catalogue.stats(items,equipment)
	stats.appearance = Appearance.defaults()
	stats.appearance.face_shape = shape
	stats.appearance.beard = beard
	var model = Model.new("arena",stats,stats,53053)
	var f: Dictionary = model.fighters[0 if direction==1 else 1]
	f.x = 0.0
	f.lane_y = 0.0
	f.direction = direction
	f.lean = lean
	f.guard = 0.0
	f.guard_target = 0.0
	f.aim = -.16
	f.speed = 0.0
	f.gait_moving = false
	f.gait_phase = 0.0
	f.motion_drive = 0.0
	return f

func frozen_rider(viewport: SubViewport, fighter: Dictionary, zoom: float, center: Vector2) -> Node2D:
	var view = Rider.new()
	view.fighter = fighter.duplicate(true)
	view.preview = true
	view.moving = false
	view.detached_lance_visible = false
	view.scale = Vector2.ONE*zoom
	view.position = center-Model.head_position(view.fighter)*zoom
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(view)
	view.clock = 0.0
	view.stride_phase = 0.0
	view._process(0.0)
	view.set_process(false)
	view.queue_redraw()
	return view

func sheet(size: Vector2i) -> SubViewport:
	var viewport = SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg = ColorRect.new()
	bg.size = Vector2(size)
	bg.color = Color("263a32")
	viewport.add_child(bg)
	return viewport

func cell(page: SubViewport, index: int, title: String) -> SubViewport:
	var panel = UI.panel(page,Rect2((index%4)*410,40+(index/4)*350,408,348))
	UI.label(panel,title,Vector2(8,6),14,UI.INK,392)
	var holder = SubViewportContainer.new()
	holder.position = Vector2(1,49)
	panel.add_child(holder)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(406,297)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	return viewport

func menu_pair(state: Node, helmet: String) -> void:
	state.profile.equipped.helmet = helmet
	state.profile.equipped.armor = armor
	state.profile.appearance = Appearance.defaults()
	main.show_home()
	await process_frame
	main.preview.clock = 0.0
	main.preview.stride_phase = 0.0
	main.preview._process(0.0)
	main.preview.set_process(false)
	main.preview.queue_redraw()
	await save_view(root,"home_"+helmet+"_"+armor)
	# Draw the same production fighter at exactly twice the menu's 1.42 scale.
	# The image is a direct GPU capture, not an edited/cropped screenshot.
	var close = sheet(Vector2i(700,510))
	UI.label(close,"同一营地骑手 · 2×显示比例 · "+helmet,Vector2(14,12),18,UI.GOLD,672)
	frozen_rider(close,main.preview.fighter,2.84,Vector2(350,178))
	await save_view(close,"home_2x_"+helmet+"_"+armor)
	close.queue_free()
	await process_frame

func face_sheet(helmet: String) -> void:
	var page = sheet(Vector2i(1640,1090))
	UI.label(page,"DEV-053 · "+helmet+" / "+armor+" · 四脸型×三胡须 · 原生产佩戴 / 2×营地比例",Vector2(12,7),18,UI.GOLD,1616)
	for beard_index in range(BEARDS.size()):
		for shape in range(4):
			var beard: int = BEARDS[beard_index]
			var viewport = cell(page,beard_index*4+shape,"脸型 %d  胡须 %d  朝右" % [shape,beard])
			frozen_rider(viewport,fighter_for(helmet,shape,beard),2.84,Vector2(203,116))
	await save_view(page,"faces_"+helmet)
	page.queue_free()
	await process_frame

func pose_sheet() -> void:
	var page = sheet(Vector2i(1640,1090))
	UI.label(page,"DEV-053 · 两种反馈头盔 · 双向中立/前倾/后仰 · 固定姿态并非玩家操作",Vector2(12,7),18,UI.GOLD,1616)
	var index = 0
	for lean in [0.0,1.0,-1.0]:
		for helmet in HELMETS:
			for direction in [1,-1]:
				var viewport = cell(page,index,"%s / %s\n俯仰 %.1f  朝向 %d" % [helmet,armor,lean,direction])
				frozen_rider(viewport,fighter_for(helmet,0,0,direction,lean),2.2,Vector2(203,112))
				index += 1
	await save_view(page,"poses_both_feedback_helmets")
	page.queue_free()
	await process_frame

func dark_skin_high_collars() -> void:
	var page = sheet(Vector2i(1640,1090))
	UI.label(page,"DEV-053 · 最深肤色 / 无胡须 · 高领混搭与封闭盔 · 双朝向",Vector2(12,7),18,UI.GOLD,1616)
	var combinations = [["fr_helmet_0","de_armor_5"],["fr_helmet_0","fr_armor_4"],["fr_helmet_0","it_armor_3"],["fr_helmet_4","fr_armor_4"],["de_helmet_3","de_armor_3"],["de_helmet_5","de_armor_5"]]
	var original_armor: String = armor
	var index = 0
	for pair in combinations:
		armor = str(pair[1])
		for direction in [1,-1]:
			var viewport = cell(page,index,"%s / %s\n最深肤色 · 无胡须 · 朝向 %d" % [pair[0],armor,direction])
			var fighter = fighter_for(str(pair[0]),0,0,direction)
			fighter.stats.appearance.skin = 5
			frozen_rider(viewport,fighter,2.84,Vector2(203,116))
			index += 1
	armor = original_armor
	await save_view(page,"dark_skin_high_collars")
	page.queue_free()
	await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--armor="):
			armor = arg.trim_prefix("--armor=")
			menu_armors = [armor]
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("HEAD_WEAR_V053 requires GPU display and isolated -- --test-profile")
		quit(2)
		return
	if FileAccess.file_exists(report_path):
		push_error("Use a fresh report path; existing evidence must be retained")
		quit(2)
		return
	var original: Dictionary = state.profile.duplicate(true)
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	items = Catalogue.load_items()
	check(not Catalogue.find(items,armor).is_empty(),"Requested armor exists: "+armor)
	for helmet in HELMETS:
		check(not Catalogue.find(items,helmet).is_empty(),"Feedback helmet exists: "+helmet)
	if not failures.is_empty():
		state.profile = original
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(captures)
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	var sheet_armor: String = armor
	for menu_armor in menu_armors:
		armor = str(menu_armor)
		for helmet in HELMETS:
			await menu_pair(state,helmet)
	armor = sheet_armor
	main.queue_free()
	await process_frame
	await process_frame
	for helmet in HELMETS:
		await face_sheet(helmet)
	await pose_sheet()
	await dark_skin_high_collars()
	state.profile = original
	var report = {"passed":failures.is_empty(),"failures":failures,"rows":rows,"armor":armor,"helmets":HELMETS,"visual_acceptance":"Requires visual review; no automated aesthetic score","scope":"Production home at 1440x810 and twice its 1.42 rider scale, 4 face shapes x 3 beards per feedback helmet, both facings and lean extremes; darkest skin/no beard with 3 kettle-hat/high-collar mixes and 3 sallet/closed/close-fitting regional sets in both directions. GPU frozen poses, no OS or human play. Armor identity inferred from screenshot; --armor may override. QA profile changes are in-memory and restored; no saves are written."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Unable to write head-wear report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("HEAD_WEAR_V053 completed=",failures.is_empty()," captures=",rows.size()," visual_acceptance=pending")
	quit(0 if failures.is_empty() else 1)
