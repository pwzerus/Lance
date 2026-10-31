extends SceneTree
## Interactive diagnostic only: real production RiderView with fixed poses.
## All changes come from controls; this file never injects input or writes profiles.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Appearance = preload("res://scripts/core/character_appearance.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")

class InputRecorder extends Node:
	var host
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			host.record({"kind":"os_mouse","button":event.button_index,"pressed":event.pressed,"position":str(event.position)})
		elif event is InputEventKey:
			host.record({"kind":"os_key","logical":event.keycode,"physical":event.physical_keycode,"pressed":event.pressed,"echo":event.echo})
		elif event is InputEventMouseMotion and event.button_mask!=0:
			host.record({"kind":"os_drag","buttons":event.button_mask,"position":str(event.position)})

var captures = "E:/GALUMU/docs/development/screenshots/v055/manual-pose"
var journal: FileAccess
var items: Array = []
var page: Control
var choices: Dictionary = {}
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var riders: Array = []
var status: Label
var pose_label: Label
var capture_count = 0
var capture_busy = false
var impact_enabled = false
var mounted_scale = 2.50

func _initialize() -> void:
	call_deferred("run")

func record(data: Dictionary) -> void:
	if journal==null:
		return
	data["ticks_ms"] = Time.get_ticks_msec()
	journal.store_line(JSON.stringify(data))
	journal.flush()

func selection(field: String) -> Variant:
	var option: OptionButton = choices[field]
	return option.get_item_metadata(option.selected)

func snapshot() -> Dictionary:
	return {"helmet":selection("helmet"),"armor":selection("armor"),
		"face_shape":selection("face_shape"),"skin":selection("skin"),"beard":selection("beard"),
		"lean":float(sliders.lean.value),"aim":float(sliders.aim.value),"guard":float(sliders.guard.value),
		"impact_recoil":.85 if impact_enabled else 0.0,"zoom":mounted_scale,
		"scope":"Interactive fixed production-renderer poses, both facings. Not a match, no gameplay timing or collision claim."}

func option_control(field: String, title: String, rectangle: Rect2, values: Array, labels: Array) -> void:
	UI.label(page,title,rectangle.position+Vector2(0,-23),16,UI.GOLD,rectangle.size.x)
	var option = OptionButton.new()
	option.position = rectangle.position
	option.size = rectangle.size
	option.add_theme_font_size_override("font_size",16)
	option.clip_text = true
	for i in range(values.size()):
		option.add_item(str(labels[i]))
		option.set_item_metadata(i,values[i])
	page.add_child(option)
	choices[field] = option
	option.item_selected.connect(func(_index: int): update_pose("select_"+field))

func slider_control(field: String, title: String, x: float, width: float, minimum: float, maximum: float, initial: float) -> void:
	value_labels[field] = UI.label(page,title,Vector2(x,121),16,UI.GOLD,width)
	var slider = HSlider.new()
	slider.position = Vector2(x,148)
	slider.size = Vector2(width,30)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = .01
	slider.value = initial
	page.add_child(slider)
	sliders[field] = slider
	slider.value_changed.connect(func(_value: float): update_pose("slider_"+field))

func select_value(field: String, value: Variant) -> void:
	var option: OptionButton = choices[field]
	for i in range(option.item_count):
		if option.get_item_metadata(i)==value:
			option.select(i)
			return

func make_view(x: float, direction: int) -> void:
	var panel = UI.panel(page,Rect2(x,223,700,540),Color("263a32"))
	UI.label(panel,"朝右 +1" if direction==1 else "朝左 -1",Vector2(14,8),18,UI.GOLD,660)
	var holder = SubViewportContainer.new()
	holder.position = Vector2(5,40)
	holder.size = Vector2(690,495)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(holder)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(690,495)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var rider = Rider.new()
	rider.preview = true
	rider.moving = false
	rider.blood_enabled = false
	rider.scale = Vector2.ONE*mounted_scale
	rider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(rider)
	rider.set_process(false)
	riders.append({"view":rider,"direction":direction})

func update_pose(reason: String) -> void:
	if riders.size()!=2 or sliders.size()!=3:
		return
	var params = snapshot()
	var equipment = {"helmet":params.helmet,"armor":params.armor,"horse":"horse_bay","lance":"lance_ash","shield":"shield_basic"}
	var stats = Catalogue.stats(items,equipment)
	stats.appearance = Appearance.defaults()
	for field in ["face_shape","skin","beard"]:
		stats.appearance[field] = int(params[field])
	var model = Model.new("arena",stats,stats,55055)
	for index in range(riders.size()):
		var fighter: Dictionary = model.fighters[index]
		fighter.x = 0.0
		fighter.lane_y = 0.0
		fighter.direction = int(riders[index].direction)
		fighter.lean = params.lean
		fighter.aim = params.aim
		fighter.guard = params.guard
		fighter.guard_target = params.guard
		fighter.speed = 0.0
		fighter.gait_moving = false
		fighter.gait_phase = 0.0
		fighter.motion_drive = 0.0
		var view = riders[index].view
		view.fighter = fighter
		view.clock = 0.0
		view.stride_phase = 0.0
		view._process(0.0)
		view.impact_recoil = params.impact_recoil
		view.position = Vector2(345,160)-Model.head_position(fighter)*mounted_scale
		view.queue_redraw()
	value_labels.lean.text = "俯仰 %.2f（-1后仰 / +1前倾）" % params.lean
	value_labels.aim.text = "枪角 %.2f rad" % params.aim
	value_labels.guard.text = "盾位 %.2f（0腹 / 1头）" % params.guard
	pose_label.text = "%s  /  %s  ·  身体角 %.1f°  ·  %s" % [params.helmet,params.armor,rad_to_deg(Model.pose_angle(model.fighters[0])),"受击定格" if impact_enabled else "无受击"]
	record({"kind":"pose_change","reason":reason,"pose":params})

