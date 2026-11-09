extends SceneTree
## ART-063 render study: repainted coats, coat filtering, far-leg crop and
## joint seams on the real RiderView, moving continuously (world-locked
## hooves), both facings. Writes contact sheets; human review of the images
## is the actual art check. Not OS input, not a playtest.
## Run with --test-profile through Start-MemoryBound -IsolatedDesktop.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const IDS = ["horse_bay","horse_grey","horse_chestnut","horse_courser"]
const CELL = Vector2i(600,420)
var folder = ""
var report: FileAccess

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-report="): folder = arg.trim_prefix("--art-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	if DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	report = FileAccess.open(folder+"/report.jsonl",FileAccess.WRITE)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	Engine.max_fps = 30
	var catalogue = load("res://scripts/core/catalogue.gd")
	var items = catalogue.load_items()
	# Solid magenta coat for the far legs only: anything magenta that is not
	# a far leg proper is a seam/sliver bug.
	var debug_image = Image.create_empty(64,64,false,Image.FORMAT_RGBA8)
	debug_image.fill(Color(1,0,1,1))
	var debug_texture = ImageTexture.create_from_image(debug_image)
	for row in range(IDS.size()):
		for facing in [1,-1]:
			var stats = catalogue.stats(items,{"horse":IDS[row]})
			var model = Model.new("arena",stats,stats)
			var fighter: Dictionary = model.fighters[0 if facing==1 else 1]
			fighter.x = 0.0
			fighter.lane_y = 0.0
			fighter.gait_moving = true
			var mount = Node2D.new()
			root.add_child(mount)
			var rider = Rider.new()
			rider.fighter = fighter
			rider.moving = true
			rider.scale = Vector2.ONE*1.3
			mount.add_child(rider)
			rider.set_process(false)
			var frames: Array[Image] = []
			var debug_frames: Array[Image] = []
			for pass_index in range(2):
				var speeds = [480.0,210.0]
				for speed in speeds:
					fighter.speed = speed
					fighter.gait_phase = 0.0
					rider.cycles_initialized = false
					rider.planted_feet.fill(INF)
					var world_x = 0.0
					var dt = 1.0/60.0
					var period = 1.0/Gait.frequency(speed)
					var ticks = int(period*60.0*2.0)
					var captures = 6 if speed==480.0 else 4
					for tick in range(ticks):
						fighter.motion_drive = 0.0
						fighter.gait_phase += TAU*Gait.frequency(speed)*dt
						world_x += speed*dt*facing
						fighter.x = world_x
						rider.position = Vector2(world_x,0)
						mount.position = Vector2(720-world_x,640)
						rider._process(dt)
						if pass_index==1 and rider.far_fore_skin!=null:
							rider.far_fore_skin.coat = debug_texture
							rider.far_hind_skin.coat = debug_texture
						var capture_every = maxi(1,int(ticks/2/captures))
						if tick>=ticks/2 and (tick-ticks/2)%capture_every==0 and (tick-ticks/2)/capture_every<captures:
							rider.queue_redraw()
							await process_frame
							await RenderingServer.frame_post_draw
							var frame = root.get_texture().get_image().get_region(Rect2i(720-CELL.x/2,640-CELL.y+70,CELL.x,CELL.y))
							if pass_index==0:
								frames.append(frame)
							else:
								debug_frames.append(frame)
								# Count magenta pixels per frame for the report.
								report.store_line(JSON.stringify({"coat":stats.horse_coat,"facing":facing,"speed":speed,"tick":tick,"far_leg_pixels":_count_magenta(frame)}))
				if pass_index==1:
					rider.far_fore_skin.set_coat(str(stats.horse_coat))
					rider.far_hind_skin.set_coat(str(stats.horse_coat))
			var sheet = Image.create_empty(CELL.x*2+8,(CELL.y+8)*frames.size(),false,Image.FORMAT_RGBA8)
			sheet.fill(Color.BLACK)
			for i in range(frames.size()):
				sheet.blit_rect(frames[i],Rect2i(Vector2i.ZERO,CELL),Vector2i(0,i*(CELL.y+8)))
				if i<debug_frames.size():
					sheet.blit_rect(debug_frames[i],Rect2i(Vector2i.ZERO,CELL),Vector2i(CELL.x+8,i*(CELL.y+8)))
			var path = folder+"/%s-%d.png" % [stats.horse_coat,facing]
			if sheet.save_png(path)!=OK:
				quit(1)
				return
			report.store_line(JSON.stringify({"sheet":path,"coat":stats.horse_coat,"facing":facing,"frames":frames.size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}))
			report.flush()
			mount.queue_free()
			await process_frame
	report.close()
	print("ART063_RENDER_DONE "+folder)
	quit()

static func _count_magenta(image: Image) -> int:
	var data = image.get_data()
	var count = 0
	for i in range(0,data.size(),4):
		# Far legs are drawn with a .25-.29 darker tint: magenta becomes ~181/0/181.
		if data[i]>150 and data[i+1]<40 and data[i+2]>150:
			count += 1
	return count
