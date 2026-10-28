extends SceneTree
## Continuous rendering study. Model-driven inputs, not OS input or human play.
## Run with --write-movie <new-path>.avi --fixed-fps 30 --disable-vsync.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const DT = 1.0 / 30.0
const TOTAL_FRAMES = 360
const CAPTURE_FRAMES = [20, 65, 110, 155, 200, 235, 290, 345]

class TrackFloor extends Node2D:
	var travel = 0.0
	var facing = 1
	var body_height = 0.0
	func _draw() -> void:
		draw_rect(Rect2(0, 313, 1416, 32), Color("514d3b"))
		draw_line(Vector2(0, 313), Vector2(1416, 313), Color("b4ad84"), 2.0)
		for i in range(-2, 25):
			var x = i * 64.0 - fposmod(travel * .9, 64.0)
			draw_line(Vector2(x, 329), Vector2(x + 19, 329), Color("88816a"), 3.0)
		var shadow = PackedVector2Array()
		var radius = 108.0 - clampf(-body_height * .4, -5, 15)
		for i in range(32):
			var angle = TAU * i / 32.0
			shadow.append(Vector2(708 + cos(angle) * radius, 320 + sin(angle) * 9))
		draw_colored_polygon(shadow, Color(0, 0, 0, .24))

var model: RefCounted
var views: Array = []
var holders: Array = []
var floors: Array = []
var labels: Array = []
var samples: Array = []
var caption: Label
var capture_dir = "E:/GALUMU/docs/development/screenshots/v045/showcase"
var first_model_frame = true

func _initialize() -> void:
	call_deferred("run")

func make_scene() -> void:
	var page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var background = ColorRect.new()
	background.color = Color("15221e")
	background.size = Vector2(1440, 810)
	page.add_child(background)
	caption = UI.label(page, "马匹连续动作观察", Vector2(20, 10), 26, UI.GOLD)
	UI.label(page, "程序驱动 / 离线固定30FPS · 非真人试玩、非OS鼠标验收", Vector2(20, 777), 17, UI.MUTED)
	for index in range(2):
		var panel = UI.panel(page, Rect2(12, 68 + index * 353, 1416, 344))
		panel.clip_contents = true
		var floor_view = TrackFloor.new()
		floor_view.facing = 1 if index == 0 else -1
		panel.add_child(floor_view)
		floors.append(floor_view)
		var holder = Node2D.new()
		holder.scale = Vector2.ONE * .9
		panel.add_child(holder)
		holders.append(holder)
		var view = Rider.new()
		view.fighter = model.fighters[index]
		view.moving = true
		holder.add_child(view)
		view.set_process(false)
		views.append(view)
		labels.append(UI.label(panel, "", Vector2(16, 12), 18, UI.INK, 510))

func steady_frame(speed_value: float) -> void:
	for fighter in model.fighters:
		fighter.prev_x = fighter.x
		fighter.speed = speed_value
		fighter.x += speed_value * int(fighter.direction) * DT
		fighter.gait_phase += DT * TAU * Gait.frequency(speed_value)
		fighter.gait_moving = true
		fighter.motion_drive = 0.0
		fighter.guard = .43
		fighter.aim = -.08
		model._cache_pose(fighter)

func controlled_frame(held: bool) -> void:
	if first_model_frame:
		first_model_frame = false
		for fighter in model.fighters:
			fighter.speed = 0.0
			fighter.acceleration = 0.0
			fighter.accel_command = 0.0
			fighter.motion_drive = 0.0
			fighter.stamina = 100.0
			fighter.gait_phase = 0.0
			fighter.gait_moving = true
			model._cache_pose(fighter)
		# This is an explicit new study segment, equivalent to the match's
		# stationary pre-charge interval. Clear previous planted/swing state.
		for view in views:
			view.moving = false
			view._process(0.0)
			view.moving = true
	for index in range(2):
		model.set_controls(index, -.08, 0.0, held, DT, .43)
	model.step(DT)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var state = root.get_node_or_null("GameState")
	if state == null or not state.save_path.contains("qa_"):
		push_error("Motion showcase requires -- --test-profile")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Motion showcase requires an actual rendering display")
		quit(1)
		return
	if FileAccess.file_exists(capture_dir + "/report.json"):
		push_error("Choose a fresh --capture-dir to preserve previous evidence")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280, 720)
	model = Model.new("arena", {"stability": 1.0}, {"stability": 1.0}, 4501)
	model.phase = "charge"
	model.fighters[0].x = -50000.0
	model.fighters[1].x = 50000.0
	for fighter in model.fighters:
		fighter.acted = true
		fighter.lane_y = 0.0
	make_scene()
	for frame in range(TOTAL_FRAMES):
		await process_frame
		var stage_name = ""
		if frame < 192:
			var stage = mini(frame / 48, 3)
			steady_frame([110.0, 210.0, 340.0, 480.0][stage])
			stage_name = "四档恒速观察 · " + Gait.NAMES[stage]
		else:
			var held = frame >= 207 and frame < 297
			controlled_frame(held)
			stage_name = "从静止起步" if frame < 207 else ("持续催马加速" if held else "松手减速回巡航")
		caption.text = "马匹连续动作观察 · " + stage_name
		var row = {"frame": frame, "seconds": frame * DT, "stage": stage_name, "fighters": []}
		for index in range(2):
			var fighter = model.fighters[index]
			var view = views[index]
			view.position = Vector2(fighter.x, 0)
			view._process(DT)
			holders[index].position = Vector2(708 - fighter.x * .9, 302)
			var pose = Model.gait_pose(fighter)
			floors[index].travel = fighter.x
			floors[index].body_height = pose.offset.y
			floors[index].queue_redraw()
			labels[index].text = ("右向骑手" if index == 0 else "左向骑手") + " · %s · 速度 %.0f\n马身高度 %.1f / 俯仰 %.1f°" % [Gait.NAMES[Gait.gait_index(fighter.speed)], fighter.speed, -pose.offset.y, rad_to_deg(pose.pitch)]
			var feet: Array = []
			for leg in view.leg_poses:
				feet.append({"contact": leg.contact, "foot": [leg.foot.x, leg.foot.y]})
			row.fighters.append({"facing": fighter.direction, "speed": fighter.speed, "boost": fighter.boost, "phase": fighter.gait_phase, "body_y": pose.offset.y, "pitch": pose.pitch, "feet": feet})
		if frame % 5 == 0:
			samples.append(row)
		if frame in CAPTURE_FRAMES:
			await RenderingServer.frame_post_draw
			var code = root.get_texture().get_image().save_png(capture_dir + "/frame_%03d.png" % frame)
			print("MOTION_SHOWCASE_CAPTURE ", frame, " ", code)
	var report = {"scope": "Continuous engine rendering, four steady gaits then model-driven start/hold/release; both facings; fixed following framing. Not OS input, human play or real-time performance proof.", "fps": 30, "frames": TOTAL_FRAMES, "samples": samples}
	var file = FileAccess.open(capture_dir + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MOTION_SHOWCASE_V045_COMPLETE")
	quit()
