extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	var model = Model.new()
	model.phase = "charge"
	for f in model.fighters:
		f.acted = true
	var trace: Array = []
	var speed_at: Dictionary = {}
	for tick in range(624):
		model.set_controls(0,0,0,tick<240,1.0/120)
		model.set_controls(1,0,0,false,1.0/120)
		model.step(1.0/120)
		if tick+1 in [60,180,240,300,360,480,624]:
			var time = float(tick+1)/120
			speed_at[tick+1] = float(model.fighters[0].speed)
			trace.append({"seconds":time,"speed":model.fighters[0].speed,"x":model.fighters[0].x})
	check(speed_at[60]>=470,"Half a second of urging must visibly reach a gallop")
	check(speed_at[180]>=479 and speed_at[240]>=479,"One tap's two-second urge must include sustained full gallop")
	check(speed_at[300]>430 and speed_at[360]>=390,"Release must retain momentum instead of abruptly returning to trot")
	check(speed_at[240]>speed_at[300] and speed_at[300]>speed_at[360] and speed_at[360]>speed_at[480],"Coasting must decay continuously")
	check(absf(float(speed_at[624])-Model.TROT_SPEED)<.1,"Release must eventually return to trot, not stick at gallop")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.show_match_setup()
	await process_frame
	var practice_button: Button
	var region: OptionButton
	for child in main.screen.find_children("*","Control",true,false):
		if child is Button and child.text.begins_with("开始练习"):
			practice_button = child
		if child is OptionButton:
			region = child
	check(practice_button!=null and region!=null,"Setup must expose practice and region controls")
	if practice_button and region:
		check(not practice_button.get_global_rect().intersects(region.get_global_rect()),"Practice entry must not overlap the region selector")
	main._start_match("arena",true)
	var battle = main.battle
	battle.set_physics_process(false)
	battle.match_model.phase = "charge"
	battle.match_model.fighters[0].x = -4000
	battle.match_model.fighters[1].x = 4000
	for f in battle.match_model.fighters:
		f.acted = true
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(1100,450)
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	for i in range(360):
		battle._physics_process(1.0/120)
	check(battle.mouse_held and battle.spur_left==0 and battle.match_model.fighters[0].boost,"Held input must keep urging after the tap buffer expires")
	check(float(battle.match_model.fighters[0].speed)>=479,"Three seconds of held input must sustain full gallop")
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	for i in range(60):
		battle._physics_process(1.0/120)
	check(not battle.mouse_held and not battle.match_model.fighters[0].boost and float(battle.match_model.fighters[0].speed)>430 and float(battle.match_model.fighters[0].speed)<480,"Releasing held input must stop urging while preserving a smooth coast")
	var previous_screen_gap = INF
	var gaps: Array = []
	for distance in [4400.0,3000.0,2000.0,1000.0,500.0,350.0]:
		battle.match_model.fighters[0].x = -distance*.5
		battle.match_model.fighters[1].x = distance*.5
		for i in range(120):
			battle._update_camera(1.0/60,Time.get_ticks_msec())
		var screen_gap = distance*battle.camera.zoom.x
		check(screen_gap<previous_screen_gap,"Cinematic zoom must preserve visible approach at distance "+str(distance))
		previous_screen_gap = screen_gap
		gaps.append({"world_separation":distance,"screen_separation":screen_gap,"zoom":battle.camera.zoom.x})
	main._close_battle()
	main.queue_free()
	await process_frame
	await create_timer(.3,true,false,true).timeout
	var report = {"checks":checks,"failures":failures,"passed":failures.is_empty(),"response":trace,"framing":gaps,"scope":"rule response, setup controls and settled camera projection; no human fun claim"}
	var file = FileAccess.open("res://tests/charge_response_v043_results.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
	print("CHARGE_RESPONSE_REPORT "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


