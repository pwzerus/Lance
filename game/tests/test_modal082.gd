extends "test_gui082.gd"
## Keyboard focus must remain in the visible briefing, not its dimmed page.
func key(code: int, shift: bool = false) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.shift_pressed=shift
	event.pressed=true
	root.push_input(event,true)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event,true)
func focus_in_brief() -> bool:
	var owner=root.gui_get_focus_owner()
	return is_instance_valid(owner) and is_instance_valid(main.brief_overlay) and main.brief_overlay.is_ancestor_of(owner)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	click_text("开始游戏")
	await process_frame
	var origin: Control
	for button in buttons(main):
		if button.text=="进入竞技场": origin=button
	click_text("进入竞技场")
	await process_frame
	check(focus_in_brief(),"Brief leaves keyboard focus on dimmed setup controls")
	for backwards in [false,true]:
		for index in range(6):
			key(KEY_TAB,backwards)
			await process_frame
			check(focus_in_brief(),"Tab navigation escaped the visible brief")
	await capture("keyboard_brief")
	key(KEY_ESCAPE)
	await process_frame
	check(main.page=="setup" and not is_instance_valid(main.brief_overlay),"Escape did not cancel the brief")
	check(root.gui_get_focus_owner()==origin,"Cancel did not restore keyboard focus to the originating button")
	click_text("进入竞技场")
	await process_frame
	key(KEY_ENTER)
	await process_frame
	check(main.page=="battle" and is_instance_valid(main.battle),"Enter did not activate the focused brief action")
	if is_instance_valid(main.battle):
		var battle=main.battle
		if root.focus_exited.is_connected(battle._on_focus_lost): root.focus_exited.disconnect(battle._on_focus_lost)
		battle.set_physics_process(false)
		click_text("暂停 Esc")
		await process_frame
		var owner=root.gui_get_focus_owner()
		check(is_instance_valid(owner) and battle.pause_panel.is_ancestor_of(owner),"Pause leaves keyboard focus outside the pause menu")
		for backwards in [false,true]:
			for index in range(8):
				key(KEY_TAB,backwards)
				await process_frame
				owner=root.gui_get_focus_owner()
				check(is_instance_valid(owner) and battle.pause_panel.is_ancestor_of(owner),"Tab navigation escaped the pause menu")
		await capture("keyboard_pause")
		key(KEY_ESCAPE)
		await process_frame
		check(not battle.paused,"Escape did not resume the keyboard pause")
		check(root.gui_get_focus_owner()==null,"Resume leaves a menu button able to consume Space")
		key(KEY_ESCAPE)
		await process_frame
		key(KEY_ENTER)
		await process_frame
		check(not battle.paused,"Enter did not activate the initial Resume action")
		key(KEY_SPACE)
		await process_frame
		check(not battle.paused,"Space reactivated a stale Pause button after resuming")
		main._close_battle()
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Engine viewport keyboard and mouse injection; modal focus and cancel/start paths. No OS input."},"\t"))
	print("MODAL082 ",failures)
	quit(0 if failures.is_empty() else 1)
