extends SceneTree
## Native desktop observation only; this harness never injects inputs.
var qa_main: Node
var timeout_cleanup = false

func _initialize() -> void:
	call_deferred("run")

func _process(_delta: float) -> bool:
	if timeout_cleanup:
		quit()
	elif Time.get_ticks_msec()>=300000 and is_instance_valid(qa_main):
		qa_main._close_battle()
		qa_main.queue_free()
		timeout_cleanup = true
	return false

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.save_path = "user://qa_desktop_v050_%d.json" % Time.get_ticks_usec()
	state.backup_path = state.save_path+".backup"
	state.profile = state.default_profile()
	qa_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(qa_main)
	var audit = load("res://scripts/core/desktop_input_audit.gd").new()
	audit.main = qa_main
	audit.log_path = "E:/GALUMU/docs/development/logs/v050/desktop01.jsonl"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audit-log="):
			audit.log_path = argument.trim_prefix("--audit-log=")
	if FileAccess.file_exists(audit.log_path):
		push_error("Choose a fresh desktop audit log")
		audit.free()
		quit(2)
		return
	qa_main.add_child(audit)
	audit.write({"kind":"qa_identity","save_path":state.save_path,"executable":OS.get_executable_path(),"injection":false})
	root.title = "GALUMU v0.4.10 QA - Desktop observation"
