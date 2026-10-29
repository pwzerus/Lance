extends "test_hud_v047.gd"
## Small-window/letterbox follow-up. Synthetic embedder events and passive
## observed events are labelled separately; no direct _input calls simulate OS.
var edge_rows: Array = []
var audit: Node
var observe_seconds = .5

class EdgeInputAudit extends Node:
	var events: Array = []
	var synthetic_tag = ""
	var battle
	func _input(event: InputEvent) -> void:
		if not event is InputEventMouse:
			return
		var window = get_window()
		var raw_screen = DisplayServer.mouse_get_position()
		var window_origin = DisplayServer.window_get_position(window.get_window_id())
		var row = {"source":"engine_embedder_injection" if not synthetic_tag.is_empty() else "observed_not_injected_by_this_test","tag":synthetic_tag,"type":event.get_class(),"device":event.device,"logical_position":[event.position.x,event.position.y],"global_position":[event.global_position.x,event.global_position.y],"screen_cursor_poll":[raw_screen.x,raw_screen.y],"window_client_origin":[window_origin.x,window_origin.y],"window_size":[window.size.x,window.size.y],"wall_msec":Time.get_ticks_msec()}
		if is_instance_valid(battle):
			row["pointer_before_dispatch"] = battle.pointer_aim
			row["mouse_held_before_dispatch"] = battle.mouse_held
		events.append(row)

func input_probe(battle, tag: String, physical_point: Vector2, expected_logical: Vector2, expect_bar: bool) -> Dictionary:
	audit.synthetic_tag = tag
	var before = float(battle.pointer_aim)
	var first_event = audit.events.size()
	var motion = InputEventMouseMotion.new()
	motion.position = physical_point
	motion.global_position = physical_point
	motion.relative = Vector2(1,0)
	# false asks Viewport to convert from embedder coordinates. Record the
	# actual delivered coordinate instead of assuming native Window delivery
	# is identical to this API path.
	root.push_input(motion,false)
	var delivered: Vector2 = battle.aim_pointer
	var observer_position = Vector2.INF
	if audit.events.size()>first_event:
		var latest: Dictionary = audit.events[audit.events.size()-1]
		observer_position = Vector2(latest.logical_position[0],latest.logical_position[1])
	var button = InputEventMouseButton.new()
	button.position = physical_point
	button.global_position = physical_point
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	root.push_input(button,false)
	battle._physics_process(DT)
	var urged = bool(battle.match_model.fighters[0].boost)
	var aimed = float(battle.pointer_aim)
	var mapping_matches = delivered.distance_to(expected_logical)<1.0
	# This is an engine-injection assertion only, never OS reproduction.
	if expect_bar and mapping_matches:
		check(not urged,"Mapped letterbox engine injection urged the horse (OS delivery unverified)")
		check(absf(aimed-before)<.0001,"Mapped letterbox engine injection changed aim (OS delivery unverified)")
	button.pressed = false
	root.push_input(button,false)
	battle._physics_process(DT)
	audit.synthetic_tag = ""
	return {"source":"engine_embedder_injection_not_OS","tag":tag,"physical_embedder_point":[physical_point.x,physical_point.y],"expected_content_logical_point":[expected_logical.x,expected_logical.y],"delivered_logical_point":[delivered.x,delivered.y],"embedder_mapping_matches_content_math":mapping_matches,"expected_letterbox":expect_bar,"observer_received_mouse_event":audit.events.size()>first_event,"battle_aim_pointer_matches_observed_event":observer_position.is_finite() and observer_position.distance_to(delivered)<.01,"battle_urged_during_press":urged,"aim_before":before,"aim_after":aimed}

func run() -> void:
	capture_dir = "E:/GALUMU/docs/development/screenshots/v047/hud-edges01"
	report_path = "E:/GALUMU/docs/development/logs/v047/hud-edges01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--observe-seconds="):
			observe_seconds = clampf(float(arg.trim_prefix("--observe-seconds=")),0,15)
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("HUD edge test requires rendering and -- --test-profile")
		quit(1)
		return
	if FileAccess.file_exists(report_path):
		push_error("Choose fresh edge-test outputs")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.settings.shake = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	audit = EdgeInputAudit.new()
	audit.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(audit)
	for requested in [Vector2i(960,540),Vector2i(1024,768),Vector2i(1920,800)]:
		root.size = requested
		await process_frame
		await process_frame
		main._start_match("arena",true)
		var battle = main.battle
		configure(battle)
		audit.battle = battle
		set_fixture(battle,"charge",400,0,0,1,true)
		await measure(battle,str(requested.x)+"x"+str(requested.y)+"_close_high_shields",true)
		var actual = Vector2(root.size)
		var logical = Vector2(1440,810)
		var scale_value = minf(actual.x/logical.x,actual.y/logical.y)
		var content_size = logical*scale_value
		var content_offset = (actual-content_size)*.5
		battle.set_process_input(true)
		# Unhandled keys/touch stay isolated; mouse _input uses the real engine route.
		var probes: Array = []
		var center = content_offset+content_size*.5
		probes.append(input_probe(battle,"content_center",center,(center-content_offset)/scale_value,false))
		if content_offset.y>1:
			var point = Vector2(actual.x*.5,content_offset.y*.5)
			probes.append(input_probe(battle,"top_letterbox",point,(point-content_offset)/scale_value,true))
		if content_offset.x>1:
			var point = Vector2(content_offset.x*.5,actual.y*.5)
			probes.append(input_probe(battle,"left_letterbox",point,(point-content_offset)/scale_value,true))
			point.x = actual.x-content_offset.x*.5
			probes.append(input_probe(battle,"right_letterbox",point,(point-content_offset)/scale_value,true))
		# Passive event observation may collect real input but does not create it.
		# Zero observed events means OS black-bar behaviour remains unverified.
		if observe_seconds>0:
			await create_timer(observe_seconds,true,false,true).timeout
		battle.set_process_input(false)
		edge_rows.append({"requested_window":[requested.x,requested.y],"actual_window":[root.size.x,root.size.y],"logical_viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"expected_content_rect":[content_offset.x,content_offset.y,content_size.x,content_size.y],"physical_scale":scale_value,"minimum_hint_font_physical_px":14*scale_value,"guard_button_physical_height":44*scale_value,"probes":probes})
		main._close_battle()
		await process_frame
	main.queue_free()
	await process_frame
	var observed = 0
	for event in audit.events:
		if event.source=="observed_not_injected_by_this_test":
			observed += 1
	var report = {"passed":failures.is_empty(),"failures":failures,"layout":rows,"edges":edge_rows,"input_events":audit.events,"observed_non_test_event_count":observed,"scope":"Three rendered window-edge fixtures using production keep-aspect stretch, formal high-shield near view, HUD and figure geometry. Synthetic Viewport embedder input is labelled and actual delivered coordinates recorded; passive unlabelled events are observations, not automatically OS black-bar acceptance. No direct _input calls, no OS injection, no human readability rating."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("HUD_EDGES_V047 ",report.passed," failures=",failures," observed_events=",observed)
	quit(0 if failures.is_empty() else 1)
