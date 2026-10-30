extends SceneTree
## Offscreen GPU renders of production RiderView. Engine fixture poses, not OS
## input or player experience evidence. Run with -- --test-profile.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Face = preload("res://scripts/core/character_appearance.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const COUNTRIES = ["eng", "fr", "de", "it"]
const DIRECTIONS = [1, -1]
const POSES = [
	{"id":"forward_high", "label":"前倾 / 护头", "lean":1.0, "guard":1.0},
	{"id":"back_low", "label":"后仰 / 护腹", "lean":-1.0, "guard":0.0}
]
var captures = "E:/GALUMU/docs/development/screenshots/v051/equipment-poses01"
var report = "E:/GALUMU/docs/development/logs/v051/equipment-poses01.json"
var mode = "arena"
var items: Array = []
var failures: Array[String] = []
var pose_rows: Array = []
var face_rows: Array = []
var capture_rows: Array = []
var open_ids: Array[String] = []
var atlas: SubViewport
var surface: Control
var current_page = ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, detail: Dictionary = {}) -> bool:
	if not ok:
		failures.append(message+" "+str(detail))
		push_error(message+" "+str(detail))
	return ok

func _arguments() -> void:
	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg = str(args[i])
		if arg.begins_with("--captures="):
			captures = arg.trim_prefix("--captures=")
		elif arg=="--captures" and i+1<args.size():
			captures = str(args[i+1])
		elif arg.begins_with("--report="):
			report = arg.trim_prefix("--report=")
		elif arg=="--report" and i+1<args.size():
			report = str(args[i+1])
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")

func _page(page_name: String, dimensions: Vector2i, title: String) -> void:
	current_page = page_name
	atlas = SubViewport.new()
	atlas.name = "EquipmentPoseAtlas"
	atlas.size = dimensions
	atlas.disable_3d = true
	atlas.transparent_bg = false
	atlas.world_2d = World2D.new()
	atlas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(atlas)
	surface = Control.new()
	surface.theme = UI.theme()
	surface.size = Vector2(dimensions)
	atlas.add_child(surface)
	var bg = ColorRect.new()
	bg.color = Color("20322d")
	bg.size = Vector2(dimensions)
	surface.add_child(bg)
	UI.label(surface,title,Vector2(16,9),20,UI.GOLD,dimensions.x-32)

func _cell(point: Vector2, dimensions: Vector2i, title: String) -> SubViewport:
	var panel = Panel.new()
	panel.position = point
	panel.size = Vector2(dimensions)
	panel.add_theme_stylebox_override("panel",UI.box(Color("2a3c36"),Color("617464"),0))
	surface.add_child(panel)
	UI.label(panel,title,Vector2(10,6),13,UI.INK,dimensions.x-20)
	var holder = SubViewportContainer.new()
	holder.position = Vector2(2,49)
	holder.size = Vector2(dimensions.x-4,dimensions.y-51)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(holder)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(dimensions.x-4,dimensions.y-51)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var bg = ColorRect.new()
	bg.color = Color("34483f")
	bg.size = Vector2(viewport.size)
	viewport.add_child(bg)
	return viewport

func _fighter(country: String, tier: int, direction: int, pose: Dictionary, appearance: Dictionary) -> Dictionary:
	var equipment = {
		"helmet":"%s_helmet_%d" % [country,tier],
		"armor":"%s_armor_%d" % [country,tier],
		"lance":"lance_ash", "horse":"horse_bay", "shield":"shield_basic"
	}
	var stats = Catalogue.stats(items,equipment).duplicate(true)
	stats.appearance = appearance.duplicate(true)
	var model = Model.new(mode,stats,stats,51051)
	var value: Dictionary = model.fighters[0 if direction==1 else 1]
	value.x = 0.0
	value.lane_y = 0.0
	value.direction = direction
	value.speed = 0.0
	value.gait_moving = false
	value.gait_phase = 0.0
	value.motion_drive = 0.0
	# These are intentional pose fixtures. They do not test how fast real
	# controls reach an extreme, and do not bypass controls in production.
	value.lean = float(pose.lean)
	value.guard = float(pose.guard)
	value.guard_target = float(pose.guard)
	value.aim = .12
	return value

