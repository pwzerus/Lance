extends SceneTree
var main: Node
var state: Node
var failures: Array[String] = []
var measured: Array = []
var capture_dir = "E:/GALUMU/docs/development/screenshots/v044/layout/"

func _initialize() -> void:
	call_deferred("run")

func check_page(tag: String, capture_image: bool = false, container: Control = null) -> void:
	await process_frame
	await process_frame
	await process_frame
	var buttons: Array[Control] = []
	var labels: Array[Control] = []
	var scan_root = container if container else main.screen
	for control in scan_root.find_children("*","Control",true,false):
		if not control.is_visible_in_tree():
			continue
		if control is Button:
			buttons.append(control)
		if control is Label:
			labels.append(control)
		if control is Button or control is Label:
			var r = control.get_global_rect()
			if r.position.x<-.5 or r.position.y<-.5 or r.end.x>1441 or r.end.y>811:
				failures.append(tag+": outside logical canvas: "+control.text+" "+str(r))
	for i in range(buttons.size()):
		for j in range(i+1,buttons.size()):
			if buttons[i].get_global_rect().grow(-1).intersects(buttons[j].get_global_rect().grow(-1)):
				failures.append(tag+": overlapping controls: "+buttons[i].text+" / "+buttons[j].text)
	for label in labels:
		for button in buttons:
			if label.get_global_rect().grow(-1).intersects(button.get_global_rect().grow(-1)):
				failures.append(tag+": text overlaps control: "+label.text+" / "+button.text)
	measured.append({"page":tag,"buttons":buttons.size(),"labels":labels.size(),"window":str(root.size)})
	if capture_image:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(capture_dir)
		root.get_texture().get_image().save_png(capture_dir+tag+".png")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")+"/"
	state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for size_value in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = size_value
		var prefix = str(size_value.x)+"_"
		main.show_home()
		await check_page(prefix+"home",size_value.x==960)
		main.show_match_setup()
		await check_page(prefix+"setup",size_value.x==960)
		main.show_saves()
		await check_page(prefix+"saves")
		main.show_settings()
		await check_page(prefix+"settings")
	# A valid but unusually large legacy profile must still fit its menu.
	state.profile.coins = 999999999
	state.profile.renown = 999999999
	state.profile.wins = 999999999
	state.profile.matches = 999999999
	main.show_home()
	await check_page("large_profile_home")
	main.show_saves()
	await check_page("large_profile_saves")
	main._start_match("arena",true)
	main.battle._toggle_pause()
	await check_page("pause",true,main.battle.pause_panel)
	main.battle._toggle_pause()
	main.battle.match_model._finish("hp")
	for event in main.battle.match_model.drain_events():
		main.battle._handle_event(event)
	main.battle.is_finished = true
	main.battle._update_hud()
	main.show_result()
	await check_page("result",true)
	if main.battle.hud.visible:
		failures.append("Battle HUD must be hidden at results")
	main._close_battle()
	main.queue_free()
	await process_frame
	await create_timer(.3,true,false,true).timeout
	var result = {"passed":failures.is_empty(),"failures":failures,"measured":measured,"scope":"engine-rendered window sizes; control/text geometry, not other hardware or OS DPI"}
	var file = FileAccess.open("res://tests/layout_v044_results.json",FileAccess.WRITE)
	if file==null:
		file = FileAccess.open("user://qa_layout_v044_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("LAYOUT_V044 "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

