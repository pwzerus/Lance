extends SceneTree
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
var folder = ""
var facing = 1
var frames = false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--facing="): facing=int(arg.trim_prefix("--facing="))
		if arg=="--frames": frames=true
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(768,512)
	root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("4b5859"))
	var stats=Catalogue.stats(Catalogue.load_items(),{"horse":"horse_bay","armor":"eng_armor_3","helmet":"eng_helmet_3"})
	var model=Model.new("arena",stats,stats,7501)
	model.phase="charge"
	model.fighters[0].x=-50000.0
	model.fighters[1].x=50000.0
	var f: Dictionary=model.fighters[0 if facing==1 else 1]
	var mount=Node2D.new()
	root.add_child(mount)
	var rider=Rider.new()
	rider.fighter=f
	rider.moving=true
	mount.add_child(rider)
	rider.set_process(false)
	var trace: Array=[]
	var worst_step=0.0
	var worst_slide=0.0
	var last: Array=[]
	var last_contact: Array=[]
	var failures: Array=[]
	for tick in range(540):
		var t=tick/60.0
		f.boost=(t>=1.0 and t<4.0) or (t>=6.0 and t<7.0)
		model.step(1.0/60.0)
		rider.position=Vector2(f.x,440)
		mount.position.x=384-float(f.x)
		rider._process(1.0/60.0)
		var feet: Array=[]
		var contacts: Array=[]
		for i in range(4):
			var p: Dictionary=rider.leg_poses[i]
			var world=Vector2(float(f.x)+p.foot.x*facing,p.foot.y)
			if not world.is_finite(): failures.append("nonfinite hoof")
			if not last.is_empty():
				worst_step=maxf(worst_step,world.distance_to(last[i]))
				if p.contact and last_contact[i]: worst_slide=maxf(worst_slide,world.distance_to(last[i]))
			feet.append(world)
			contacts.append(p.contact)
		trace.append({"time":t,"speed":f.speed,"boost":f.boost,"feet":feet,"contacts":contacts})
		last=feet; last_contact=contacts
		if frames and tick%3==0:
			rider.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/frame-%04d.png"%(tick/3))
	if worst_slide>.1: failures.append("Planted hoof slides in world space")
	if worst_step>24.0: failures.append("Hoof moves more than 24 units per 60Hz step")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"worst_step":worst_step,"worst_slide":worst_slide,"trace":trace},"\t"))
	rider.queue_free(); mount.queue_free()
	await process_frame
	print("TRANSITION075 ",worst_step," slide=",worst_slide," ",failures)
	quit(0 if failures.is_empty() else 1)
