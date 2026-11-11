extends SceneTree
## External probe loaded by the actual packaged engine, in a relocated bundle.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var folder = ""
	var wait = 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder = arg.trim_prefix("--folder=")
		if arg.begins_with("--probe-wait="): wait = clampf(float(arg.trim_prefix("--probe-wait=")),0,30)
	if folder.is_empty() or not OS.get_cmdline_user_args().has("--test-profile"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var state = root.get_node("GameState")
	var result = {"executable":OS.get_executable_path(), "engine":Engine.get_version_info(),
		"game_version":ProjectSettings.get_setting("application/config/version"),
		"arguments":OS.get_cmdline_user_args(), "guard":OS.get_environment("GALUMU_MEMORY_BOUND"),
		"profile":state.save_path, "display":DisplayServer.get_name(),
		"started_usec":Time.get_ticks_usec()}
	var file = FileAccess.open(folder+"/probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	var licenses = {"godot":Engine.get_license_text(),"licenses":Engine.get_license_info(),"copyright":Engine.get_copyright_info()}
	file = FileAccess.open(folder+"/engine-licenses.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(licenses,"\t"))
	file.close()
	if wait > 0: await create_timer(wait).timeout
	quit(0 if result.guard=="1024" and "qa_" in state.save_path else 1)
