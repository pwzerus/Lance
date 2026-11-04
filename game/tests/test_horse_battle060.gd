extends SceneTree
var main: Node
var directory = ""
var report: FileAccess

func _initialize() -> void:
	call_deferred("run")

func sample(label: String) -> void:
	report.store_line(JSON.stringify({"label":label,"seconds":Time.get_ticks_msec()/1000.0,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}))
	report.flush()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(directory+"/"+label+".png")!=OK:
		quit(1)
	sample(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--horse-report="): directory=arg.trim_prefix("--horse-report=")
	var state=root.get_node("GameState")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not state.save_path.contains("qa_") or directory.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	if FileAccess.file_exists(directory+"/report.jsonl"):
		quit(2)
		return
	report=FileAccess.open(directory+"/report.jsonl",FileAccess.WRITE)
	# Keep writes inside this unique workspace QA run, never the player's profile.
	state.save_path=directory+"/qa_horse_profile.json"
	state.backup_path=directory+"/qa_horse_profile.backup.json"
	state.profile=state.default_profile()
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1,true,false,true).timeout
	var coats=["bay","grey","flaxen","black"]
	var horses=["horse_bay","horse_grey","horse_chestnut","horse_courser"]
	for index in range(4):
		if not horses[index] in state.profile.owned: state.profile.owned.append(horses[index])
		state.profile.equipped.horse=horses[index]
		main.show_home()
		await capture(coats[index]+"-home")
		main._start_match("arena",true)
		main.battle.autoplay=true
		main.battle.match_model.fighters[1].stats.horse_coat=coats[(index+1)%4]
		for step in range(5):
			await create_timer(2,true,false,true).timeout
			await capture(coats[index]+"-charge-"+str(step))
		main._close_battle()
		await process_frame
	main.show_home()
	sample("before-minimize")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await create_timer(20,true,false,true).timeout
	sample("minimized")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await create_timer(2,true,false,true).timeout
	await capture("restored")
	report.close()
	if not state.save_profile():
		push_error("QA save failed: "+state.save_error)
		quit(1)
		return
	print("HORSE_BATTLE_060_RENDER_COMPLETE: requesting QA close")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
