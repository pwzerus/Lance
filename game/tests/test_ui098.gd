extends SceneTree
## Protected isolated render evidence. Engine-driven, never OS input.
var folder = ""
var main
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func shot(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")

func check_numbers(node: Node) -> void:
	if node is Label and node.is_visible_in_tree():
		var digits=RegEx.new()
		digits.compile("[0-9]")
		if digits.search(node.text): failures.append("numeric normal HUD label: "+node.text)
	for child in node.get_children(): check_numbers(child)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): folder=arg.trim_prefix("--report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless" or folder.is_empty() or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	var state=root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,810)
	root.content_scale_size=Vector2i(1440,810)
	state.profile.settings.sound=false
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1).timeout
	main._start_match("arena",true)
	var started=Time.get_ticks_msec()
	while not main.battle.presentation_ready and Time.get_ticks_msec()-started<30000:
		await process_frame
	if not main.battle.presentation_ready:
		failures.append("staged battle failed to become ready")
	else:
		main.battle.autoplay=true
		await create_timer(2).timeout
		await shot("battle-normal")
		check_numbers(main.battle.hud)
		if main.battle.speed_meter.get_global_rect().end.y>800: failures.append("speed meter overlaps lower margin")
		main.battle.training_zones=true
		main.battle._update_hud()
		await shot("battle-debug")
		main.battle.training_zones=false
		var impacted=false
		while not main.result_visible and Time.get_ticks_msec()-started<150000:
			await process_frame
			if not impacted and not main.battle.exchange_log.is_empty():
				impacted=true
				await shot("contact")
				check_numbers(main.battle.hud)
				main.battle.training_zones=true
				main.battle._update_hud()
				await shot("contact-debug")
				main.battle.training_zones=false
				main.battle._update_hud()
		if main.result_visible:
			await shot("result")
			var key=InputEventKey.new()
			key.pressed=true
			key.keycode=KEY_H
			main._unhandled_input(key)
			await shot("result-debug")
			if not main.result_detail_scroll.visible: failures.append("H did not reveal result data")
			main._unhandled_input(key)
			if main.result_detail_scroll.visible: failures.append("H did not hide result data")
		else: failures.append("match did not finish")
	main._close_battle()
	main.selected_slot="shield"
	main.selected_region=0
	main.selected_era=-1
	main.show_armory()
	await create_timer(1).timeout
	await shot("armory-shields")
	main.show_home()
	await create_timer(.5).timeout
	await shot("camp")
	main.show_levels(0)
	await create_timer(.5).timeout
	await shot("levels")
	var file=FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"passed":failures.is_empty(),"evidence":"isolated rendering + engine controls, no OS input or human play"},"  "))
	file.close()
	main.queue_free()
	for i in range(5): await process_frame
	print("UI098_DONE "+folder)
	quit(0 if failures.is_empty() else 1)
