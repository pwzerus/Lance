extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func send(code: int, physical: bool, conflicting_physical: int = 0) -> void:
	var key = InputEventKey.new()
	if physical:
		key.physical_keycode = code
	else:
		key.keycode = code
		key.physical_keycode = conflicting_physical
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_match("arena",true)
	await process_frame
	var failures: Array = []
	send(KEY_ESCAPE,false)
	await process_frame
	if not main.battle.paused:
		failures.append("Logical-only Escape is ignored")
	else:
		send(KEY_ESCAPE,true)
		await process_frame
		if main.battle.paused:
			failures.append("Physical Escape failed to resume")
	var old_id = main.battle.get_instance_id()
	send(KEY_ESCAPE,false,4194313)
	await process_frame
	if not main.battle.paused:
		failures.append("Desktop Escape with differing scan code is ignored")
	send(KEY_ESCAPE,false,4194313)
	await process_frame
	send(KEY_R,false)
	await process_frame
	if main.battle.get_instance_id()==old_id:
		failures.append("Logical-only R is ignored")
	main._close_battle()
	main.queue_free()
	await process_frame
	print("KEYBOARD_V042 "+JSON.stringify({"failures":failures,"passed":failures.is_empty(),"scope":"engine injection, not OS keyboard"}))
	quit(0 if failures.is_empty() else 1)
