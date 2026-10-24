extends SceneTree

const UI = preload("res://scripts/ui/ui_factory.gd")
var checks = 0
var failures: Array = []
var main: Node
var state: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func real_wait(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func touch(index: int, point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	return event

func find_button(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
		var found = find_button(child,prefix)
		if found:
			return found
	return null

func run() -> void:
	state = root.get_node("GameState")
	# This runner must never write a player's real save.
	check(state.save_path.contains("qa_"),"Integration runner must use an isolated QA save")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.profile = state.default_profile()
	state.save_profile()
	# Load after autoload initialization; --script compiles its entry point
	# before named autoloads are available to dependent gameplay scripts.
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames()
	check(main.page=="home","Main scene must open at camp")
	find_button(main.screen,"军械库").pressed.emit()
	await frames()
	check(main.page=="armory","Camp armory button must open the shop")
	var oversized_icons: Array = []
	_scan_icons(main.screen,oversized_icons)
	check(oversized_icons.is_empty(),"Shop icon textures must fit their fixed card sizes")
	find_button(main.screen,"头盔").pressed.emit()
	await frames()
	check(main.selected_slot=="helmet","Slot button must select helmets")
	find_button(main.screen,"十三世纪封闭盔").pressed.emit()
	await frames()
	find_button(main.info_panel,"购买").pressed.emit()
	await frames()
	check("helm_great" in state.profile.owned and state.profile.coins==260,"UI purchase must add one item and deduct its price")
	find_button(main.info_panel,"装备").pressed.emit()
	await frames()
	check(state.profile.equipped.helmet=="helm_great","UI equip must update the actual loadout")
	state.load_profile()
	check(state.profile.equipped.helmet=="helm_great","Purchased equipment must survive a disk reload")
	var clean = state.sanitize({"region":{},"settings":{"difficulty":[]},"coins":"invalid"})
	check(clean.region==0 and clean.settings.difficulty==1 and clean.coins==520,"Malformed field types must fall back without a runtime error")
	var good_path = state.save_path
	var good_backup = state.backup_path
	state.save_path = "res://directory_that_does_not_exist/profile.json"
	var old_coins = state.profile.coins
	check(state.purchase("lance_long").begins_with("购买未完成"),"An unwritable save must report that purchase failed")
	check(state.profile.coins==old_coins and "lance_long" not in state.profile.owned,"Failed purchases must refund coins and remove the unsaved item")
	state.save_path = "user://qa_corrupt_primary.json"
	state.backup_path = "user://qa_corrupt_backup.json"
	state.profile.coins = 610
	state.save_profile()
	state.profile.coins = 730
	state.save_profile()
	var corrupt = FileAccess.open(state.save_path,FileAccess.WRITE)
	corrupt.store_string("{broken json")
	corrupt.close()
	state.load_profile()
	check(state.profile.coins==610,"A corrupt primary save must load the preceding backup")
	state.save_path = good_path
	state.backup_path = good_backup
	state.profile = state.default_profile()
	state.save_profile()
	main.show_history()
	await frames()
	var source_button = find_button(main.screen,"查阅来源")
	check(source_button.size.y<=32,"Compact history buttons must fit inside their cards")
	main._start_match("arena")
	var battle = main.battle
	await frames()
	check(battle.match_model.fighters[1].stats.reach==247,"Opponent loadout must not mirror shop purchases")
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(1100,250)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	var mouse_button = InputEventMouseButton.new()
	mouse_button.button_index = MOUSE_BUTTON_LEFT
	mouse_button.pressed = true
	mouse_button.position = motion.position
	Input.parse_input_event(mouse_button)
	var held_key = InputEventKey.new()
	held_key.physical_keycode = KEY_W
	held_key.keycode = KEY_W
	held_key.pressed = true
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	await real_wait(.2)
	print("INPUT_AIM_HIGH ",battle.aim_pointer," aim ",battle.match_model.fighters[0].aim)
	check(battle.match_model.fighters[0].aim<-.10,"Viewport mouse movement must raise the actual lance")
	check(battle.match_model.fighters[0].boost and battle.match_model.fighters[0].lean>.2,"Held left mouse and W must drive acceleration and forward lean")
	mouse_button.pressed = false
	Input.parse_input_event(mouse_button)
	held_key.pressed = false
	Input.parse_input_event(held_key)
	motion.position = Vector2(1100,650)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await real_wait(.3)
	print("INPUT_AIM_LOW ",battle.aim_pointer," aim ",battle.match_model.fighters[0].aim)
	check(battle.match_model.fighters[0].aim>.10,"Lowering mouse position must lower the actual lance")
	check(not battle.match_model.fighters[0].boost and is_zero_approx(battle.match_model.fighters[0].lean),"Releasing held inputs must stop boost and return the rider upright")
	state.profile.settings.mouse_only = true
	mouse_button.button_index = MOUSE_BUTTON_WHEEL_UP
	mouse_button.pressed = true
	mouse_button.position = Vector2(900,600)
	root.push_input(mouse_button,true)
	await real_wait(.15)
	check(battle.wheel_lean>0 and battle.match_model.fighters[0].lean>0,"Mouse-only wheel input must control posture")
	mouse_button.button_index = MOUSE_BUTTON_MIDDLE
	root.push_input(mouse_button,true)
	await real_wait(.15)
	check(is_zero_approx(battle.wheel_lean) and is_zero_approx(battle.match_model.fighters[0].lean),"Middle mouse must reset posture")
	state.profile.settings.mouse_only = false
	battle.autoplay = true
	battle._unhandled_input(touch(8,Vector2(150,550),true))
	battle._unhandled_input(touch(3,Vector2(950,400),true))
	battle._unhandled_input(touch(5,Vector2(1100,500),true))
	check(battle.touch_roles.get(8)=="lean" and battle.touch_roles.get(3)=="aim" and battle.touch_roles.get(5)=="boost","Three touch IDs must retain independent input roles")
	var drag = InputEventScreenDrag.new()
	drag.index = 8
	drag.position = Vector2(1000,480)
	battle._unhandled_input(drag)
	check(battle.touch_lean>0 and battle.touch_roles[8]=="lean","A finger crossing screen halves must keep its original role")
	battle._unhandled_input(touch(3,Vector2(950,400),false))
	check(not battle.touch_roles.has(3) and battle.touch_aim==Vector2.ZERO,"Releasing aim touch must clear its state")
	var canceled_touch = touch(8,Vector2(1000,480),true)
	canceled_touch.canceled = true
	battle._unhandled_input(canceled_touch)
	check(not battle.touch_roles.has(8) and is_zero_approx(battle.touch_lean),"Canceled touches must clear their original role even if pressed is set")
	var rules_random_state = battle.match_model.rng.state
	battle.effects.blood_enabled = true
	battle.effects.hit(Vector2.ZERO,1,35,false,false)
	check(battle.effects.particles.any(func(p):return p.blood),"Blood-on must produce injury particles")
	check(battle.match_model.rng.state==rules_random_state,"Blood particles must never consume match-rule random numbers")
	battle.match_model.phase = "charge"
	battle.effects.fall(battle.match_model.fighters[0],1)
	await frames()
	key(KEY_ESCAPE)
	await frames()
	check(battle.paused and paused,"Escape must pause the match and physics world")
	var frozen = battle.effects.bodies[0].position
	var frozen_shake = battle.shake
	await real_wait(.15)
	check(battle.effects.bodies[0].position.is_equal_approx(frozen),"Ragdoll bodies must remain frozen during pause")
	check(battle.shake==frozen_shake,"Pause must preserve the camera effect rather than consuming animation frames")
	check(battle.touch_roles.is_empty(),"Pause must cancel all active touch roles")
	var blood_check: CheckButton
	for child in battle.pause_panel.get_children():
		if child is CheckButton and child.text=="显示血腥表现":
			blood_check = child
	blood_check.toggled.emit(false)
	check(battle.effects.stains.is_empty() and not battle.effects.particles.any(func(p):return p.blood),"Turning blood off must remove existing particles and stains")
	key(KEY_ESCAPE)
	await frames()
	check(not paused and Engine.time_scale==1.0,"Resume must restore tree processing and time scale")
	battle.hitstop_until = Time.get_ticks_msec()+50
	battle.slow_until = Time.get_ticks_msec()+160
	Engine.time_scale = .001
	await real_wait(.25)
	check(Engine.time_scale==1.0,"Real-time clock must release hitstop and slow motion")
	battle.autoplay = false
	battle._on_focus_lost()
	check(battle.paused,"Losing application focus must safely pause gameplay")
	main._start_match("war")
	await frames()
	check(not paused and Engine.time_scale==1 and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Restart from pause must restore global state")
	var old_session = main.session_id
	key(KEY_R)
	await frames()
	check(main.session_id!=old_session and main.get_children().filter(func(n):return n.get_script()!=null and n.get_script().resource_path.ends_with("battle.gd")).size()==1,"R must create exactly one replacement match")
	battle = main.battle
	battle.autoplay = true
	battle.match_model.fighters[1].ko = true
	battle.match_model.fighters[1].dead = true
	battle.match_model.fighters[1].hp = 0
	battle.hitstop_until = Time.get_ticks_msec()+100
	battle.slow_until = Time.get_ticks_msec()+300
	battle.match_model._finish("terminal")
	await real_wait(.15)
	check(battle.departure_elapsed<.08,"Departing horses must obey terminal hitstop and slow motion")
	await real_wait(2.55)
	check(main.result_visible and main.pending_result.enemy_dead,"A terminal war result must appear with a death outcome")
	var matches_after = state.profile.matches
	await real_wait(.15)
	check(state.profile.matches==matches_after and matches_after==1,"Finished match reward must be applied exactly once")
	main._close_battle()
	main.show_home()
	await frames()
	check(main.page=="home" and not paused and Engine.time_scale==1,"Return to camp must restore a usable menu")
	state.profile = state.default_profile()
	state.save_profile()
	var report = {"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"UI callbacks, injected Esc/R, touch IDs, pause physics, blood, save failure/recovery, terminal result"}
	var file = FileAccess.open("res://tests/integration_results.json",FileAccess.WRITE)
	if file == null:
		file = FileAccess.open("user://qa_integration_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("INTEGRATION_TEST_REPORT "+JSON.stringify(report))
	main.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func _scan_icons(node: Node, oversized: Array) -> void:
	for child in node.get_children():
		if child is TextureRect and (child.size.x>91 or child.size.y>127):
			oversized.append(child.size)
		_scan_icons(child,oversized)
