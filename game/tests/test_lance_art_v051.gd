extends SceneTree
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Lance = preload("res://scripts/visual/lance_art.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
class Weapon extends Node2D:
	const Drawing = preload("res://scripts/visual/lance_art.gd")
	var stats: Dictionary
	var length = 247.0
	func _draw() -> void:
		Drawing.draw(self,stats,Vector2.ZERO,0,length,false,0,"arena")
		Drawing.draw(self,stats,Vector2(0,33),0,length,false,.8,"war")
		Drawing.draw(self,stats,Vector2(0,62),0,66,true,0,"arena")
		var remainder = length-66.0
		var first = remainder*.56
		draw_set_transform(Vector2(66+first*.5+5,62))
		Drawing.draw_fragment(self,stats,66,first,length,false,"arena")
		draw_set_transform(Vector2(66+first+remainder*.44*.5+10,62))
		Drawing.draw_fragment(self,stats,66+first,remainder*.44,length,true,"arena")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var out = "E:/GALUMU/docs/development/screenshots/v051/lances01"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): out=arg.trim_prefix("--captures=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440,810)
	var items = Catalogue.load_items()
	var errors: Array[String] = []
	for country in ["eng","fr","de","it"]:
		var page = Control.new()
		page.theme = UI.theme()
		root.add_child(page)
		var bg = ColorRect.new()
		bg.color = Color("24342d")
		bg.size = Vector2(1440,810)
		page.add_child(bg)
		for q in range(6):
			for kind in ["light","stout","long"]:
				var col = ["light","stout","long"].find(kind)
				var item = Catalogue.find(items,"%s_lance_%s_%d" % [country,kind,q])
				if item.is_empty():
					errors.append("Missing weapon")
					continue
				var reach = float(item.stats.reach)
				for angle in [-.68,0.0,.58]:
					var hand = Vector2(32,-76)
					var tip = hand+Vector2(cos(angle),sin(angle))*reach
					if Lance.surface(hand,angle,reach,0,reach,false,1).distance_to(tip)>.001:
						errors.append("Recoil moved the actual weapon tip: "+item.id)
				var origin = Vector2(col*480,q*135)
				UI.label(page,item.name,origin+Vector2(18,5),14,UI.GOLD,440)
				var weapon = Weapon.new()
				weapon.stats = item.stats
				weapon.length = reach
				weapon.position = origin+Vector2(90,45)
				page.add_child(weapon)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(out.path_join(country+".png"))!=OK:
			errors.append("Screenshot failed")
		page.queue_free()
		await process_frame
	print("LANCE_ART_V051 ",errors.is_empty()," errors=",errors)
	quit(0 if errors.is_empty() else 1)
