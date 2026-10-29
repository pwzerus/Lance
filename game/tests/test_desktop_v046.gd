extends SceneTree
## Native desktop observation only. This script injects no input.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.save_path = "user://qa_desktop_v046.json"
	state.backup_path = "user://qa_desktop_v046.backup.json"
	state.profile = state.default_profile()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var audit = load("res://scripts/core/desktop_input_audit.gd").new()
	audit.main = main
	audit.log_path = "E:/GALUMU/docs/development/logs/v046/desktop-01.jsonl"
	main.add_child(audit)
	root.title = "GALUMU v046 QA — desktop observation"
	await create_timer(240,true,false,true).timeout
	main._close_battle()
	main.queue_free()
	await process_frame
	quit()
