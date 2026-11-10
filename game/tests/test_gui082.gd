extends "test_ui082.gd"
## Real engine GUI hit-testing, including the modal shade and scroll controls.
## push_input is viewport injection, never system mouse/keyboard control.
func pointer(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion=InputEventMouseMotion.new()
	motion.position=point
	root.push_input(motion,true)
	var event=InputEventMouseButton.new()
	event.position=point
	event.button_index=button
	event.pressed=true
	root.push_input(event,true)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event,true)

func click_text(text: String) -> void:
	for button in buttons(main):
		if button.text==text and not button.disabled:
			pointer(button.get_global_rect().get_center())
			return
	check(false,"Missing GUI button "+text)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg=="--compact": compact=true
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	state.save_profile()
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	click_text("开始游戏")
	await process_frame
	check(main.page=="setup","Start button GUI hit failed")
	click_text("进入竞技场")
	await process_frame
	check(is_instance_valid(main.brief_overlay),"Brief did not open through GUI")
	click_text("返回营地") # behind the full-screen shade, outside the dialog
	await process_frame
	check(main.page=="setup" and is_instance_valid(main.brief_overlay),"Brief overlay allowed a background click")
	click_text("返回选择")
	await process_frame
	check(not is_instance_valid(main.brief_overlay),"Brief cancel GUI hit failed")
	click_text("返回营地")
	await process_frame
	click_text("设置")
	await process_frame
	click_text("镜头震动")
	await process_frame
	check(not state.profile.settings.shake,"Setting toggle GUI hit failed")
	var disk=JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	check(disk is Dictionary and not disk.settings.shake,"Setting toggle was not persisted")
	click_text("返回营地")
	await process_frame
	click_text("军械库")
	await process_frame
	var selected=""
	for id in main.armory_cards:
		if id!=main.selected_item.id:
			selected=id
			pointer(main.armory_cards[id].get_global_rect().get_center())
			break
	await process_frame
	check(main.selected_item.id==selected,"Inventory card GUI hit did not select the card")
	var old_scroll=main.armory_scroll.scroll_vertical
	for _i in range(5): pointer(Vector2(420,450),MOUSE_BUTTON_WHEEL_DOWN)
	for _i in range(3): await process_frame
	check(main.armory_scroll.scroll_vertical>old_scroll,"Inventory wheel input did not scroll")
	await capture("gui_inventory")
	click_text("返回营地")
	await process_frame
	click_text("开始游戏")
	await process_frame
	click_text("开始练习")
	await process_frame
	click_text("明白了，出战")
	await process_frame
	check(main.page=="battle" and main.practice_match,"Practice start GUI hit failed")
	var battle=main.battle
	if root.focus_exited.is_connected(battle._on_focus_lost): root.focus_exited.disconnect(battle._on_focus_lost)
	battle.set_physics_process(false)
	pointer(battle.guard_buttons[0].get_global_rect().get_center())
	await process_frame
	check(battle.guard_slot==0,"Guard GUI button did not select high guard")
	check(not battle.mouse_held,"Guard click latched horse acceleration")
	click_text("暂停 Esc")
	await process_frame
	check(battle.paused and paused,"Pause button GUI hit failed")
	click_text("继续对冲")
	await process_frame
	check(not battle.paused and not paused,"Resume button GUI hit failed")
	click_text("暂停 Esc")
	await process_frame
	click_text("返回营地")
	await process_frame
	check(main.page=="home" and not paused and is_equal_approx(Engine.time_scale,1.0),"Return from paused battle kept simulation paused")
	await capture("gui_return")
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Engine viewport mouse press/release/wheel GUI hit-testing. No OS input or human play."},"\t"))
	print("GUI082 ",failures)
	quit(0 if failures.is_empty() else 1)
