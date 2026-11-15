extends SceneTree
## ART-090 render study (isolated desktop, QA profile):
##  1. riders.png  - kits at three on-screen scales (run-up .5, mid 1.0,
##                   contact 1.6): cloth armour in each arms, plate armour,
##                   great helm vs open helm, at a gallop frame.
##  2. lances.png  - every lance type x quality x period at battle scales.
##  3. hud_*.png   - real main scene, autopilot arena match wearing a great
##                   helm: helmet sight mask during the charge.
## Human review of the images is the check. Not OS input, not a playtest.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Lance = preload("res://scripts/visual/lance_art.gd")
var folder = ""
var items: Array = []
var catalogue

class LanceBoard extends Node2D:
	const Lance = preload("res://scripts/visual/lance_art.gd")
	var rows: Array = []
	var scale_factor = 1.0
	func _draw() -> void:
		for r in range(rows.size()):
			var stats: Dictionary = rows[r]
			draw_set_transform(Vector2(20,24+r*40)*1.0,0,Vector2.ONE*scale_factor)
			Lance.draw(self,stats,Vector2.ZERO,0,float(stats.get("reach",247)),false,0,"arena" if r%2==0 else "war")
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-report="): folder = arg.trim_prefix("--art-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	catalogue = load("res://scripts/core/catalogue.gd")
	items = catalogue.load_items()
	# 1. Riders.
	var kits = [
		{"armor":"eng_armor_3","helmet":"eng_helmet_1","crest":"crest_bend","lance":"eng_lance_long_3","shield":"eng_shield_3"},
		{"armor":"fr_armor_1","helmet":"fr_helmet_0","crest":"crest_chevron","lance":"fr_lance_light_2","shield":"fr_shield_2"},
		{"armor":"de_armor_1","helmet":"de_helmet_1","crest":"crest_cross","lance":"eng_lance_stout_4","shield":"eng_shield_4"},
		{"armor":"eng_armor_2","helmet":"eng_helmet_2","crest":"crest_diamond","lance":"eng_lance_long_5","shield":"eng_shield_5"},
		{"armor":"eng_armor_5","helmet":"eng_helmet_5","crest":"crest_bend","lance":"eng_lance_stout_5","shield":"eng_shield_5"},
		{"armor":"it_armor_4","helmet":"it_helmet_3","crest":"crest_chevron","lance":"fr_lance_light_0","shield":"fr_shield_0"}]
	var cells: Array[Image] = []
	for kit in kits:
		var equipped = {"horse":"horse_bay"}
		equipped.merge(kit,true)
		var stats = catalogue.stats(items,equipped)
		for zoom in [.5,1.0,1.6]:
			cells.append(await _render_rider(stats,zoom))
	_save_grid(cells,3,folder+"/riders.png")
	# 2. Lances.
	var rows: Array = []
	for type in ["light","standard","long","stout"]:
		for q in [0,2,3,5]:
			var era = [0,1,3,4][q/2 if q<5 else 3]
			var reach = {"light":237,"standard":247,"long":280,"stout":253}[type]
			rows.append({"lance_type":type,"lance_quality":q,"lance_era":era,"reach":reach,"heraldry":["bend","chevron","cross","diamond"][rows.size()%4]})
	for scale in [.6,1.2]:
		var board = LanceBoard.new()
		board.rows = rows
		board.scale_factor = scale
		root.add_child(board)
		for _i in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(0,0,1440,1080)).save_png(folder+"/lances_%d.png" % int(scale*10))
		board.queue_free()
		await process_frame
	# 3. HUD with a great helm.
	var state = root.get_node("GameState")
	for id in ["eng_helmet_1"]:
		if id not in state.profile.owned:
			state.profile.owned.append(id)
	state.profile.equipped.helmet = "eng_helmet_1"
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for _i in range(3):
		await process_frame
	main.smoke_mode = true
	main._start_match("arena",false)
	var shots = {300:"hud_charge_early.png",430:"hud_charge_late.png"}
	for frame in range(600):
		await process_frame
		if shots.has(frame):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+shots[frame])
	print("ART090_DONE "+folder)
	main.queue_free()
	await process_frame
	quit()

func _render_rider(stats: Dictionary, zoom: float) -> Image:
	var model = Model.new("arena",stats,stats)
	var fighter: Dictionary = model.fighters[0]
	fighter.x = 0.0
	fighter.lane_y = 0.0
	fighter.gait_moving = true
	fighter.speed = 480.0
	var mount = Node2D.new()
	root.add_child(mount)
	var rider = Rider.new()
	rider.fighter = fighter
	rider.moving = true
	rider.scale = Vector2.ONE*zoom
	mount.add_child(rider)
	rider.set_process(false)
	var dt = 1.0/60.0
	var world_x = 0.0
	for tick in range(24):
		fighter.gait_phase += TAU*Gait.frequency(480.0)*dt
		world_x += 480.0*dt
		fighter.x = world_x
		rider.position = Vector2(world_x,0)
		mount.position = Vector2(560-world_x*zoom,760)
		rider._process(dt)
	rider.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var size = Vector2i(roundi(480*maxf(zoom,.75)),roundi(420*maxf(zoom,.75)))
	var image = root.get_texture().get_image().get_region(Rect2i(560-size.x/2,760-size.y+int(60*zoom),size.x,size.y))
	mount.queue_free()
	await process_frame
	return image

func _save_grid(cells: Array[Image], columns: int, path: String) -> void:
	var cell_w = 0
	var cell_h = 0
	for cell in cells:
		cell_w = maxi(cell_w,cell.get_width())
		cell_h = maxi(cell_h,cell.get_height())
	var rows = ceili(cells.size()/float(columns))
	var sheet = Image.create_empty((cell_w+6)*columns,(cell_h+6)*rows,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in range(cells.size()):
		sheet.blit_rect(cells[i],Rect2i(Vector2i.ZERO,cells[i].get_size()),Vector2i((i%columns)*(cell_w+6),(i/columns)*(cell_h+6)))
	sheet.save_png(path)
