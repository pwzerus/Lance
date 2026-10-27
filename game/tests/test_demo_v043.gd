extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Cues = preload("res://scripts/visual/combat_cues.gd")
var failures: Array[String] = []
var notes: Array[String] = []
var state: Node
var main: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func write(path: String, value: String) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()

func find_button(node: Node, text_value: String) -> Button:
	if node is Button and node.text==text_value:
		return node
	for child in node.get_children():
		var found = find_button(child,text_value)
		if found:
			return found
	return null

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func mouse(point: Vector2, button: int, down: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = down
	root.push_input(event,true)

func saves() -> void:
	state.save_path = "user://qa_v043_suite.json"
	state.backup_path = "user://qa_v043_suite.backup.json"
	for path in [state.save_path,state.backup_path,state.slot_path(1),state.slot_path(1)+".backup",state.slot_path(2),state.slot_path(2)+".backup",state.slot_path(3),state.slot_path(3)+".backup"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	state.profile = state.default_profile()
	state.profile.coins = 777
	check(state.save_profile(),"initial autosave")
	check(state.save_slot(1),"first manual save")
	state.profile.coins = 888
	check(state.save_slot(1),"manual overwrite")
	write(state.slot_path(1),"{broken json")
	var recovered = state.read_slot(1)
	check(not recovered.is_empty() and recovered.profile.coins==777 and recovered.recovered,"corrupt slot must recover previous backup")
	state.profile.coins = 999
	check(state.save_slot(1),"save repairs corrupt slot")
	var backup_text = FileAccess.get_file_as_string(state.slot_path(1)+".backup")
	check(JSON.parse_string(backup_text).profile.coins==777,"corrupt primary must not overwrite valid backup")
	write(state.slot_path(1),JSON.stringify({"version":1,"format":"lance-manual-1","profile":"invalid"}))
	check(state.save_slot(1),"save repairs invalid envelope")
	check(FileAccess.get_file_as_string(state.slot_path(1)+".backup")==backup_text,"invalid envelope must not overwrite backup")
	state.profile.coins = 1234
	check(state.load_slot(1) and state.profile.coins==999,"manual load restores saved progress")
	check(not state.load_slot(0) and state.profile.coins==999,"invalid slot leaves progress intact")
	var previous_backup = state.backup_path
	state.backup_path = "user://missing_v043_directory/backup.json"
	state.profile.coins = 555
	check(not state.load_slot(1) and state.profile.coins==555,"failed auto backup rolls back loaded memory")
	state.backup_path = previous_backup
	state.save_error = ""
	notes.append("manual save/load, corrupt/invalid backup recovery, failed load rollback, QA-only paths")

func projections() -> void:
	for side in [0,1]:
		var model = Model.new("arena")
		var a = model.fighters[side]
		var d = model.fighters[1-side]
		d.shield = 0
		for zone in ["head","body","flank"]:
			var y = Model.head_position(d).y if zone=="head" else (Model.body_position(d).y if zone=="body" else Model.flank_position(d).y)
			a.aim = asin((y-Model.hand_position(a).y)/Model.lance_length(a))
			check(Cues.project(model,side).zone==zone,"projection "+str(side)+"/"+zone)
		d.shield = 78
		d.guard = 1.0
		a.aim = asin((Model.shield_position(d).y-Model.hand_position(a).y)/Model.lance_length(a))
		check(Cues.project(model,side).zone=="shield","shield takes first contact priority")
		var rng_before = model.rng.state
		var fighters_before = model.fighters.duplicate(true)
		for i in range(500):
			Cues.project(model,side)
		check(model.rng.state==rng_before and model.fighters==fighters_before,"cues are read-only")
		a.acted = true
		check(not Cues.project(model,side).active,"hide cue after own strike")
		a.acted = false
		model.phase = "ended"
		check(not Cues.project(model,side).active,"hide cue after result")
	notes.append("projected head/chest/flank, shield-first order, both directions, no physics/RNG mutation")

func run() -> void:
	state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	saves()
	projections()
	state.profile.settings.sound = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	find_button(main.screen,"开始游戏").pressed.emit()
	await process_frame
	check(main.page=="setup","home opens mode selection")
	find_button(main.screen,"老练对手").pressed.emit()
	await process_frame
	check(state.profile.settings.difficulty==2,"difficulty persists from setup")
	main.show_saves()
	await process_frame
	check(find_button(main.screen,"继续游戏")!=null and find_button(main.screen,"保存到此槽")!=null,"save page has clear actions")
	main._start_match("arena",true)
	await process_frame
	var battle = main.battle
	battle.autoplay = false
	battle.set_physics_process(false)
	key(KEY_1)
	check(battle.guard_slot==0,"key 1 selects head")
	key(KEY_2)
	check(battle.guard_slot==1,"key 2 selects chest")
	key(KEY_3)
	check(battle.guard_slot==2,"key 3 selects abdomen")
	key(KEY_Q)
	check(battle.guard_slot==0,"Q cycles all three guards")
	mouse(Vector2(700,400),MOUSE_BUTTON_RIGHT,true)
	mouse(Vector2(700,400),MOUSE_BUTTON_RIGHT,false)
	check(battle.guard_slot==1,"right click cycles guards")
	battle._clear_touch()
	var aim_before = battle.pointer_aim
	var button_point = battle.guard_buttons[2].get_global_rect().get_center()
	mouse(button_point,MOUSE_BUTTON_LEFT,true)
	check(not battle.mouse_held and battle.spur_left==0,"shield click must not spur horse")
	mouse(button_point,MOUSE_BUTTON_LEFT,false)
	check(battle.guard_slot==2 and battle.pointer_aim==aim_before,"shield button selects abdomen without aiming")
	var touch = InputEventScreenTouch.new()
	touch.position = battle.guard_buttons[0].get_global_rect().get_center()
	touch.index = 7
	touch.pressed = true
	root.push_input(touch,true)
	check(battle.guard_slot==0 and battle.touch_roles.is_empty(),"touch shield button does not acquire a lean/aim role")
	touch = touch.duplicate()
	touch.pressed = false
	root.push_input(touch,true)
	key(KEY_ESCAPE)
	key(KEY_3)
	check(battle.paused and battle.guard_slot==0,"paused guard cannot change")
	key(KEY_ESCAPE)
	battle.match_model.phase = "charge"
	var f = battle.match_model.fighters[0]
	f.speed = Model.TROT_SPEED
	mouse(Vector2(700,400),MOUSE_BUTTON_LEFT,true)
	for i in range(60):
		battle._physics_process(1.0/120)
	check(float(f.speed)>450,"holding left must visibly accelerate within half a second")
	mouse(Vector2(700,400),MOUSE_BUTTON_LEFT,false)
	check(not battle.mouse_held,"left release clears hold")
	check(absf(float(f.guard)-1.0)<.03,"guard travels smoothly to head slot")
	notes.append("engine-injected keys, mouse and touch; shield clicks isolated from aiming/boost; pause; left boost")
	main._close_battle()
	main.queue_free()
	await process_frame
	await create_timer(.3,true,false,true).timeout
	var result = {"passed":failures.is_empty(),"failures":failures,"coverage":notes,"scope":"engine injection and rule/save tests; not OS desktop or human play"}
	write("res://tests/demo_v043_results.json",JSON.stringify(result,"\t"))
	print("DEMO_V043 "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
