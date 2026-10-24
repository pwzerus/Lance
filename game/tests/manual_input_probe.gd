extends SceneTree

class InputProbe extends Node:
	var battle: Node
	var log_file: FileAccess
	var elapsed = 0.0
	var sample_at = 0.0
	var max_speed = 0.0
	var clicks = 0

	func record(data: Dictionary) -> void:
		data["ticks_ms"] = Time.get_ticks_msec()
		log_file.store_line(JSON.stringify(data))
		log_file.flush()

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			clicks += 1 if event.pressed else 0
			record({"kind":"desktop_button","pressed":event.pressed,"position":event.position,"paused":battle.paused})
			if event.pressed and not battle.paused and battle.match_model.phase=="ready":
				battle.match_model.phase = "charge"

	func _process(delta: float) -> void:
		elapsed += delta
		if Time.get_ticks_msec()<sample_at:
			return
		sample_at = Time.get_ticks_msec()+100
		var f = battle.match_model.fighters[0]
		max_speed = maxf(max_speed,float(f.speed))
		record({"kind":"state","phase":battle.match_model.phase,"boost":f.boost,"speed":f.speed,"x":f.x,"stamina":f.stamina,"raw_button":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"paused":battle.paused})

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
	main._start_match("arena")
	main.battle.match_model.phase_time = 999
	var probe = InputProbe.new()
	probe.battle = main.battle
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	probe.log_file = FileAccess.open("E:/GALUMU/docs/development/logs/v03-mouse-probe-v02.jsonl",FileAccess.WRITE)
	root.add_child(probe)
	probe.record({"kind":"begin","build":"v0.2","source":"Windows desktop input; this script does not inject input"})
	await create_timer(240,true,false,true).timeout
	probe.record({"kind":"end","clicks":probe.clicks,"max_speed":probe.max_speed})
	quit()
