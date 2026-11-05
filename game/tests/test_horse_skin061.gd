extends SceneTree
const Gait=preload("res://scripts/visual/horse_gait.gd")
const CoatSkin=preload("res://scripts/visual/horse_skin.gd")
var folder=""

class Horse extends Node2D:
	var body: Dictionary
	var legs: Array=[]
	var main_skin=CoatSkin.new()
	var hind_skin=CoatSkin.new("hind")
	var fore_skin=CoatSkin.new("fore")
	func _draw() -> void:
		if legs.is_empty(): return
		draw_line(Vector2(-250,12),Vector2(250,12),Color.GRAY,1)
		hind_skin.update(body,legs[0],legs[2])
		fore_skin.update(body,legs[0],legs[2])
		main_skin.update(body,legs[1],legs[3])
		hind_skin.draw(self,Color(.65,.65,.65))
		fore_skin.draw(self,Color(.65,.65,.65))
		main_skin.draw(self,Color.WHITE)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--skin-report="): folder=arg.trim_prefix("--skin-report=")
	if folder.is_empty() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2)
		return
	if DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(640,480)
	root.content_scale_size=Vector2i(640,480)
	RenderingServer.set_default_clear_color(Color("596365"))
	var horse=Horse.new()
	horse.material=ShaderMaterial.new()
	horse.material.shader=load("res://scripts/visual/mounted_pixel.gdshader")
	horse.position=Vector2(320,380)
	root.add_child(horse)
	for speed in [100.0,210.0,320.0,480.0]:
		for frame in range(16):
			var phase=frame*TAU/16
			horse.body=Gait.body(phase,speed,true)
			horse.legs.clear()
			for i in range(4): horse.legs.append(Gait.leg(i,phase,speed,true))
			horse.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/speed%d-%02d.png"%[speed,frame])
	print("SKIN061_COMPLETE "+folder)
	quit()
