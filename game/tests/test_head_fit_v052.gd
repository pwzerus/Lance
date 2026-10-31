extends SceneTree
## Actual GPU readback of production RiderView. Connected-alpha checks catch
## floating heads, but do not assert artistic quality or player satisfaction.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Fit = preload("res://scripts/visual/head_fit.gd")
const Appearance = preload("res://scripts/core/character_appearance.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const POSES = [{"id":"neutral","lean":0.0},{"id":"forward","lean":1.0},{"id":"back","lean":-1.0}]
var destination = "E:/GALUMU/docs/development/screenshots/v052/fit01"
var report_path = "E:/GALUMU/docs/development/logs/v052/fit01.json"
var items: Array
var rows: Array = []
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func fighter_for(helmet: String, armor: String, direction: int, lean: float, phase: float) -> Dictionary:
	var stats = Catalogue.stats(items,{"helmet":helmet,"armor":armor,"horse":"horse_bay","lance":"lance_ash","shield":"shield_basic"})
	stats.appearance = Appearance.defaults()
	stats.appearance.beard = 4
	stats.appearance.face_shape = 1
	var model = Model.new("arena",stats,stats,52052)
	var f: Dictionary = model.fighters[0 if direction==1 else 1]
	f.x = 0.0
	f.lane_y = 0.0
	f.direction = direction
	f.lean = lean
	f.guard = 0.0
	f.guard_target = 0.0
	f.aim = -.2
	f.speed = 480.0
	f.gait_moving = true
	f.gait_phase = phase
	return f

func connected(image: Image, start: Vector2i, finish: Vector2i) -> bool:
	# Local head-to-upper-chest region excludes the horse and the lower arms.
	var area = Rect2i(start-Vector2i(116,106),Vector2i(232,225)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var queue: Array[Vector2i] = []
	var seen = {}
	for dy in range(-9,10):
		for dx in range(-9,10):
			var point = start+Vector2i(dx,dy)
			if area.has_point(point) and image.get_pixelv(point).a>.5:
				queue.append(point)
				seen[point] = true
	var index = 0
	while index<queue.size():
		var point: Vector2i = queue[index]
		index += 1
		if point.distance_squared_to(finish)<100:
			return true
		for delta in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			var next = point+delta
			if area.has_point(next) and not seen.has(next) and image.get_pixelv(next).a>.5:
				seen[next] = true
				queue.append(next)
	return false

func page(name: String, combinations: Array, pose: Dictionary) -> void:
	var sheet = SubViewport.new()
	sheet.size = Vector2i(1600,1128)
	sheet.disable_3d = true
	sheet.world_2d = World2D.new()
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var surface = Control.new()
	surface.theme = UI.theme()
	sheet.add_child(surface)
	var bg = ColorRect.new()
	bg.size = Vector2(sheet.size)
	bg.color = Color("20322d")
	surface.add_child(bg)
	UI.label(surface,"DEV-052 · "+name+" · 生产渲染 / 自动姿态与连接检查",Vector2(16,8),20,UI.GOLD,1560)
	var probes: Array = []
	for index in range(combinations.size()):
		var item: Dictionary = combinations[index]
		var panel = UI.panel(surface,Rect2((index%4)*400,48+(index/4)*360,398,358))
		UI.label(panel,str(item.helmet)+" / "+str(item.armor)+"\n"+pose.id+(" 右" if item.direction==1 else " 左"),Vector2(8,4),13,UI.INK,380)
		var holder = SubViewportContainer.new()
		holder.position = Vector2(1,44)
		panel.add_child(holder)
		var viewport = SubViewport.new()
		viewport.size = Vector2i(396,312)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		holder.add_child(viewport)
		var f = fighter_for(item.helmet,item.armor,item.direction,pose.lean,float(index)*TAU/12.0)
		f.stats.appearance.beard = int(item.get("beard",4))
		var view = Rider.new()
		view.fighter = f
		view.moving = true
		view.preview = false
		view.detached_lance_visible = false
		view.scale = Vector2.ONE*2.0
		view.position = Vector2(198,119)-Model.head_position(f)*2.0
		viewport.add_child(view)
		view._process(0.0)
		view.set_process(false)
		view.impact_recoil = .7 if index%3==0 else 0.0
		view.queue_redraw()
		var torso: Transform2D = Rider.arm_pose(f).torso_transform
		probes.append({"viewport":viewport,"start":Vector2i(198,119),"finish":Vector2i(view.position+(torso*Vector2(0,-70))*2.0),"helmet":item.helmet,"armor":item.armor,"direction":item.direction,"fit":Fit.layout(f.stats)})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	for probe in probes:
		var pixels: Image = probe.viewport.get_texture().get_image()
		var joined = connected(pixels,probe.start,probe.finish)
		check(joined,"Disconnected head/chest pixels: "+name+" "+str(probe.helmet)+" "+str(probe.direction))
		rows.append({"page":name,"helmet":probe.helmet,"armor":probe.armor,"direction":probe.direction,"pose":pose.id,"connected_alpha":joined,"layout":str(probe.fit)})
	var output = sheet.get_texture().get_image()
	check(output.save_png(destination.path_join(name+".png"))==OK,"Capture saved: "+name)
	print("HEAD_FIT_V052 page=",name," fixtures=",probes.size())
	sheet.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): destination = arg.trim_prefix("--captures=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Requires GPU rendering with isolated --test-profile")
		quit(2)
		return
	items = Catalogue.load_items()
	DirAccess.make_dir_recursive_absolute(destination)
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	for country in ["eng","fr","de","it"]:
		var pairs: Array = []
		for tier in range(6):
			for direction in [1,-1]:
				pairs.append({"helmet":"%s_helmet_%d" % [country,tier],"armor":"%s_armor_%d" % [country,tier],"direction":direction})
		for pose in POSES:
			await page(country+"_"+pose.id,pairs,pose)
	var mixed: Array = []
	var combinations = [["fr_helmet_0","de_armor_5"],["eng_helmet_5","mail_basic"],["fr_helmet_4","it_armor_2"],["it_helmet_3","eng_armor_2"],["helm_e2","armor_e2"],["helm_nasal","fr_armor_4"]]
	for pair in combinations:
		for direction in [1,-1]:
			mixed.append({"helmet":pair[0],"armor":pair[1],"direction":direction})
	for pose in POSES:
		await page("mixed_"+pose.id,mixed,pose)
	var beards: Array = []
	for beard in range(5):
		for direction in [1,-1]:
			beards.append({"helmet":"fr_helmet_0","armor":"fr_armor_0","direction":direction,"beard":beard})
	await page("open_helmet_beards",beards,POSES[0])
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"GPU frozen production rider poses at gait phases/recoil, 24 sets + 6 cross/legacy pairs, both directions, three lean poses. Alpha connectivity catches detached silhouettes; proportion and face fit still require visual inspection. No OS input or player enjoyment claim."},"\t"))
	file.close()
	print("HEAD_FIT_V052 passed=",failures.is_empty()," fixtures=",rows.size())
	quit(0 if failures.is_empty() else 1)
