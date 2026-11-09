extends SceneTree
## EQUIP-066 render study on the real RiderView and main scene (isolated
## desktop, QA profile): caparison styles x arms at a gallop frame, a gallop
## strip under a caparison (cloth must bend with the body and legs), a close
## shield crop at battle scale, and armoury captures for crest, shield,
## caparison and armour (weights, load summary). Human review of the images
## is the actual check. Not OS input, not a playtest.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Heraldry = preload("res://scripts/visual/heraldry.gd")
const CELL = Vector2i(560,420)
var folder = ""
var items: Array = []
var catalogue

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--equip-report="): folder = arg.trim_prefix("--equip-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	catalogue = load("res://scripts/core/catalogue.gd")
	items = catalogue.load_items()
	# 1. Styles x arms at one gallop frame.
	var cells: Array[Image] = []
	for style in ["caparison_linen","caparison_wool","caparison_velvet"]:
		for design in Heraldry.ARMS:
			var frames = await _render(style,"crest_"+design,1,480.0,1)
			cells.append(frames[0])
	_save_sheet(cells,4,"styles.png")
	# 2. Gallop and trot strips under the wool caparison, both facings.
	var strip: Array[Image] = []
	for facing in [1,-1]:
		strip.append_array(await _render("caparison_wool","crest_chevron",facing,480.0,6))
	_save_sheet(strip,6,"gallop-wool.png")
	var trot: Array[Image] = await _render("caparison_velvet","crest_cross",1,210.0,6)
	_save_sheet(trot,6,"trot-velvet.png")
	# 3. Armoury captures.
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	for _i in range(3):
		await process_frame
	for slot in ["crest","shield","caparison","armor"]:
		main.selected_slot = slot
		main.selected_era = -1
		main.selected_region = 1 if slot in ["shield","armor"] else 0
		main.selected_quality = 0
		main.selected_item = {}
		for item in items:
			if item.slot==slot and (slot=="crest" and item.id=="crest_chevron" or slot=="caparison" and item.id=="caparison_wool" or slot in ["shield","armor"] and str(item.get("region",""))=="英格兰" and int(item.get("quality",-1))==5):
				main.selected_item = item
		main.show_armory()
		await _capture(folder+"/armory_%s.png"%slot)
	main.queue_free()
	await process_frame
	print("EQUIP066_DONE "+folder)
	quit()

func _render(caparison: String, crest: String, facing: int, speed: float, captures: int) -> Array[Image]:
	var stats = catalogue.stats(items,{"horse":"horse_bay","armor":"eng_armor_3","helmet":"eng_helmet_3","shield":"eng_shield_4","lance":"eng_lance_long_3","crest":crest,"caparison":caparison})
	var model = Model.new("arena",stats,stats)
	var fighter: Dictionary = model.fighters[0 if facing==1 else 1]
	fighter.x = 0.0
	fighter.lane_y = 0.0
	fighter.gait_moving = true
	fighter.speed = speed
	var mount = Node2D.new()
	root.add_child(mount)
	var rider = Rider.new()
	rider.fighter = fighter
	rider.moving = true
	rider.scale = Vector2.ONE*1.25
	mount.add_child(rider)
	rider.set_process(false)
	var frames: Array[Image] = []
	var dt = 1.0/60.0
	var period = 1.0/Gait.frequency(speed)
	var ticks = int(period*60.0*2.0)
	var every = maxi(1,int(ticks/2/captures))
	var world_x = 0.0
	for tick in range(ticks):
		fighter.gait_phase += TAU*Gait.frequency(speed)*dt
		world_x += speed*dt*facing
		fighter.x = world_x
		rider.position = Vector2(world_x,0)
		mount.position = Vector2(720-world_x,640)
		rider._process(dt)
		if tick>=ticks/2 and (tick-ticks/2)%every==0 and frames.size()<captures:
			rider.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			frames.append(root.get_texture().get_image().get_region(Rect2i(720-CELL.x/2,640-CELL.y+70,CELL.x,CELL.y)))
	mount.queue_free()
	await process_frame
	return frames

func _save_sheet(cells: Array[Image], columns: int, name: String) -> void:
	var rows = ceili(cells.size()/float(columns))
	var sheet = Image.create_empty((CELL.x+6)*columns,(CELL.y+6)*rows,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in range(cells.size()):
		sheet.blit_rect(cells[i],Rect2i(Vector2i.ZERO,CELL),Vector2i((i%columns)*(CELL.x+6),(i/columns)*(CELL.y+6)))
	sheet.save_png(folder+"/"+name)

func _capture(path: String) -> void:
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
