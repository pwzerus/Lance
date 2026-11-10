extends "test_ui082.gd"
## All catalogue descriptions in the actual detail panel, not just starter kit.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	main.selected_era=-1
	main.show_armory()
	await process_frame
	var rows: Array=[]
	for item in state.items:
		main.selected_item=item
		main._update_item_panel()
		for _i in range(2): await process_frame
		var title: Label
		var period: Label
		var description: Label
		for child in main.info_panel.get_children():
			if child is Label:
				if child.text==item.name: title=child
				elif child.text==item.description: description=child
				elif is_equal_approx(child.position.y,76): period=child
		var bad: Array=[]
		if title!=null and title.get_rect().end.y>76: bad.append("title overlaps provenance")
		if period!=null and period.get_rect().end.y>112: bad.append("provenance overlaps description")
		if description!=null and description.get_rect().end.y>246: bad.append("description overlaps stats")
		rows.append({"id":item.id,"failures":bad,"description_bottom":description.get_rect().end.y if description!=null else -1})
		if not bad.is_empty():
			check(false,str(item.id)+": "+str(bad))
			if captures.size()<12: await capture(str(item.id))
		if rows.size()%40==0: print("CATALOG082 progress=",rows.size())
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"captures":captures,"scope":"Actual GPU/font layout at 960x540 for all equipment descriptions; no mouse or player save."},"\t"))
	print("CATALOG082 count=",rows.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
