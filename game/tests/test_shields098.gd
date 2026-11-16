extends SceneTree
## Item-driven construction study. Inspect rendered images; not a feel test.
const Catalogue=preload("res://scripts/core/catalogue.gd")
const ShieldArt=preload("res://scripts/visual/shield_art.gd")
const Status=preload("res://scripts/ui/combat_status098.gd")
var folder=""

class Board extends Node2D:
	var items: Array=[]
	func _draw() -> void:
		for row in range(4):
			var region=["eng","fr","de","it"][row]
			for q in range(6):
				var item=Catalogue.find(items,region+"_shield_"+str(q))
				var stats=item.stats.duplicate(true)
				stats.heraldry=stats.get("shield_heraldry","bend")
				var at=Vector2(130+q*235,100+row*190)
				ShieldArt.draw(self,stats,at,false)
				ShieldArt.draw(self,stats,at+Vector2(-65,0),true,Color.WHITE,0,.65,-1,.25)
				ShieldArt.draw(self,stats,at+Vector2(65,0),true,Color.WHITE,0,.65,1)
				draw_string(Status.FONT,at+Vector2(-105,77),item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e9dfc5"))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): folder=arg.trim_prefix("--report=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,810)
	root.content_scale_size=Vector2i(1440,810)
	RenderingServer.set_default_clear_color(Color("20362f"))
	var board=Board.new()
	board.items=Catalogue.load_items()
	root.add_child(board)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/shield-construction.png")
	print("SHIELDS098_DONE "+folder)
	board.queue_free()
	await process_frame
	quit(0)
