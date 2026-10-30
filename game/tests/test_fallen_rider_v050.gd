extends SceneTree
## Deterministic visual fixture; no player input or fun verdict is implied.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Fallen = preload("res://scripts/visual/fallen_rider.gd")
var failures: Array[String] = []
var report_path = "E:/GALUMU/docs/development/logs/v050/fall-01.json"
var capture_dir = "E:/GALUMU/docs/development/screenshots/v050/fall01"
var cases: Array = []
var actors: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): report_path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var back = ColorRect.new()
	back.color = Color("24382f")
	back.size = Vector2(1440,900)
	root.add_child(back)
	var model = Model.new()
	for index in range(6):
		var stage = Node2D.new()
		stage.position = Vector2(240+(index%3)*480,365+(index/3)*430)
		stage.scale = Vector2.ONE*.78
		root.add_child(stage)
		var floor_line = Line2D.new()
		floor_line.points = PackedVector2Array([Vector2(-230,12),Vector2(230,12)])
		floor_line.width = 2
		floor_line.default_color = Color("b49e68")
		stage.add_child(floor_line)
		var ground = StaticBody2D.new()
		ground.position.y = 22.0
		ground.collision_layer = 48
		var collider = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(640,20)
		collider.shape = shape
		ground.add_child(collider)
		stage.add_child(ground)
		var fighter: Dictionary = model.fighters[index/3].duplicate(true)
		fighter.x = 0.0
		fighter.lane_y = 0.0
		fighter.speed = 460.0
		fighter.direction = 1 if index<3 else -1
		fighter.lean = -.25 if index%3==0 else .2
		fighter.stats.helmet_tier = 0 if index%3==0 else 3
		fighter.gait_moving = true
		fighter.gait_phase = .6
		fighter.broken = index%2==0
		var zone = ["head","body","flank"][index%3]
		var label = Label.new()
		label.text = "%s / facing %d" % [zone,fighter.direction]
		label.position = Vector2(-210,-345)
		stage.add_child(label)
		var original = Rider.arm_pose(fighter)
		var seated = Rider.seated_leg_pose(fighter)
		var fallen = Fallen.new()
		stage.add_child(fallen)
		fallen.setup(fighter,{"zone":zone,"impulse":105.0,"direction":-int(fighter.direction)})
		fallen.set_process(false)
		for side in ["left","right"]:
			for joint in ["shoulder","elbow","hand"]:
				check((fallen.position+fallen.visual.detached_pose[side][joint]).distance_to(original[side][joint])<.001,"First fallen frame preserves mounted arm joints")
		for side in ["near","far"]:
			for joint in ["hip","knee","ankle","foot"]:
				check((fallen.position+fallen.visual.detached_legs[side][joint]*Vector2(fighter.direction,1)).distance_to(seated[side][joint]*Vector2(fighter.direction,1))<.001,"First fallen frame preserves mounted straddling legs")
		check(fallen.visual.fighter.stats==fighter.stats,"Fall retains armor, heraldry and face stats")
		actors.append(fallen)
	await process_frame
	for frame in range(181):
		if frame in [0,6,18,36,60,105,180]:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture_dir+"/frame_%03d.png"%frame)==OK,"Fall frame saves")
		for actor in actors:
			var pose: Dictionary = actor.visual.detached_pose
			for side in ["left","right"]:
				var arm: Dictionary = pose[side]
				var original: Dictionary = actor.initial_pose[side]
				check(absf(arm.shoulder.distance_to(arm.elbow)-original.shoulder.distance_to(original.elbow))<.001,"Upper arm length remains attached throughout fall")
				check(absf(arm.elbow.distance_to(arm.hand)-original.elbow.distance_to(original.hand))<.001,"Forearm length remains attached throughout fall")
			check(actor.position.is_finite() and is_finite(actor.rotation),"Fall remains finite")
			check(actor.position.y+actor.lowest_body_point()<=actor.ground_y+.01,"Body remains above its own lane floor")
			actor.advance(1.0/60.0)
		await process_frame
	for actor in actors:
		check(actor.settled and actor.grounded,"All authored zone reactions land and settle within three seconds")
		cases.append({"zone":actor.zone,"direction":actor.fighter.direction,"age":actor.age,"position":str(actor.position),"rotation":actor.rotation,"settled":actor.settled})
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"cases":cases,"captures":capture_dir,"evidence":"scripted articulated fall + rendered frames"},"\t"))
	file.close()
	print("FALL_V050 ",JSON.stringify({"failures":failures,"cases":cases.size()}))
	quit(0 if failures.is_empty() else 1)