func set_lean(value: float) -> void:
	sliders.lean.value = value
	update_pose("preset_lean")

func toggle_impact() -> void:
	impact_enabled = not impact_enabled
	update_pose("toggle_impact")

func save_capture() -> void:
	if capture_busy:
		return
	capture_busy = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var params = snapshot()
	capture_count += 1
	var basename = "pose_%03d" % capture_count
	var image_path = captures.path_join(basename+".png")
	var sidecar_path = captures.path_join(basename+".json")
	var image_result = root.get_texture().get_image().save_png(image_path)
	var sidecar = FileAccess.open(sidecar_path,FileAccess.WRITE)
	params["ticks_ms"] = Time.get_ticks_msec()
	params["image"] = image_path
	params["image_saved"] = image_result==OK
	params["build"] = ProjectSettings.get_setting("application/config/version","unknown")
	if sidecar:
		sidecar.store_string(JSON.stringify(params,"\t"))
		sidecar.close()
	status.text = "已保存 "+basename+"（PNG+参数）" if image_result==OK and sidecar!=null else "保存失败，请检查日志"
	record({"kind":"capture","image":image_path,"saved":image_result==OK,"sidecar_saved":sidecar!=null,"pose":params})
	print("HEAD_MANUAL_V055 capture=",basename," saved=",image_result==OK)
	capture_busy = false

func finish() -> void:
	record({"kind":"session_end","captures":capture_count,"pose":snapshot(),"acceptance":"Not scored; inspect the images"})
	if journal:
		journal.close()
	quit()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			captures = arg.trim_prefix("--captures=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("HEAD_MANUAL_V055 requires a GPU window and -- --test-profile")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(captures):
		push_error("Choose a fresh capture directory; existing evidence is retained")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(captures)!=OK:
		push_error("Cannot create capture directory")
		quit(2)
		return
	journal = FileAccess.open(captures.path_join("events.jsonl"),FileAccess.WRITE)
	if journal==null:
		push_error("Cannot open diagnostic journal")
		quit(2)
		return
	items = Catalogue.load_items()
	var helmets: Array = []
	var armor: Array = []
	var helmet_names: Array = []
	var armor_names: Array = []
	for region in ["eng","fr","de","it"]:
		for tier in range(6):
			for slot in ["helmet","armor"]:
				var id = "%s_%s_%d" % [region,slot,tier]
				var entry = Catalogue.find(items,id)
				if entry.is_empty():
					push_error("Missing catalogue item: "+id)
					quit(2)
					return
				if slot=="helmet":
					helmets.append(id)
					helmet_names.append(id+" · "+str(entry.name))
				else:
					armor.append(id)
					armor_names.append(id+" · "+str(entry.name))
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.title = "GALUMU v"+str(ProjectSettings.get_setting("application/config/version","?"))+" - Interactive QA poses, NOT a match"
	page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var background = ColorRect.new()
	background.color = Color("15221e")
	background.size = Vector2(1440,810)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	UI.label(page,"交互QA姿态，非比赛 · 原生产骑手 / 左右对照",Vector2(16,9),22,UI.GOLD,1408)
	option_control("helmet","头盔（24）",Rect2(16,70,430,38),helmets,helmet_names)
	option_control("armor","胸甲（24）",Rect2(456,70,430,38),armor,armor_names)
	option_control("face_shape","脸型",Rect2(896,70,160,38),[0,1,2,3],Appearance.OPTIONS.face_shape)
	option_control("skin","肤色",Rect2(1066,70,170,38),[0,1,2,3,4,5],Appearance.OPTIONS.skin)
	option_control("beard","胡须",Rect2(1246,70,178,38),[0,1,2,3,4],Appearance.OPTIONS.beard)
	select_value("helmet","fr_helmet_0")
	select_value("armor","eng_armor_0")
	slider_control("lean","俯仰",16,430,-1,1,0)
	slider_control("aim","枪角",466,360,-.68,.58,-.16)
	slider_control("guard","盾位",846,280,0,1,0)
	UI.button(page,"保存图",Rect2(1146,136,128,42),save_capture,true)
	UI.button(page,"退出QA",Rect2(1284,136,140,42),finish)
	UI.button(page,"中立",Rect2(16,181,100,32),func(): set_lean(0.0))
	UI.button(page,"前倾",Rect2(126,181,100,32),func(): set_lean(1.0))
	UI.button(page,"后仰",Rect2(236,181,100,32),func(): set_lean(-1.0))
	UI.button(page,"受击开/关",Rect2(346,181,130,32),toggle_impact)
	pose_label = UI.label(page,"",Vector2(492,187),16,UI.MUTED,932)
	make_view(16,1)
	make_view(724,-1)
	status = UI.label(page,"拖动滑条检查中间姿态；保存图包含当前参数。未写玩家存档。",Vector2(16,774),16,UI.MUTED,1400)
	var recorder = InputRecorder.new()
	recorder.host = self
	root.add_child(recorder)
	root.close_requested.connect(finish)
	record({"kind":"session_begin","build":ProjectSettings.get_setting("application/config/version","unknown"),"executable":OS.get_executable_path(),"qa_guard":state.save_path,"injected_inputs":false,"scope":"Interactive diagnostic controls over production rendering; not a playable match or OS timing test"})
	update_pose("initial_fixture")
	print("HEAD_MANUAL_V055 ready captures=",captures)
