extends SceneTree

class InputProbe extends Node:
	var battle: Node
	var log_file: FileAccess
	var status: Label
	var next_sample = 0
	var clicks = 0
	var releases = 0
	var max_speed = 0.0

	func record(data: Dictionary) -> void:
		data["ticks_ms"] = Time.get_ticks_msec()
		log_file.store_line(JSON.stringify(data))
		log_file.flush()

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			clicks += 1 if event.pressed else 0
			releases += 0 if event.pressed else 1
			record({"kind":"desktop_button","pressed":event.pressed,"position":event.position,"paused":battle.paused})
			if event.pressed and not battle.paused and battle.match_model.phase=="ready":
				battle.match_model.phase = "charge"
		if event is InputEventKey and event.physical_keycode==KEY_SPACE and not event.echo:
			record({"kind":"desktop_space","pressed":event.pressed})

	func _process(_delta: float) -> void:
		if Time.get_ticks_msec()<next_sample:
			return
		next_sample = Time.get_ticks_msec()+100
		var f = battle.match_model.fighters[0]
		max_speed = maxf(max_speed,float(f.speed))
		var raw = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		status.text = "v0.4 催马检查 · 左键开始冲锋\n收到按下 %d / 松开 %d　物理按住 %s\n催马 %s　实际速度 %.0f / 480\n阶段 %s　暂停 %s　最高速度 %.0f" % [clicks,releases,str(raw),str(f.boost),float(f.speed),str(battle.match_model.phase),str(battle.paused),max_speed]
		record({"kind":"state","phase":battle.match_model.phase,"boost":f.boost,"speed":f.speed,"x":f.x,"stamina":f.stamina,"raw_button":raw,"raw_space":Input.is_physical_key_pressed(KEY_SPACE),"mouse_held":battle.mouse_held,"spur_left":battle.spur_left,"paused":battle.paused,"tree_paused":get_tree().paused,"time_scale":Engine.time_scale,"focused":get_window().has_focus()})

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.profile = state.default_profile()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_match("arena",true)
	# Hold the staging area until a real click arrives; do not let the
	# inspection delay consume the run before its input can be observed.
	main.battle.match_model.phase_time = 999
	root.title = "Lance & Laurel v0.4 - Mouse input diagnostic"
	var probe = InputProbe.new()
	probe.battle = main.battle
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	probe.log_file = FileAccess.open("E:/GALUMU/docs/development/logs/v04-user-mouse-input.jsonl",FileAccess.WRITE)
	if not probe.log_file:
		quit(1)
		return
	var ui = load("res://scripts/ui/ui_factory.gd")
	var panel = ui.panel(main.battle.hud,Rect2(20,125,560,173),Color(.02,.04,.03,.96))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	probe.status = ui.label(panel,"",Vector2(12,8),19,Color.WHITE,540)
	root.add_child(probe)
	probe.record({"kind":"begin","build":"v0.4 export","executable":OS.get_executable_path(),"save":state.save_path,"source":"Actual input only; this runner never injects mouse or key events"})
