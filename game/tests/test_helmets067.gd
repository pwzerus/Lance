extends SceneTree
## EQUIP-067 helmet fit sheet: every historical helmet on the real RiderView,
## mounted and standing still, cropped to head and shoulders. Human review of
## the sheet is the check (user: some helmets look fat).
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const CELL = Vector2i(220,240)
var folder = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--helmet-report="): folder = arg.trim_prefix("--helmet-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	var catalogue = load("res://scripts/core/catalogue.gd")
	var items = catalogue.load_items()
	var cells: Array[Image] = []
	for region in ["eng","fr","de","it"]:
		for q in range(6):
			var stats = catalogue.stats(items,{"horse":"horse_bay","armor":"%s_armor_%d"%[region,q],"helmet":"%s_helmet_%d"%[region,q]})
			var model = Model.new("arena",stats,stats)
			var fighter: Dictionary = model.fighters[0]
			fighter.x = 0.0
			fighter.lane_y = 0.0
			var mount = Node2D.new()
			mount.position = Vector2(720,700)
			root.add_child(mount)
			var rider = Rider.new()
			rider.fighter = fighter
			rider.scale = Vector2.ONE*1.6
			mount.add_child(rider)
			rider.set_process(false)
			rider._process(1.0/60.0)
			rider.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			cells.append(root.get_texture().get_image().get_region(Rect2i(720-CELL.x/2-20,700-470,CELL.x,CELL.y)))
			mount.queue_free()
			await process_frame
	var sheet = Image.create_empty((CELL.x+4)*6,(CELL.y+4)*4,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in range(cells.size()):
		sheet.blit_rect(cells[i],Rect2i(Vector2i.ZERO,CELL),Vector2i((i%6)*(CELL.x+4),(i/6)*(CELL.y+4)))
	sheet.save_png(folder+"/helmets.png")
	print("HELMETS067_DONE "+folder)
	quit()
