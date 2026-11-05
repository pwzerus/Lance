extends "test_memory_windows_inc059.gd"
## Same production lifetime probe, with QA saves inside its report directory.
## Real audio driver runs silently in this process; no global volume changes.
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	super._initialize()

func run() -> void:
	var target = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--window-report="):
			target = arg.trim_prefix("--window-report=")
	if target.is_empty() or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2)
		return
	var state = root.get_node("GameState")
	state.save_path = target.get_basename()+"-qa_profile.json"
	state.backup_path = target.get_basename()+"-qa_profile.backup.json"
	await super.run()
