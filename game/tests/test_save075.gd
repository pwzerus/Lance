extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	var state=root.get_node("GameState")
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	print("SAVE075 first start")
	var first=state.save_profile()
	print("SAVE075 first=",first," error=",state.save_error)
	state.profile.coins=1234
	var second=state.save_profile()
	print("SAVE075 second=",second," error=",state.save_error)
	state.profile.coins=0
	state.load_profile()
	var valid=first and second and state.profile.coins==1234 and FileAccess.file_exists(state.backup_path)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":valid,"first":first,"second":second,"error":state.save_error,"coins":state.profile.coins}))
	quit(0 if valid else 1)
