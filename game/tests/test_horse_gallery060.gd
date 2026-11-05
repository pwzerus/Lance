extends SceneTree
var riders: Array = []
var report: FileAccess
var directory = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gallery="): directory=arg.trim_prefix("--gallery=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or directory.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	if FileAccess.file_exists(directory+"/report.jsonl"):
		quit(2)
		return
	report=FileAccess.open(directory+"/report.jsonl",FileAccess.WRITE)
	root.size=Vector2i(1440,1080)
	root.content_scale_size=Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	Engine.max_fps=30
	var catalogue=load("res://scripts/core/catalogue.gd")
	var model=load("res://scripts/core/joust_match.gd")
	var rider_script=load("res://scripts/visual/rider_view.gd")
	var items=catalogue.load_items()
	var ids=["horse_bay","horse_grey","horse_chestnut","horse_courser"]
	for row in range(4):
		for side in range(2):
			var rider=rider_script.new()
			var stats=catalogue.stats(items,{"horse":ids[row]})
			var match_model=model.new("arena",stats,stats)
			rider.fighter=match_model.fighters[side]
			rider.fighter.x=0
			rider.position=Vector2(360+side*720,250+row*265)
			rider.scale=Vector2.ONE*.85
			rider.moving=true
			root.add_child(rider)
			rider.set_process(false)
			riders.append(rider)
			var label=Label.new()
			label.text=stats.horse_coat+" / "+str(rider.fighter.direction)
			label.position=Vector2(side*720+20,row*265+8)
			root.add_child(label)
	for speed in [0.0,210.0,480.0]:
		for phase in range(4):
			for rider in riders:
				rider.moving=speed>0
				rider.fighter.gait_moving=speed>0
				rider.fighter.speed=speed
				rider.fighter.gait_phase=phase*TAU/4
				rider.fighter.motion_drive=1.0 if speed==480 else 0.0
				rider.cycles_initialized=false
				rider.planted_feet.fill(INF)
				rider._process(.016)
			await process_frame
			await RenderingServer.frame_post_draw
			var frame=root.get_texture().get_image()
			var path=directory+"/speed%d-phase%d.png"%[speed,phase]
			if frame.save_png(path)!=OK:
				quit(1)
				return
			report.store_line(JSON.stringify({"speed":speed,"phase":phase,"path":path,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}))
			report.flush()
			await create_timer(.2,true,false,true).timeout
	report.close()
	quit()
