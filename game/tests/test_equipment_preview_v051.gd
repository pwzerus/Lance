extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
var output = "E:/GALUMU/docs/development/screenshots/v051/sample01.png"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args = OS.get_cmdline_user_args()
	var helmet = "eng_helmet_5"
	if "--helmet" in args:
		helmet = args[args.find("--helmet")+1]
	if "--capture" in args:
		output = args[args.find("--capture")+1]
	root.size = Vector2i(1440,810)
	var scene = Node2D.new()
	root.add_child(scene)
	var background = ColorRect.new()
	background.color = Color("303c37")
	background.size = Vector2(1440,810)
	scene.add_child(background)
	var stats = {"armor_art":"eng_armor_5","helmet_art":"eng_helmet_5","armor_tier":4,"helmet_tier":4,"lance_quality":5,"lance_era":4,"lance_type":"stout","lance_region":"英格兰","lance_color":"d0ad64","leg_decoration":1}
	stats.helmet_art = helmet
	for i in range(2):
		var model = Model.new("arena",stats,stats,44)
		var view = Rider.new()
		view.fighter = model.fighters[i]
		view.fighter.x = 0
		view.fighter.lane_y = 0
		view.fighter.aim = -.12
		view.position = Vector2(350+i*740,580)
		view.scale = Vector2.ONE*1.6
		scene.add_child(view)
		UI.label(background,helmet+" · " + ("向右" if i==0 else "向左"),Vector2(80+i*740,40),24,Color.WHITE)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error = root.get_texture().get_image().save_png(output)
	print("V051 SAMPLE ",error)
	quit(int(error))
