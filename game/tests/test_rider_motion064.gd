extends SceneTree
## RIDER-064 render study of the mounted rider: walk/trot/gallop strides and a
## lean forward -> back -> forward transition, real RiderView and real model
## controls, large scale so joints are inspectable. Writes contact sheets and
## per-frame joint traces. Not OS input or a playtest.
## Run with --test-profile through Start-MemoryBound -IsolatedDesktop.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const CELL = Vector2i(460,560)
const SCALE = 2.1
var folder = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rider-report="): folder = arg.trim_prefix("--rider-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var trace = FileAccess.open(folder+"/trace.jsonl",FileAccess.WRITE)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	Engine.max_fps = 30
	for facing in [1,-1]:
		var model = Model.new("arena",{"stability":1.0},{"stability":1.0},5001)
		model.phase = "charge"
		model.fighters[0].x = -50000.0
		model.fighters[1].x = 50000.0
		var index = 0 if facing==1 else 1
		var fighter: Dictionary = model.fighters[index]
		fighter.lane_y = 0.0
		fighter.gait_moving = true
		var mount = Node2D.new()
		root.add_child(mount)
		var rider = Rider.new()
		rider.fighter = fighter
		rider.moving = true
		rider.scale = Vector2.ONE*SCALE
		mount.add_child(rider)
		rider.set_process(false)
		var frames: Array[Image] = []
		var dt = 1.0/60.0
		# Steady strides: 8 frames across one stride per gait.
		for speed in [110.0,210.0,480.0]:
			fighter.speed = speed
			fighter.gait_phase = 0.0
			rider.cycles_initialized = false
			rider.planted_feet.fill(INF)
			var period = 1.0/Gait.frequency(speed)
			var ticks = int(period*60.0)
			for warm in range(ticks):
				_advance(fighter,rider,mount,speed,dt)
			for tick in range(ticks):
				_advance(fighter,rider,mount,speed,dt)
				_trace(trace,"stride%d"%int(speed),tick,fighter,rider)
				if tick%maxi(1,ticks/8)==0 and frames.size()%8<8:
					frames.append(await _capture(rider))
		# Lean transition at gallop through the real control spring.
		fighter.speed = 480.0
		for tick in range(150):
			var seconds = tick*dt
			var lean = 1.0 if seconds<.8 else (-1.0 if seconds<1.8 else 1.0)
			model.set_controls(index,-.08,lean,true,dt,.43)
			fighter.speed = 480.0
			Model.advance_reaction(fighter,dt)
			_advance(fighter,rider,mount,480.0,dt)
			_trace(trace,"lean",tick,fighter,rider)
			if tick%10==0:
				frames.append(await _capture(rider))
		var columns = 8
		var rows = int(ceil(frames.size()/float(columns)))
		var sheet = Image.create_empty((CELL.x+6)*columns,(CELL.y+6)*rows,false,Image.FORMAT_RGBA8)
		sheet.fill(Color.BLACK)
		for i in range(frames.size()):
			sheet.blit_rect(frames[i],Rect2i(Vector2i.ZERO,CELL),Vector2i((i%columns)*(CELL.x+6),(i/columns)*(CELL.y+6)))
		sheet.save_png(folder+"/rider%d.png"%facing)
		mount.queue_free()
		await process_frame
	trace.close()
	print("RIDER064_RENDER_DONE "+folder)
	quit()

func _advance(fighter: Dictionary, rider, mount: Node2D, speed: float, dt: float) -> void:
	fighter.speed = speed
	fighter.gait_phase += TAU*Gait.frequency(speed)*dt
	fighter.x += speed*int(fighter.direction)*dt
	rider.position = Vector2(fighter.x,0)
	mount.position = Vector2(720-fighter.x,760)
	rider._process(dt)

func _capture(rider) -> Image:
	rider.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	# Rider origin sits ~168 units above the ground (x2.1 scale): helmet top
	# near y=105, stirrups near y=580 on this 760 ground line.
	return root.get_texture().get_image().get_region(Rect2i(720-CELL.x/2,70,CELL.x,CELL.y))

static func _trace(file: FileAccess, label: String, tick: int, fighter: Dictionary, rider) -> void:
	var arms = Rider.arm_pose(fighter)
	var seat = Rider.seated_leg_pose(fighter)
	file.store_line(JSON.stringify({"label":label,"tick":tick,"lean":fighter.lean,"pose_angle":Model.pose_angle(fighter),
		"origin":[Model.rider_origin(fighter).x-float(fighter.x),Model.rider_origin(fighter).y],"head":[Model.head_position(fighter).x-float(fighter.x),Model.head_position(fighter).y],
		"hand":[Model.hand_position(fighter).x-float(fighter.x),Model.hand_position(fighter).y],"near_knee":[seat.near.knee.x,seat.near.knee.y],"near_ankle":[seat.near.ankle.x,seat.near.ankle.y]}))
