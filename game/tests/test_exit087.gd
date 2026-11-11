extends "test_ui082.gd"
## Real filesystem failure, rendered modals and normal asynchronous shutdown.
## Dialog signals are production callbacks, not OS mouse/keyboard evidence.
func run() -> void:
	var discard=false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a=="--discard":discard=true
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=false
	check(state.save_profile(),"Initial isolated save failed")
	var disk_before=FileAccess.get_sha256(state.save_path)
	var coins_before=state.profile.coins
	state.profile.coins+=180
	state.backup_path=folder+"/blocked_backup"
	DirAccess.make_dir_recursive_absolute(state.backup_path)
	FileAccess.open(state.backup_path+"/keep.txt",FileAccess.WRITE).store_string("Deliberate write failure")
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	main._start_match("arena",true)
	if root.focus_exited.is_connected(main.battle._on_focus_lost):root.focus_exited.disconnect(main.battle._on_focus_lost)
	await process_frame
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await capture("01_failed_exit")
	check(not main.shutting_down and main.battle.paused and paused,"Save error did not pause active combat")
	var first=main.save_error_dialog
	check(first is ConfirmationDialog and first.get_cancel_button().text=="返回游戏","Save failure lacks safe return")
	check(first.get_viewport().gui_get_focus_owner()==first.get_cancel_button(),"Failure dialog defaults to unsafe focus")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(main.save_error_dialog==first,"Duplicate close request changed the modal")
	first.canceled.emit();await process_frame
	check(not main.shutting_down and FileAccess.get_sha256(state.save_path)==disk_before,"Cancel altered saved progress or quit")
	main._save_and_exit();await process_frame
	main.save_error_dialog.custom_action.emit(&"discard");await process_frame;await process_frame
	await capture("02_discard_confirmation")
	var confirm=main.save_error_dialog
	check(confirm.dialog_text.contains("会丢失") and confirm.get_ok_button().text=="放弃改动并退出","Discard is not explicitly confirmed")
	check(confirm.get_viewport().gui_get_focus_owner()==confirm.get_cancel_button(),"Discard defaults to destructive focus")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(main.save_error_dialog==confirm and confirm.title=="放弃未保存的改动？","Repeated close rewrote discard confirmation")
	confirm.canceled.emit();await process_frame
	check(not main.shutting_down and FileAccess.get_sha256(state.save_path)==disk_before,"Discard cancellation altered saved progress")
	main._save_and_exit();await process_frame
	if discard:
		main.save_error_dialog.custom_action.emit(&"discard");await process_frame;await process_frame
		main.save_error_dialog.confirmed.emit()
	else:
		state.backup_path=folder+"/qa_backup.json"
		main.save_error_dialog.confirmed.emit()
		await process_frame;await process_frame
	check(main.shutting_down,"Confirmed exit did not start normal shutdown")
	var saved=state._read_save(state.save_path)
	if discard:
		check(saved.coins==coins_before and FileAccess.get_sha256(state.save_path)==disk_before,"Discard wrote unsaved changes or damaged original")
	else:
		check(saved.coins==coins_before+180 and not state.profile_save_pending,"Retry failed to save before exit")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"discard":discard,"shutting_down":main.shutting_down,"captures":captures,"saved_coins":saved.coins,"scope":"Actual isolated GPU and file write failure; normal modal callbacks and asynchronous shutdown, no OS input. Guard exit log proves final process exit."},"\t"))
	print("EXIT087 ",failures)
