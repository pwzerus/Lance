extends SceneTree
var main: Node
var state: Node
var scenario = "home"
var passed = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
	state.save_path = "user://qa_v043_exit_"+scenario+".json"
	state.backup_path = "user://qa_v043_exit_"+scenario+".backup.json"
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.coins = 4321
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if scenario in ["paused","failure"]:
		main._start_match("arena")
		main.battle._toggle_pause()
	if scenario=="failure":
		var path = state.save_path
		state.save_path = "user://missing_v043_exit/fail.json"
		main._save_and_exit()
		await process_frame
		var dialog: AcceptDialog
		for child in main.get_children():
			if child is AcceptDialog:
				dialog = child
		passed = dialog!=null and dialog.visible and dialog.process_mode==Node.PROCESS_MODE_ALWAYS and main.battle.paused
		print("EXIT_FAILURE_V043 ",passed,"; failed save stays open and dialog remains usable while paused")
		state.save_path = path
		if dialog:
			dialog.queue_free()
		main._close_battle()
		main.queue_free()
		await process_frame
		await create_timer(.3,true,false,true).timeout
		quit(0 if passed else 1)
		return
	main.tree_exiting.connect(func():
		var data = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
		passed = data is Dictionary and int(data.get("coins",0))==4321
		print("EXIT_SAVED_V043 ",scenario," ",passed))
	if scenario=="paused":
		main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	else:
		for child in main.screen.get_children():
			if child is Button and child.text=="保存并退出":
				child.pressed.emit()
