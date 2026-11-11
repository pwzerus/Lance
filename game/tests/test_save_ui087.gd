extends "test_ui082.gd"
func put(path: String, value: String) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg=="--compact": compact=true
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in str(state.save_path) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.coins=876
	state.profile.settings.sound=false
	check(state.save_slot(1),"prepare valid manual recovery slot")
	put(state.save_path,"broken primary")
	put(state.backup_path,"broken backup")
	state.load_profile()
	state.profile.settings.sound=false
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	check(main.page=="recovery","broken pair silently entered camp")
	await capture("01_recovery_choice")
	main.show_home()
	check(main.page=="recovery","Escape/home bypassed recovery")
	main._confirm_slot_operation(1,true)
	await process_frame
	await capture("02_recovery_confirmation")
	check(is_instance_valid(main.slot_dialog),"manual recovery lacks confirmation")
	main.slot_dialog.canceled.emit()
	await process_frame
	check(state.recovery_required and FileAccess.get_file_as_string(state.save_path)=="broken primary","cancel altered original save")
	main._confirm_slot_operation(1,true)
	await process_frame
	main.slot_dialog.confirmed.emit()
	await process_frame
	check(not state.recovery_required and state.profile.coins==876,"manual slot recovery did not restore progress")
	await capture("03_recovered_saves")
	main._confirm_slot_operation(1,false)
	await process_frame
	await capture("04_overwrite_confirmation")
	main.slot_dialog.canceled.emit()
	await process_frame
	# A real failed reward write remains marked pending after a manual save.
	state.backup_path=folder+"/blocked_backup"
	DirAccess.make_dir_recursive_absolute(state.backup_path)
	put(state.backup_path+"/keep.txt","blocks file copy")
	state.award_match("qa-ui-087",1,"arena")
	check(state.profile_save_pending,"reward failure not pending")
	check(state.save_slot(2),"manual snapshot failed unexpectedly")
	main.show_saves()
	await capture("05_pending_current_progress")
	main.set_process(false)
	main._start_match("arena",false)
	main.battle.set_physics_process(false)
	main.battle.set_process(false)
	main._on_match_finished({"winner":0,"reason":"score","player_hp":80,"enemy_hp":50,"player_score":5,"enemy_score":2})
	main.show_result()
	await capture("06_pending_reward_result")
	state.backup_path=folder+"/qa_backup.json"
	check(press("重试保存"),"result retry button missing")
	check(not state.profile_save_pending,"result retry failed")
	await capture("07_reward_saved")
	main._close_battle()
	main.show_home()
	await capture("08_recovered_camp")
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await create_timer(.15,true,false,true).timeout
	put(folder+"/report.json",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Background real rendering and production UI callbacks, not OS input. Isolated save faults, recovery/cancel/overwrite/retry."},"\t"))
	print("SAVE_UI087 ",failures)
	quit(0 if failures.is_empty() else 1)
