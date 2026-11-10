extends "test_icons085.gd"
## Suspend while the armoury still has pending jobs; resume on isolated desktop.
func run() -> void:
	var folder=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=false
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await process_frame;await RenderingServer.frame_post_draw
	main.selected_slot="armor";main.selected_item={};main.show_armory()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await settle(1.0)
	var start_draws=Engine.get_frames_drawn();var start_mem=OS.get_static_memory_usage()
	var rows=[]
	for i in range(12):
		await settle(.5)
		rows.append({"can_draw":DisplayServer.window_can_draw(),"drawn":Engine.get_frames_drawn(),"static_bytes":OS.get_static_memory_usage()})
		if DisplayServer.window_can_draw() and "Minimize fixture did not suspend" not in failures:failures.append("Minimize fixture did not suspend")
	var drawn=Engine.get_frames_drawn()-start_draws
	if drawn>2:failures.append("Hidden armoury continued drawing")
	# Release Godot may return 0 (memory instrumentation disabled). The
	# supervisor's privateMiB samples are the authority in that case.
	if start_mem>0 and OS.get_static_memory_usage()-start_mem>8*1024*1024:failures.append("Hidden queue retains growing allocations")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await settle(1.2)
	var visible=visible_icons(main)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/restored.png")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"hidden_draws":drawn,"rows":rows,"visible":visible,"scope":"Actual window minimize/restore on the isolated desktop, with pending page jobs. Six second hidden steady window; not a long soak or OS input."},"\t"))
	print("SUSPEND085 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