func _rider(viewport: SubViewport, value: Dictionary, zoom: float, head_close: bool) -> RiderView:
	var view = Rider.new()
	view.fighter = value
	view.mode = mode
	view.moving = false
	view.preview = false
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.scale = Vector2.ONE*zoom
	if head_close:
		# Crop an actual mounted RiderView around its actual model head. Face
		# drawing, helmet transform and shoulder layers remain production code.
		view.position = Vector2(viewport.size.x*.5,125.0)-Model.head_position(value)*zoom
		view.detached_lance_visible = false
	else:
		view.position = Vector2(viewport.size.x*.5,viewport.size.y-19)
	viewport.add_child(view)
	view._process(0.0)
	view.set_process(false)
	view.queue_redraw()
	return view

func _pose_record(value: Dictionary, view: RiderView, country: String, tier: int, pose: Dictionary) -> Dictionary:
	var helmet_id = "%s_helmet_%d" % [country,tier]
	var armor_id = "%s_armor_%d" % [country,tier]
	var entry = Art.descriptor(value.stats,"helmet")
	return {
		"page":current_page,"country":country,"tier":tier,
		"helmet_id":helmet_id,"armor_id":armor_id,
		"direction":value.direction,"pose":pose.id,
		"lean":value.lean,"guard":value.guard,"mode":mode,
		"helmet_open_face":bool(entry.get("open_face",false)),
		"helmet_draw_size":entry.get("draw_size",[]),
		"face_rect":entry.get("face_rect",[]),
		"head_anchor":_xy(Model.head_position(value)),
		"body_anchor":_xy(Model.body_position(value)),
		"lance_hand":_xy(Model.hand_position(value)),
		"shield_center":_xy(Model.shield_position(value)),
		"view_position":_xy(view.position),"zoom":view.scale.x,
		"fixture":"frozen production RiderView at explicitly assigned pose; visual judgment pending"
	}

func _xy(point: Vector2) -> Array:
	return [point.x,point.y]

func _capture() -> void:
	# Two frames allow deferred UI sizing/viewport backing stores to settle;
	# frame_post_draw establishes actual renderer completion before readback.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = atlas.get_texture().get_image()
	if check(image!=null,"Atlas renderer returned an image",{"page":current_page}):
		var path = captures.path_join(current_page+".png")
		var error = image.save_png(path)
		check(error==OK,"Atlas PNG saved",{"path":path,"error":error})
		capture_rows.append({"page":current_page,"path":path,"width":image.get_width(),"height":image.get_height(),"saved":error==OK})
		print("EQUIPMENT_POSES_V051 page=",current_page," size=",image.get_size()," saved=",error==OK)
	atlas.queue_free()
	atlas = null
	surface = null
	await process_frame
	await process_frame

func _render_country(country: String, pose: Dictionary) -> void:
	_page(country+"_"+str(pose.id),Vector2i(1920,1368),"%s · %s · 每档左右同屏 · %s · 自动姿态夹具" % [country,pose.label,mode])
	for tier in range(6):
		var helmet = Catalogue.find(items,"%s_helmet_%d" % [country,tier])
		var armor = Catalogue.find(items,"%s_armor_%d" % [country,tier])
		if helmet.is_empty() or armor.is_empty():
			continue
		for side in range(2):
			var direction = int(DIRECTIONS[side])
			var index = tier*2+side
			var origin = Vector2((index%4)*480,48+(index/4)*440)
			var label = "%d  %s  %s\n%s / %s" % [tier,"朝右" if direction==1 else "朝左",helmet.name,armor.name,pose.label]
			var viewport = _cell(origin,Vector2i(480,440),label)
			var value = _fighter(country,tier,direction,pose,Face.defaults())
			var view = _rider(viewport,value,.88,false)
			pose_rows.append(_pose_record(value,view,country,tier,pose))
	await _capture()

func _render_faces(helmet: Dictionary) -> void:
	var id = str(helmet.id)
	var pieces = id.split("_")
	var country = str(pieces[0])
	var tier = int(pieces[2])
	var entry = Art.descriptor(helmet.stats,"helmet")
	_page("faces_"+id,Vector2i(1600,832),"%s · 四脸型×左右 · 最大胡须 · 使用最新manifest / 实际RiderView" % helmet.name)
	for shape in range(4):
		for side in range(2):
			var direction = int(DIRECTIONS[side])
			var index = shape*2+side
			var origin = Vector2((index%4)*400,48+(index/4)*392)
			var label = "脸型%d%s · %s\n最大胡须 / 低盾 / 头肩裁切" % [shape,"宽脸" if shape==1 else ("长脸" if shape==2 else ""),"朝右" if direction==1 else "朝左"]
			var viewport = _cell(origin,Vector2i(400,392),label)
			var appearance = Face.defaults()
			appearance.face_shape = shape
			appearance.beard = 4
			appearance.brows = 1
			appearance.skin = [1,2,3,4][shape]
			appearance.eyes = shape%5
			appearance.hair = shape%4
			var neutral = {"id":"head_close","lean":0.0,"guard":0.0}
			var value = _fighter(country,tier,direction,neutral,appearance)
			var view = _rider(viewport,value,2.5,true)
			var row = _pose_record(value,view,country,tier,neutral)
			row.appearance = appearance.duplicate(true)
			row.latest_manifest_draw_size = entry.get("draw_size",[])
			row.latest_manifest_face_rect = entry.get("face_rect",[])
			row.lance_hidden_for_head_inspection = true
			face_rows.append(row)
	await _capture()

