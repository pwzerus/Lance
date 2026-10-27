extends SceneTree
## Exercises actual Control hit-testing, not Button.pressed.emit callbacks.
var main: Node
var state: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func frames() -> void:
	for i in range(3):
		await process_frame

func button(text_value: String, slot: int = 0) -> Button:
	for node in main.screen.find_children("*","Button",true,false):
		if node.text!=text_value:
			continue
		if slot==0:
			return node
		for label in node.get_parent().get_children():
			if label is Label and label.text=="手动存档 %d" % slot:
				return node
	return null

func click(text_value: String, slot: int = 0) -> void:
	var control = button(text_value,slot)
	check(control!=null,"Missing menu button: "+text_value+str(slot))
	if control==null:
		return
	var point = control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await frames()

func run() -> void:
	state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.save_path = "user://qa_v043_menu_flow.json"
	state.backup_path = "user://qa_v043_menu_flow.backup.json"
	for slot in range(1,4):
		for path in [state.slot_path(slot),state.slot_path(slot)+".backup"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames()
	await click("开始游戏")
	check(main.page=="setup","Start enters setup via GUI hit-testing")
	await click("初学骑手")
	check(state.profile.settings.difficulty==0,"Beginner card sets difficulty zero")
	await click("老练对手")
	state.load_profile()
	check(state.profile.settings.difficulty==2,"Veteran card persists to disk")
	await click("开始练习")
	check(button("返回选择")!=null and main.battle==null,"First start shows briefing before a match")
	await click("返回选择")
	check(button("明白了，出战")==null and main.page=="setup","Brief cancel leaves setup usable")
	await click("开始练习")
	await click("明白了，出战")
	check(main.battle!=null and main.practice_match and state.profile.settings.combat_brief_v043,"Brief confirmation starts actual practice and records acknowledgement")
	main._close_battle()
	main.show_home()
	await frames()
	await click("存档 / 继续进度")
	check(main.page=="saves","Home opens save management via GUI")
	for slot in range(1,4):
		check(button("读取进度",slot).disabled,"Empty slot cannot be loaded: "+str(slot))
		state.profile.coins = 1000+slot
		state.profile.settings.difficulty = slot%3
		await click("保存到此槽",slot)
		var saved = state.read_slot(slot)
		check(not saved.is_empty() and saved.profile.coins==1000+slot,"Slot button saves its own slot: "+str(slot))
		check(not button("读取进度",slot).disabled,"Saved slot becomes loadable: "+str(slot))
	for slot in range(1,4):
		await click("读取进度",slot)
		check(state.profile.coins==1000+slot and state.profile.settings.difficulty==slot%3,"Slot button restores correct progress and settings: "+str(slot))
		state.load_profile()
		check(state.profile.coins==1000+slot,"Loaded slot is persisted as current autosave: "+str(slot))
	state.profile.coins = 2202
	await click("覆盖此槽",2)
	check(state.read_slot(2).profile.coins==2202 and state.read_slot(1).profile.coins==1001 and state.read_slot(3).profile.coins==1003,"Overwrite changes only the selected slot")
	await click("继续游戏")
	check(main.page=="setup","Continue returns to match setup")
	await click("进入实战")
	check(main.battle!=null and main.current_mode=="war" and not main.practice_match,"War starts without a repeated briefing")
	main._close_battle()
	main.queue_free()
	await frames()
	await create_timer(.3,true,false,true).timeout
	print("MENU_FLOW_V043 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"scope":"engine-injected viewport clicks through menu Controls; three independent slots, difficulty, briefing, practice and war; not OS mouse or human play"}))
	quit(0 if failures.is_empty() else 1)
