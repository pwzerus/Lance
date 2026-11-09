extends SceneTree
## RIDER-065 stride study: 16 frames across one stride for walk, trot,
## canter and gallop, real RiderView with world-locked hooves, one horse,
## facing right. Inspect hoof paths for the "kick back" the user reported.
## Run with --test-profile through Start-MemoryBound -IsolatedDesktop.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const CELL = Vector2i(520,340)
var folder = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stride-report="): folder = arg.trim_prefix("--stride-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	Engine.max_fps = 30
	var model = Model.new("arena",{"stability":1.0},{"stability":1.0},5001)
	var fighter: Dictionary = model.fighters[0]
	fighter.lane_y = 0.0
	fighter.gait_moving = true
	var mount = Node2D.new()
	root.add_child(mount)
	var rider = Rider.new()
	rider.fighter = fighter
	rider.moving = true
	rider.scale = Vector2.ONE*1.1
	mount.add_child(rider)
	rider.set_process(false)
	var dt = 1.0/120.0
	for speed in [110.0,210.0,340.0,480.0]:
		var frames: Array[Image] = []
		fighter.speed = speed
		fighter.gait_phase = 0.0
		rider.cycles_initialized = false
		rider.planted_feet.fill(INF)
		var period = 1.0/Gait.frequency(speed)
		var ticks = int(period*120.0)
		for warm in range(ticks*2):
			_advance(fighter,rider,mount,speed,dt)
		for k in range(16):
			var target = int(k*ticks/16.0)
			var steps = target-(0 if k==0 else int((k-1)*ticks/16.0))
			for s in range(steps):
				_advance(fighter,rider,mount,speed,dt)
			rider.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			frames.append(root.get_texture().get_image().get_region(Rect2i(720-CELL.x/2,760-CELL.y+30,CELL.x,CELL.y)))
		var sheet = Image.create_empty((CELL.x+4)*4,(CELL.y+4)*4,false,Image.FORMAT_RGBA8)
		sheet.fill(Color.BLACK)
		for i in range(frames.size()):
			sheet.blit_rect(frames[i],Rect2i(Vector2i.ZERO,CELL),Vector2i((i%4)*(CELL.x+4),(i/4)*(CELL.y+4)))
		sheet.save_png(folder+"/stride%d.png"%int(speed))
	print("STRIDE065_DONE "+folder)
	quit()

func _advance(fighter: Dictionary, rider, mount: Node2D, speed: float, dt: float) -> void:
	fighter.speed = speed
	fighter.gait_phase += TAU*Gait.frequency(speed)*dt
	fighter.x += speed*dt
	rider.position = Vector2(fighter.x,0)
	mount.position = Vector2(720-fighter.x,760)
	rider._process(dt)
