extends "test_body114.gd"
## PHYS-115: diagnostic views of limp slips and contact constraints. No quality assertions.
const CASES = [["body",1,40.0,"slip",Vector2(300,300),false],["body",-1,40.0,"slip",Vector2(300,300),false],
	["head",-1,105.0,"impact",Vector2(620,180),true],["flank",1,60.0,"impact",Vector2(480,480),true],
	["flank",-1,60.0,"impact",Vector2(480,480),true],["body",1,40.0,"balance",Vector2(400,400),true]]

func run() -> void:
	var folder = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,960)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("21382f"))
	var actors = []
	var stages = []
	for index in range(CASES.size()):
		var c = CASES[index]
		var stage = Node2D.new()
		root.add_child(stage)
		stage.position = Vector2(240+(index%3)*480,415+(index/3)*465)
		stage.scale = Vector2.ONE*.92
		var line = Line2D.new()
		line.points = PackedVector2Array([Vector2(-3000,12),Vector2(3000,12)])
		line.width = 2
		line.default_color = Color("a99664")
		stage.add_child(line)
		var label = Label.new()
		label.text = "%s %d %s i%d %d/%d" % [c[1] if false else c[0],c[1],c[3],int(c[2]),int(c[4].x),int(c[4].y)]
		label.position = Vector2(30+(index%3)*480,20+(index/3)*465)
		root.add_child(label)
		actors.append(make_actor(stage,c[0],c[1],c[2],c[3],c[5],c[4]))
		stages.append(stage)
	for tick in range(721):
		for i in range(actors.size()):
			stages[i].position.x = 240+(i%3)*480-actors[i].position.x*.92
		if tick in [36,72,120,240,480,720]:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/t%03d.png" % tick)
		for actor in actors: actor.advance(1.0/120.0)
	quit(0)
