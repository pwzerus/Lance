extends SceneTree
## Observes OS-delivered input only; injects none. Isolated from the real save.
var qa_main: Node
var timeout_cleanup = false

func _initialize() -> void:
	call_deferred("run")

func _process(_delta: float) -> bool:
	# No suspended five-minute coroutine: normal menu exit can free the harness.
	if timeout_cleanup:
		quit()
	elif Time.get_ticks_msec() >= 300000 and is_instance_valid(qa_main):
		qa_main._close_battle()
		qa_main.queue_free()
		timeout_cleanup = true
	return false

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.save_path = "user://qa_desktop_v047.json"
	state.backup_path = "user://qa_desktop_v047.backup.json"
	state.profile = state.default_profile()
	var main = load("res://scenes/main.tscn").instantiate()
	qa_main = main
	root.add_child(main)
	var audit = load("res://scripts/core/desktop_input_audit.gd").new()
	audit.main = main
	audit.log_path = "E:/GALUMU/docs/development/logs/v047/desktop-01.jsonl"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audit-log="):
			audit.log_path = argument.trim_prefix("--audit-log=")
	main.add_child(audit)
	root.title = "GALUMU v047 QA - desktop observation"
