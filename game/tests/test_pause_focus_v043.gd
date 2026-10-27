extends SceneTree
var main: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_match("arena",true)
	await process_frame
	var battle = main.battle
	var pause_button: Button
	for node in battle.hud.find_children("*","Button",true,false):
		if node.text=="暂停  Esc":
			pause_button = node
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pause_button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await process_frame
	if not battle.paused:
		failures.append("Mouse pause button did not pause")
	key(KEY_ESCAPE)
	await process_frame
	if battle.paused:
		failures.append("Escape did not resume")
	print("FOCUS_AFTER_RESUME ",root.gui_get_focus_owner())
	key(KEY_SPACE)
	await process_frame
	if battle.paused:
		failures.append("Space intended to spur horse reactivated the focused pause button")
	if not battle.paused:
		battle.set_physics_process(false)
		battle.match_model.phase = "charge"
		battle.spur_left = 0
		battle.mouse_held = false
		var fighter = battle.match_model.fighters[0]
		fighter.speed = battle.Model.TROT_SPEED
		var held = InputEventKey.new()
		held.keycode = KEY_SPACE
		held.physical_keycode = KEY_SPACE
		held.pressed = true
		Input.parse_input_event(held)
		Input.flush_buffered_events()
		for tick in range(60):
			battle._physics_process(1.0/120)
		held = held.duplicate()
		held.pressed = false
		Input.parse_input_event(held)
		Input.flush_buffered_events()
		if float(fighter.speed)<450:
			failures.append("Held Space after resume did not accelerate the actual horse")
		print("SPEED_AFTER_RESUME ",fighter.speed)
	main._close_battle()
	main.queue_free()
	await process_frame
	await create_timer(.3,true,false,true).timeout
	print("PAUSE_FOCUS_V043 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"scope":"engine-injected mouse pause then Esc resume then Space; not OS input"}))
	quit(0 if failures.is_empty() else 1)
