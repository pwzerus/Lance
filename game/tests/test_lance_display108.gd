extends SceneTree
## Actual catalogue, both modes/facings, intact and broken. PNGs require
## visual inspection; counting images is not an art-quality assertion.
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Lance=preload("res://scripts/visual/lance_art.gd")
const Family=preload("res://scripts/visual/heraldry.gd")
var folder=""
var failures=[]
class Board extends Node2D:
	var rows=[]
	var mode="arena"
	var zoom=1.0
	var broken=false
	func _draw()->void:
		for row in range(rows.size()):
			var item=rows[row]
			for facing in [1,-1]:
				var at=Vector2(90 if facing==1 else 910,34+row*42)
				draw_set_transform(at,0,Vector2(facing,1)*zoom)
				Lance.draw(self,item.stats,Vector2.ZERO,.02,float(item.stats.reach)*(.34 if broken else 1.0),broken,.45,mode,Lance.Layer.WHOLE,.8)
				draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font,Vector2(420,28+row*42),item.id,HORIZONTAL_ALIGNMENT_CENTER,160,11,Color("f4e6c6"))
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless" or not "qa_" in root.get_node("GameState").save_path:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1000,810);root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("34474a"))
	var items=Catalogue.load_items();var trace=[]
	for region in ["eng","fr","de","it"]:
		var rows=[]
		for kind in ["light","long","stout"]:
			for q in range(6):
				var id="%s_lance_%s_%d"%[region,kind,q]
				var item=Catalogue.find(items,id)
				if item.is_empty():failures.append("Missing lance "+id);continue
				var stats=Catalogue.stats(items,{"lance":id,"crest":"crest_fleur"})
				rows.append({"id":id,"stats":stats})
				if stats.lance_type!=kind or int(stats.lance_quality)!=q:failures.append("Wrong visual identity "+id)
		for mode in ["arena","war"]:
			for zoom in [.65,1.1]:
				for broken in [false,true]:
					var board=Board.new();board.rows=rows;board.mode=mode;board.zoom=zoom;board.broken=broken;root.add_child(board)
					await process_frame;await RenderingServer.frame_post_draw
					var name="%s-%s-%d-%s"%[region,mode,roundi(zoom*100),"broken" if broken else "whole"]
					if root.get_texture().get_image().save_png(folder+"/"+name+".png")!=OK:failures.append("Capture "+name)
					trace.append({"capture":name,"lances":rows.size(),"facings":2})
					board.queue_free();await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"trace":trace,"scope":"72 real catalogue lances; two modes, two directions, two scales, intact/broken. GPU decoration only, not collision or human readability acceptance."},"\t"))
	quit(0 if failures.is_empty() else 1)
