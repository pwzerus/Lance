extends SceneTree
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
var page: Control
var capture_dir = "E:/GALUMU/docs/development/screenshots/v044/art02"

func _initialize() -> void:
	call_deferred("run")

func make_page(title: String) -> void:
	page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var bg = ColorRect.new()
	bg.color = Color("17251f")
	bg.size = Vector2(1440,810)
	page.add_child(bg)
	UI.label(page,title,Vector2(24,14),27,UI.GOLD)

func rider_at(index: int, phase: float, direction: int, lean: float, guard: float, moving: bool = true, speed_value: float = 480.0) -> void:
	var panel = UI.panel(page,Rect2(12+(index%4)*356,64+(index/4)*366,344,350))
	panel.clip_contents = true
	UI.label(panel,"相位 %d%% · %s" % [roundi(phase/TAU*100),"右向" if direction==1 else "左向"],Vector2(14,12),16,UI.GOLD)
	var model = Model.new()
	var fighter = model.fighters[0]
	fighter.x = 0
	fighter.direction = direction
	fighter.lean = lean
	fighter.guard = guard
	fighter.aim = -.12
	fighter.speed = speed_value
	fighter.gait_phase = phase
	fighter.gait_moving = moving
	var rider = Rider.new()
	rider.fighter = fighter
	rider.moving = moving
	rider.stride_phase = phase
	rider.position = Vector2(167,312)
	rider.scale = Vector2.ONE*.81
	panel.add_child(rider)
	rider.set_process(false)
	var ground = ColorRect.new()
	ground.position = Vector2(0,322)
	ground.size = Vector2(344,1)
	ground.color = Color("657756")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ground)

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var code = root.get_texture().get_image().save_png(capture_dir+"/"+name_value+".png")
	print("ART_V044_CAPTURE ",name_value," ",code)
	page.queue_free()
	await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	for gait in range(4):
		var speed_value = [110.0,210.0,340.0,480.0][gait]
		make_page(["慢步：四拍支撑","小跑：对角两拍","跑步：三拍起伏","疾驰：蹬地 / 收腿 / 腾空"][gait])
		for i in range(8):
			rider_at(i,TAU*i/8,1,0,.43,true,speed_value)
		await capture("gait_"+str(gait))
	make_page("右手持枪 / 左手持盾 · 对称骨长 · 双向极限姿态")
	for i in range(8):
		rider_at(i,TAU*(i%4)/4,1 if i<4 else -1,1 if i%2==0 else -1,1 if i%2==0 else 0)
	await capture("arms_extremes")
	make_page("三档盾位：左臂在前，右臂持枪在后")
	for i in range(8):
		rider_at(i,0,1 if i<4 else -1,0,[0.0,.43,1.0,.43][i%4],false)
	await capture("arms_guards")
	print("ART_V044_COMPLETE")
	quit()

