extends SceneTree
## FEEL-093 render study (isolated desktop, QA profile):
##  shields.png  - all 12 arms x shield quality 0/2/4/5, kite and heater, at
##                 armoury scale and battle scale.
##  riders.png   - mounted riders bearing new arms (surcoat, shield, caparison,
##                 lance) facing right and left at battle zoom.
## Human review of the images is the check. Not OS input, not a playtest.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const ShieldArt = preload("res://scripts/visual/shield_art.gd")
const Heraldry = preload("res://scripts/visual/heraldry.gd")
var folder = ""

class Board extends Node2D:
	const ShieldArt = preload("res://scripts/visual/shield_art.gd")
	const Heraldry = preload("res://scripts/visual/heraldry.gd")
	func _draw() -> void:
		var designs = Heraldry.ARMS.keys()
		for i in range(designs.size()):
			for q in range(4):
				var quality = [0,2,4,5][q]
				var shape = "heater" if q%2==0 else "kite"
				var stats = {"shield_shape":shape,"shield_quality":quality,"heraldry":designs[i]}
				ShieldArt.draw(self,stats,Vector2(60+i*114,80+q*140),false,Color.WHITE,0.0,1.1,1)
			# Battle scale (projected), facing right then left.
			ShieldArt.draw(self,{"shield_shape":"kite","shield_quality":2,"heraldry":designs[i]},Vector2(60+i*114,705),true,Color.WHITE,0.0,.45,1)
			ShieldArt.draw(self,{"shield_shape":"heater","shield_quality":4,"heraldry":designs[i]},Vector2(60+i*114,775),true,Color.WHITE,0.0,.45,-1)
			draw_string(ThemeDB.fallback_font,Vector2(10+i*114,640),str(Heraldry.ARMS[designs[i]].name),HORIZONTAL_ALIGNMENT_LEFT,-1,14)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shield-report="): folder = arg.trim_prefix("--shield-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,840)
	root.content_scale_size = Vector2i(1440,840)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	var board = Board.new()
	root.add_child(board)
	for _i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/shields.png")
	board.queue_free()
	await process_frame
	var catalogue = load("res://scripts/core/catalogue.gd")
	var items = catalogue.load_items()
	var cells: Array[Image] = []
	var kits = [["fr_armor_1","crest_quarterly","caparison_velvet"],["eng_armor_3","crest_chief","caparison_wool"],["de_armor_1","crest_fleur","caparison_linen"],["it_armor_1","crest_chequy","caparison_velvet"]]
	for kit in kits:
		for facing in [1,-1]:
			var stats = catalogue.stats(items,{"armor":kit[0],"helmet":"eng_helmet_3","crest":kit[1],"caparison":kit[2],"lance":"eng_lance_long_4","shield":"eng_shield_4","horse":"horse_bay"})
			cells.append(await _render(stats,facing))
	var cell = cells[0].get_size()
	var sheet = Image.create_empty((cell.x+6)*4,(cell.y+6)*2,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in range(cells.size()):
		sheet.blit_rect(cells[i],Rect2i(Vector2i.ZERO,cell),Vector2i((i/2)*(cell.x+6),(i%2)*(cell.y+6)))
	sheet.save_png(folder+"/riders.png")
	print("SHIELDS093_DONE "+folder)
	quit(0)

func _render(stats: Dictionary, facing: int) -> Image:
	var model = Model.new("arena",stats,stats)
	var fighter: Dictionary = model.fighters[0 if facing==1 else 1]
	fighter.x = 0.0
	fighter.lane_y = 0.0
	fighter.gait_moving = true
	fighter.speed = 420.0
	var mount = Node2D.new()
	root.add_child(mount)
	var rider = Rider.new()
	rider.fighter = fighter
	rider.moving = true
	rider.scale = Vector2.ONE*.9
	mount.add_child(rider)
	rider.set_process(false)
	var world_x = 0.0
	for tick in range(20):
		fighter.gait_phase += TAU*Gait.frequency(420.0)/60.0
		world_x += 420.0/60.0*facing
		fighter.x = world_x
		rider.position = Vector2(world_x,0)
		mount.position = Vector2(560-world_x*.9,700)
		rider._process(1.0/60.0)
	rider.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image().get_region(Rect2i(560-260,700-330,520,380))
	mount.queue_free()
	await process_frame
	return image
