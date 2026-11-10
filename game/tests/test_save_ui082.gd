extends "test_ui082.gd"
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
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	# Several delivered clicks can arrive before deferred deletion runs.
	var old_page=main.screen
	main.show_armory()
	check(not old_page.visible,"Previous page remains active until deferred deletion")
	await process_frame
	state.save_path=folder+"/missing/qa_profile.json"
	main._save_and_exit()
	await process_frame
	main._save_and_exit()
	await process_frame
	var dialogs: Array=[]
	for child in main.get_children():
		if child is AcceptDialog and not child.is_queued_for_deletion(): dialogs.append(child)
	check(dialogs.size()==1,"Repeated failed close stacked multiple dialogs")
	check(not main.shutting_down,"Failed save shut down despite unsaved changes")
	await capture("save_failure_dialog")
	for dialog in dialogs: dialog.canceled.emit()
	await process_frame
	state.save_path=folder+"/qa_profile.json"
	check(state.save_profile(),"Save retry after failure did not succeed")
	main.show_saves("已恢复保存")
	await capture("save_retry")
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Explicit unwritable isolated QA directory, repeated production close handler and retry. No player saves or OS input."},"\t"))
	print("SAVE_UI082 ",failures)
	quit(0 if failures.is_empty() else 1)