func _coverage() -> void:
	# Presence and rendered fixture coverage, not a claim that pixels are free
	# of clipping. That conclusion requires reviewing the saved images.
	for country in COUNTRIES:
		for tier in range(6):
			for direction in DIRECTIONS:
				for pose in POSES:
					var found = false
					for row in pose_rows:
						if row.country==country and row.tier==tier and row.direction==direction and row.pose==pose.id:
							found = true
							break
					check(found,"Required region/quality/direction/extreme pose has a render fixture",{"country":country,"tier":tier,"direction":direction,"pose":pose.id})
	for id in open_ids:
		for shape in range(4):
			for direction in DIRECTIONS:
				var found = false
				for row in face_rows:
					if row.helmet_id==id and int(row.appearance.face_shape)==shape and row.direction==direction:
						found = true
						break
				check(found,"Open helmet has each face shape and direction fixture",{"id":id,"shape":shape,"direction":direction})
	for id in ["fr_helmet_4","it_helmet_3"]:
		check(id in open_ids,"Recent open-face correction is included from current manifest",{"id":id})

func _finish(exit_code: int = -1) -> void:
	var result = {
		"passed":failures.is_empty(),"failures":failures,
		"mode":mode,"pose_rows":pose_rows,"face_rows":face_rows,
		"open_helmet_ids":open_ids,"captures":capture_rows,
		"scope":"Production RiderView rendered in nested SubViewports: 24 regional helmet/torso pairs, both facings, full forward/high-shield and full backward/low-shield; every authored open helmet has four face shapes with maximum beard in both facings. Programmatically assigned frozen fixtures, not OS input, control-rate validation, moving combat or human play. Saved images require visual review for overlap and connection quality.",
		"visual_acceptance":"not asserted by fixture-count checks; inspect PNGs",
		"capture_pixels_are_actual_godot_render_readback":true
	}
	DirAccess.make_dir_recursive_absolute(report.get_base_dir())
	var file = FileAccess.open(report,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	else:
		push_error("Cannot write equipment pose report: "+report)
		quit(2)
		return
	print("EQUIPMENT_POSES_V051 passed=",result.passed," pages=",capture_rows.size()," open_helmets=",open_ids.size())
	quit(exit_code if exit_code>=0 else (0 if failures.is_empty() else 1))

func run() -> void:
	_arguments()
	var state = root.get_node_or_null("GameState")
	if not check(state!=null and str(state.save_path).contains("qa_"),"Use isolated --test-profile; formal profile is forbidden"):
		_finish(2)
		return
	if not check(mode in ["arena","war"],"Mode is arena or war",{"mode":mode}):
		_finish(2)
		return
	if not check(DisplayServer.get_name()!="headless","A rendering display is required; no headless pixel claims"):
		_finish(2)
		return
	items = Catalogue.load_items()
	for country in COUNTRIES:
		for tier in range(6):
			for slot in ["helmet","armor"]:
				var id = "%s_%s_%d" % [country,slot,tier]
				var item = Catalogue.find(items,id)
				if not check(not item.is_empty(),"Regional equipment exists",{"id":id}):
					continue
				var entry = Art.descriptor(item.stats,slot)
				check(not entry.is_empty() and Art.equipment_texture(item.stats,slot)!=null,"Actual authored asset is imported; no silent fallback",{"id":id})
				if slot=="helmet" and bool(entry.get("open_face",false)):
					open_ids.append(id)
	if not failures.is_empty():
		_finish(2)
		return
	DirAccess.make_dir_recursive_absolute(captures)
	for country in COUNTRIES:
		for pose in POSES:
			await _render_country(country,pose)
	for id in open_ids:
		await _render_faces(Catalogue.find(items,id))
	_coverage()
	_finish()
